//
//  StrataFFI.swift
//  StrataFoundry
//
//  Raw C-ABI function declarations for libstrata_foundry_bridge.
//  These map directly to the #[no_mangle] extern "C" functions in Rust.
//
//  All functions that return strings return heap-allocated C strings
//  that MUST be freed with strata_free_string().
//

import Foundation

// MARK: - C Function Declarations

/// Verify the bridge dylib is loaded. Returns `{"ok":"strata-foundry-bridge"}`.
@_silgen_name("strata_ping")
nonisolated func _strata_ping() -> UnsafeMutablePointer<CChar>

/// Open a database at a filesystem path.
/// - Parameters:
///   - path: Null-terminated UTF-8 path to a .strata directory
///   - config: Null-terminated JSON string for OpenOptions, or nil for defaults
/// - Returns: JSON string `{"ok": <handle_id>}` or `{"error": {...}}`
@_silgen_name("strata_open")
nonisolated func _strata_open(
    _ path: UnsafePointer<CChar>,
    _ config: UnsafePointer<CChar>?
) -> UnsafeMutablePointer<CChar>

/// Open an in-memory (ephemeral) database.
/// - Returns: JSON string `{"ok": <handle_id>}` or `{"error": {...}}`
@_silgen_name("strata_open_memory")
nonisolated func _strata_open_memory() -> UnsafeMutablePointer<CChar>

/// Close a database handle. The handle is invalid after this call.
@_silgen_name("strata_close")
nonisolated func _strata_close(_ handle: UInt64)

/// Execute a single command against a database.
/// - Parameters:
///   - handle: Handle ID from strata_open/strata_open_memory
///   - command: Null-terminated JSON string (externally-tagged Command)
/// - Returns: JSON string — Output on success, `{"error": {...}}` on failure
@_silgen_name("strata_execute")
nonisolated func _strata_execute(
    _ handle: UInt64,
    _ command: UnsafePointer<CChar>
) -> UnsafeMutablePointer<CChar>

/// Free a string returned by any strata_* function.
@_silgen_name("strata_free_string")
nonisolated func _strata_free_string(_ ptr: UnsafeMutablePointer<CChar>)

// MARK: - Safe Wrappers

/// Call a Rust FFI function that returns a C string, convert to Swift String, and free.
nonisolated func withStrataString(_ call: () -> UnsafeMutablePointer<CChar>) -> String {
    let ptr = call()
    let result = String(cString: ptr)
    _strata_free_string(ptr)
    return result
}
