//
//  StrataTransport.swift (was StrataClient.swift)
//  StrataFoundry
//
//  Raw async FFI wrapper over the Rust bridge.
//  All FFI calls are dispatched off the main thread.
//
//  NOTE: This file retains its original filename for Xcode project compatibility.
//  The class has been renamed to StrataTransport; the typed StrataClient
//  lives in Services/StrataClient.swift.
//

import Foundation

/// Configuration options for opening a Strata database.
struct OpenOptions {
    var accessMode: String = "read_write"  // "read_write" or "read_only"
    var autoEmbed: Bool? = nil
    var durability: String? = nil  // "standard" or "always"
    var modelEndpoint: String? = nil
    var modelName: String? = nil
    var modelApiKey: String? = nil
    var modelTimeoutMs: Int? = nil
    var embedBatchSize: Int? = nil

    func toJSON() -> String? {
        var dict: [String: Any] = [:]
        dict["access_mode"] = accessMode
        if let autoEmbed { dict["auto_embed"] = autoEmbed }
        if let durability { dict["durability"] = durability }
        if let modelEndpoint { dict["model_endpoint"] = modelEndpoint }
        if let modelName { dict["model_name"] = modelName }
        if let modelApiKey { dict["model_api_key"] = modelApiKey }
        if let modelTimeoutMs { dict["model_timeout_ms"] = modelTimeoutMs }
        if let embedBatchSize { dict["embed_batch_size"] = embedBatchSize }

        // If only default access_mode and nothing else, return nil (use defaults)
        if dict.count == 1 && accessMode == "read_write" { return nil }

        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let str = String(data: data, encoding: .utf8) else { return nil }
        return str
    }
}

/// Errors from the Strata bridge.
enum StrataError: Error, LocalizedError {
    case notOpen
    case bridgeError(String)
    case invalidResponse(String)

    var errorDescription: String? {
        switch self {
        case .notOpen:
            return "No database is open"
        case .bridgeError(let msg):
            return msg
        case .invalidResponse(let raw):
            return "Invalid response from bridge: \(raw)"
        }
    }
}

/// A parsed JSON response from the Rust bridge.
/// Every FFI call returns either `{"ok": ...}` or `{"error": ...}`,
/// except strata_execute which returns raw Output JSON on success.
private struct BridgeResponse {
    let raw: String

    /// Check if this is an error response and throw if so.
    func throwIfError() throws(StrataError) {
        guard let data = raw.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = json["error"] else {
            return
        }
        if let errorDict = error as? [String: Any],
           let data = try? JSONSerialization.data(withJSONObject: errorDict),
           let errorStr = String(data: data, encoding: .utf8) {
            throw .bridgeError(errorStr)
        }
        throw .bridgeError(String(describing: error))
    }

    /// Extract the "ok" field value as a specific type.
    func okValue<T>(_ transform: (Any) -> T?) throws(StrataError) -> T {
        try throwIfError()
        guard let data = raw.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let value = json["ok"],
              let result = transform(value) else {
            throw .invalidResponse(raw)
        }
        return result
    }
}

/// Raw async transport for interacting with a Strata database via the Rust FFI bridge.
///
/// This is the low-level wrapper. For typed command execution, use `StrataClient` instead.
@Observable
final class StrataTransport: @unchecked Sendable {
    /// The handle ID for the open database, or nil if not open.
    private(set) var handle: UInt64? = nil

    /// Whether a database is currently open.
    var isOpen: Bool { handle != nil }

    /// Dispatch queue for FFI calls (always off main thread).
    private let queue = DispatchQueue(label: "strata-bridge", qos: .userInitiated)

    // MARK: - Lifecycle

    /// Verify the bridge dylib is loaded and working.
    func ping() async throws(StrataError) -> String {
        let response = await ffiCall { withStrataString { _strata_ping() } }
        return try BridgeResponse(raw: response).okValue { $0 as? String }
    }

    /// Open an in-memory (ephemeral) database.
    func openMemory() async throws(StrataError) {
        let response = await ffiCall { withStrataString { _strata_open_memory() } }
        let id: UInt64 = try BridgeResponse(raw: response).okValue { ($0 as? NSNumber)?.uint64Value }
        handle = id
    }

    /// Open a database at a filesystem path with optional OpenOptions.
    func open(path: String, options: OpenOptions? = nil) async throws(StrataError) {
        let optionsJSON = options?.toJSON()
        let response = await ffiCall {
            path.withCString { cPath in
                if let json = optionsJSON {
                    return json.withCString { cConfig in
                        withStrataString { _strata_open(cPath, cConfig) }
                    }
                } else {
                    return withStrataString { _strata_open(cPath, nil) }
                }
            }
        }
        let id: UInt64 = try BridgeResponse(raw: response).okValue { ($0 as? NSNumber)?.uint64Value }
        handle = id
    }

    /// Close the open database.
    func close() {
        guard let h = handle else { return }
        handle = nil
        queue.async { _strata_close(h) }
    }

    // MARK: - Command Execution

    /// Execute a raw JSON command and return the raw JSON output.
    func executeRaw(_ commandJSON: String) async throws(StrataError) -> String {
        guard let h = handle else { throw .notOpen }

        let response = await ffiCall {
            commandJSON.withCString { cCmd in
                withStrataString { _strata_execute(h, cCmd) }
            }
        }

        // Check if the response is an error
        let br = BridgeResponse(raw: response)
        try br.throwIfError()

        return response
    }

    /// Execute a command given as a JSON-serializable dictionary.
    func execute(_ command: [String: Any]) async throws(StrataError) -> [String: Any] {
        guard let data = try? JSONSerialization.data(withJSONObject: command),
              let jsonStr = String(data: data, encoding: .utf8) else {
            throw .bridgeError("Failed to serialize command")
        }

        let response = try await executeRaw(jsonStr)

        guard let responseData = response.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any] else {
            throw .invalidResponse(response)
        }

        return parsed
    }

    // MARK: - Private

    /// Dispatch an FFI call to the background queue and return the result.
    private func ffiCall(_ work: @escaping @Sendable () -> String) async -> String {
        await withCheckedContinuation { continuation in
            queue.async {
                let result = work()
                continuation.resume(returning: result)
            }
        }
    }

    deinit {
        if let h = handle {
            _strata_close(h)
        }
    }
}

// MARK: - Backwards Compatibility

/// Type alias so existing code that references `StrataClient` continues to compile
/// during the incremental migration.
typealias StrataClient = StrataTransport
