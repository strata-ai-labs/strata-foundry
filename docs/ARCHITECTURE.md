# Strata Foundry — Architecture Document

## 1. Overview

Strata Foundry is a native macOS SwiftUI application that wraps StrataDB (a Rust embedded database) via FFI and integrates the Anthropic API for conversational AI. This document specifies the technical architecture across three boundaries:

1. **Rust Bridge** — C-ABI dynamic library that wraps `stratadb`
2. **Swift FFI Layer** — Swift declarations and async wrappers over the C-ABI
3. **Strata Assistant Pipeline** — Anthropic API integration with tool execution

## 2. Rust Bridge Crate (`strata-foundry-bridge`)

### 2.1 Crate Setup

```toml
[package]
name = "strata-foundry-bridge"
version = "0.1.0"
edition = "2021"

[lib]
crate-type = ["cdylib"]

[dependencies]
stratadb = { path = "../strata-core" }
serde_json = "1"
```

The crate compiles to `libstrata_foundry_bridge.dylib` (macOS). It has no features — all StrataDB features (embed, embed-metal) are selected at build time.

### 2.2 Design Principles

**JSON as the wire format.** All complex types cross the FFI boundary as JSON strings. This is intentional:

- Strata's `Value` is a recursive enum (arrays of objects of arrays). Mapping to C structs is impractical.
- `Command`, `Output`, and `Error` all derive `Serialize + Deserialize` with serde's externally-tagged format. JSON is the natural serialization.
- Swift's `Codable` decodes JSON trivially.
- The overhead of JSON encode/decode is negligible compared to database I/O and API calls.

**Opaque handles.** Rust objects (`Executor`, `Session`) are represented as opaque `*mut c_void` pointers on the Swift side. Explicit `create`/`destroy` functions manage lifetimes.

**No panics across FFI.** Every exported function catches panics with `std::panic::catch_unwind` and converts them to error JSON. A panic that crosses FFI is undefined behavior.

### 2.3 Handle Management

Two handle types correspond to the two usage patterns:

| Handle | Rust Type | Thread Safety | Use Case |
|--------|-----------|---------------|----------|
| `StrataHandle` | `Arc<HandleInner>` | Send+Sync | Stateless command execution |
| `SessionHandle` | `Box<Session>` | NOT Send+Sync | Transaction-scoped operations |

```rust
struct HandleInner {
    executor: Executor,
    db: Arc<Database>,
}
```

`StrataHandle` wraps an `Executor` (which is `Send+Sync` — verified by compile-time static assertions in stratadb). It can be called concurrently from any Swift thread. Most operations go through this handle.

`SessionHandle` wraps a `Session` (which takes `&mut self` and is NOT thread-safe). It exists only while a transaction is active. Swift must ensure single-threaded access — in practice, a Session is created, used within one async task, and destroyed.

### 2.4 C-ABI Exports

The bridge exposes a minimal, flat API. Every function follows the same pattern: accept JSON in, return JSON out.

#### Database Lifecycle

```rust
/// Open a database. Returns a handle or error JSON.
/// `path`: null-terminated UTF-8 path to .strata directory
/// `config_json`: null-terminated JSON string for OpenOptions (or null for defaults)
/// Returns: JSON string (caller must free with strata_free_string)
///   Success: {"ok": <handle_id>}
///   Error:   {"error": {"code": "...", "message": "..."}}
#[no_mangle]
pub extern "C" fn strata_open(
    path: *const c_char,
    config_json: *const c_char,
) -> *mut c_char;

/// Open an in-memory database (for scratch/testing).
#[no_mangle]
pub extern "C" fn strata_open_memory() -> *mut c_char;

/// Close a database and free the handle.
/// After this call, the handle is invalid.
#[no_mangle]
pub extern "C" fn strata_close(handle: u64);
```

#### Command Execution

```rust
/// Execute a single command against the database.
/// `handle`: handle ID from strata_open
/// `command_json`: null-terminated JSON string (externally-tagged Command)
/// Returns: JSON string (caller must free)
///   Success: the Output JSON (externally-tagged)
///   Error:   {"error": {"variant": "...", "fields": {...}}}
#[no_mangle]
pub extern "C" fn strata_execute(
    handle: u64,
    command_json: *const c_char,
) -> *mut c_char;

/// Execute multiple commands (non-transactional batch).
/// `commands_json`: JSON array of Command objects
/// Returns: JSON array of results (each Output or error)
#[no_mangle]
pub extern "C" fn strata_execute_many(
    handle: u64,
    commands_json: *const c_char,
) -> *mut c_char;
```

#### Session (Transaction) Lifecycle

```rust
/// Create a session for transaction support.
/// Returns: JSON with session_id
#[no_mangle]
pub extern "C" fn strata_session_create(handle: u64) -> *mut c_char;

/// Execute a command within a session (supports transactions).
/// Transaction commands (TxnBegin, TxnCommit, TxnRollback) go through here.
#[no_mangle]
pub extern "C" fn strata_session_execute(
    session_id: u64,
    command_json: *const c_char,
) -> *mut c_char;

/// Destroy a session. Rolls back any active transaction.
#[no_mangle]
pub extern "C" fn strata_session_destroy(session_id: u64);
```

#### Memory Management

```rust
/// Free a string returned by any strata_* function.
#[no_mangle]
pub extern "C" fn strata_free_string(ptr: *mut c_char);
```

### 2.5 Handle Registry

Handles are stored in a global concurrent map (`DashMap<u64, Arc<HandleInner>>`) keyed by auto-incrementing IDs. This avoids passing raw pointers across FFI (which Swift's strict concurrency checking dislikes) and enables handle validation.

```rust
use std::sync::atomic::{AtomicU64, Ordering};
use dashmap::DashMap;

static NEXT_ID: AtomicU64 = AtomicU64::new(1);
static HANDLES: LazyLock<DashMap<u64, Arc<HandleInner>>> = LazyLock::new(DashMap::new);
static SESSIONS: LazyLock<DashMap<u64, Mutex<Session>>> = LazyLock::new(DashMap::new);
```

Sessions wrap in `Mutex<Session>` since Session requires `&mut self`. The mutex is uncontended in practice (one Swift task per session), but prevents UB if misused.

### 2.6 JSON Wire Format

All three core types use serde's **externally-tagged** enum format:

#### Command (60 variants)

```json
{"KvPut": {"key": "user:1", "value": {"String": "Alice"}}}
{"KvGet": {"key": "user:1"}}
{"KvList": {"prefix": "user:"}}
{"EventAppend": {"event_type": "click", "payload": {"Object": {"x": {"Int": 100}}}}}
{"BranchCreate": {"branch": "experiment"}}
{"TxnBegin": {"branch": "default"}}
{"TxnCommit": null}
{"Ping": null}
{"Info": null}
```

Commands with optional `branch`/`space` fields omit them to use defaults:
```json
{"KvPut": {"key": "foo", "value": {"Int": 42}}}
```
is equivalent to:
```json
{"KvPut": {"key": "foo", "value": {"Int": 42}, "branch": "default", "space": "default"}}
```

Note: `#[serde(deny_unknown_fields)]` is set on `Command` — malformed JSON is rejected.

#### Output (32 variants)

```json
{"Unit": null}
{"Bool": true}
{"Version": 42}
{"Maybe": {"String": "hello"}}
{"Maybe": null}
{"MaybeVersioned": {"value": {"Int": 42}, "version": 3, "timestamp": 1708444800000}}
{"VersionedValues": [{"value": {"Int": 1}, "version": 1, "timestamp": 1708444800000}]}
{"Keys": ["user:1", "user:2", "user:3"]}
{"Pong": {"version": "0.5.1"}}
{"DatabaseInfo": {"branch_count": 3, "total_keys": 847, ...}}
{"TxnBegun": null}
{"TxnCommitted": {"version": 7}}
{"SearchResults": [{"entity_key": "doc:1", "score": 0.92, ...}]}
```

#### Error (26 variants)

```json
{"KeyNotFound": {"key": "nonexistent"}}
{"InvalidInput": {"reason": "key cannot be empty"}}
{"TransactionNotActive": null}
{"VersionConflict": {"expected": 5, "actual": 7, "expected_type": "...", "actual_type": "..."}}
{"AccessDenied": {"command": "KvPut"}}
```

#### Value (8 variants)

```json
"Null"
{"Bool": true}
{"Int": 42}
{"Float": 3.14}
{"String": "hello"}
{"Bytes": [0, 1, 2, 255]}
{"Array": [{"Int": 1}, {"String": "two"}]}
{"Object": {"name": {"String": "Alice"}, "age": {"Int": 30}}}
```

**Key gotcha for Swift:** `Value::Null` serializes as the JSON string `"Null"`, not JSON `null`. `Value::Int(42)` serializes as `{"Int": 42}`, not `42`. The Swift `Value` type must use a custom `Codable` implementation that handles externally-tagged enums.

## 3. Swift FFI Layer

### 3.1 C Function Declarations (`StrataFFI.swift`)

```swift
import Foundation

// All functions return JSON strings that must be freed with strata_free_string
@_silgen_name("strata_open")
func strata_open(_ path: UnsafePointer<CChar>, _ config: UnsafePointer<CChar>?) -> UnsafeMutablePointer<CChar>

@_silgen_name("strata_open_memory")
func strata_open_memory() -> UnsafeMutablePointer<CChar>

@_silgen_name("strata_close")
func strata_close(_ handle: UInt64)

@_silgen_name("strata_execute")
func strata_execute(_ handle: UInt64, _ command: UnsafePointer<CChar>) -> UnsafeMutablePointer<CChar>

@_silgen_name("strata_execute_many")
func strata_execute_many(_ handle: UInt64, _ commands: UnsafePointer<CChar>) -> UnsafeMutablePointer<CChar>

@_silgen_name("strata_session_create")
func strata_session_create(_ handle: UInt64) -> UnsafeMutablePointer<CChar>

@_silgen_name("strata_session_execute")
func strata_session_execute(_ session: UInt64, _ command: UnsafePointer<CChar>) -> UnsafeMutablePointer<CChar>

@_silgen_name("strata_session_destroy")
func strata_session_destroy(_ session: UInt64)

@_silgen_name("strata_free_string")
func strata_free_string(_ ptr: UnsafeMutablePointer<CChar>)
```

### 3.2 StrataClient — Async Swift Wrapper

`StrataClient` is the high-level Swift API that ViewModels and ClaudeClient call. It wraps the raw FFI calls with:

1. **Async dispatch** — all FFI calls run on a background thread via Swift concurrency
2. **JSON encode/decode** — Swift `Codable` types map to the Rust wire format
3. **Error mapping** — Rust error JSON is decoded into Swift `StrataError` cases
4. **String lifecycle** — every returned C string is consumed and freed immediately

```swift
@MainActor
final class StrataClient: ObservableObject {
    private var handle: UInt64 = 0
    private let queue = DispatchQueue(label: "strata-bridge", qos: .userInitiated)

    var isOpen: Bool { handle != 0 }

    func open(path: URL, options: OpenOptions? = nil) async throws { ... }
    func openMemory() async throws { ... }
    func close() { ... }

    func execute(_ command: StrataCommand) async throws -> StrataOutput { ... }
    func executeMany(_ commands: [StrataCommand]) async throws -> [Result<StrataOutput, StrataError>] { ... }

    // Convenience methods
    func kvGet(key: String) async throws -> VersionedValue? { ... }
    func kvPut(key: String, value: StrataValue) async throws -> UInt64 { ... }
    func kvList(prefix: String?) async throws -> [String] { ... }
    func kvDelete(key: String) async throws { ... }
    // ... similar for all primitives
}
```

The `execute` method is the core:

```swift
func execute(_ command: StrataCommand) async throws -> StrataOutput {
    let json = try JSONEncoder().encode(command)
    let jsonString = String(data: json, encoding: .utf8)!

    return try await withCheckedThrowingContinuation { continuation in
        queue.async {
            let resultPtr = jsonString.withCString { cStr in
                strata_execute(self.handle, cStr)
            }
            defer { strata_free_string(resultPtr) }

            let resultString = String(cString: resultPtr)
            let resultData = resultString.data(using: .utf8)!

            // Try to decode as Output first, then as Error
            if let output = try? JSONDecoder().decode(StrataOutput.self, from: resultData) {
                continuation.resume(returning: output)
            } else if let error = try? JSONDecoder().decode(StrataError.self, from: resultData) {
                continuation.resume(throwing: error)
            } else {
                continuation.resume(throwing: StrataError.internal("Unexpected response: \(resultString)"))
            }
        }
    }
}
```

### 3.3 Swift Type Mappings

#### StrataValue

The main complexity is mapping Strata's tagged-enum `Value` to a Swift type that SwiftUI can render and edit.

```swift
/// Maps to Rust's Value enum with externally-tagged serde format.
enum StrataValue: Codable, Hashable {
    case null
    case bool(Bool)
    case int(Int64)
    case float(Double)
    case string(String)
    case bytes([UInt8])
    case array([StrataValue])
    case object([String: StrataValue])

    // Custom Codable to match Rust's externally-tagged format:
    //   "Null"           → .null
    //   {"Bool": true}   → .bool(true)
    //   {"Int": 42}      → .int(42)
    //   {"Float": 3.14}  → .float(3.14)
    //   {"String": "hi"} → .string("hi")
    //   etc.
}
```

Custom `Codable` is required because serde's externally-tagged format doesn't match any of Swift's default enum encoding strategies. The implementation decodes a single-key dictionary and switches on the key name.

#### StrataCommand

```swift
/// One-to-one mapping to Rust's Command enum (60 variants).
/// Only the variants needed for current features are implemented;
/// others are added as needed.
enum StrataCommand: Encodable {
    case kvPut(key: String, value: StrataValue, branch: String? = nil, space: String? = nil)
    case kvGet(key: String, branch: String? = nil, space: String? = nil)
    case kvDelete(key: String, branch: String? = nil, space: String? = nil)
    case kvList(prefix: String? = nil, branch: String? = nil, space: String? = nil)
    // ... all 60 variants

    // Custom Encodable to produce externally-tagged JSON:
    //   .kvPut(key: "x", value: .int(1)) → {"KvPut": {"key": "x", "value": {"Int": 1}}}
}
```

#### StrataOutput

```swift
/// Maps to Rust's Output enum (32 variants).
enum StrataOutput: Decodable {
    case unit
    case maybe(StrataValue?)
    case maybeVersioned(VersionedValue?)
    case version(UInt64)
    case bool(Bool)
    case uint(UInt64)
    case versionedValues([VersionedValue])
    case keys([String])
    case databaseInfo(DatabaseInfo)
    case pong(version: String)
    case txnBegun
    case txnCommitted(version: UInt64)
    case txnAborted
    case searchResults([SearchResultHit])
    case spaceList([String])
    // ... all variants

    // Custom Decodable to match externally-tagged format
}
```

#### StrataError

```swift
/// Maps to Rust's Error enum (26 variants).
enum StrataError: Error, Decodable {
    case keyNotFound(key: String)
    case branchNotFound(branch: String)
    case invalidInput(reason: String)
    case versionConflict(expected: UInt64, actual: UInt64)
    case transactionNotActive
    case accessDenied(command: String)
    case io(reason: String)
    case `internal`(String)
    // ... all variants
}
```

## 4. Strata Assistant Pipeline

### 4.1 Architecture

```
User Input
    |
    v
ConversationViewModel
    |
    v
ClaudeClient.sendMessage(messages, tools)
    |
    v
Anthropic API  (POST /v1/messages)
    |                           |
    v                           v
Text blocks              tool_use blocks
    |                           |
    v                           |
Render in                       v
conversation              ToolExecutor.execute(name, input)
                                |
                                v
                          StrataClient.execute(command)
                                |
                                v
                          FFI → Rust → stratadb
                                |
                                v
                          tool_result JSON
                                |
                                v
                          Send back to API (continuation turn)
                                |
                                v
                          Final text + any more tool calls
                                |
                                v
                          PanelFactory.createPanels(results)
                                |
                    +-----------+-----------+
                    |                       |
                    v                       v
              Workspace:              Focus:
              add to canvas           inline artifact
```

### 4.2 ClaudeClient

Handles communication with the Anthropic Messages API.

```swift
final class ClaudeClient {
    private let apiKey: String
    private let model: String  // e.g. "claude-sonnet-4-6"
    private let session: URLSession

    /// Send a message in a conversation, handling the full tool-use loop.
    /// Returns when Claude produces a final text response (no more tool calls).
    func sendMessage(
        conversation: Conversation,
        tools: [ToolDefinition],
        toolExecutor: ToolExecutor
    ) async throws -> ConversationTurn {
        var messages = conversation.toAPIMessages()

        while true {
            let response = try await callAPI(messages: messages, tools: tools)

            // Separate text and tool_use blocks
            let textBlocks = response.content.filter { $0.type == "text" }
            let toolBlocks = response.content.filter { $0.type == "tool_use" }

            if toolBlocks.isEmpty {
                // Final response — no more tool calls
                return ConversationTurn(
                    role: .assistant,
                    text: textBlocks.map(\.text).joined(),
                    toolResults: collectedResults
                )
            }

            // Execute each tool call
            var toolResults: [ToolResult] = []
            for block in toolBlocks {
                let result = await toolExecutor.execute(
                    name: block.name,
                    input: block.input
                )
                toolResults.append(ToolResult(
                    toolUseId: block.id,
                    content: result.json
                ))
            }

            // Append assistant message + tool results, continue loop
            messages.append(AssistantMessage(content: response.content))
            messages.append(UserMessage(content: toolResults.map { .toolResult($0) }))
        }
    }
}
```

### 4.3 Tool Definitions

Each of Strata's 60 commands becomes an Anthropic tool definition. The tool definitions are generated from a static catalog — not hard-coded per-tool — to keep them in sync with stratadb.

```swift
struct ToolDefinitions {
    /// All Strata command tools for the Anthropic API.
    static let allTools: [ToolDefinition] = [
        ToolDefinition(
            name: "kv_put",
            description: "Store a key-value pair in the KV store",
            inputSchema: .object(properties: [
                "key": .string(description: "The key to store"),
                "value": .strataValue(description: "The value to store"),
                "branch": .string(description: "Branch name (default: current)", required: false),
                "space": .string(description: "Space name (default: current)", required: false),
            ])
        ),
        ToolDefinition(
            name: "kv_get",
            description: "Retrieve a value by key from the KV store",
            inputSchema: .object(properties: [
                "key": .string(description: "The key to retrieve"),
                "branch": .string(required: false),
                "space": .string(required: false),
            ])
        ),
        // ... all 60 commands
    ]
}
```

### 4.4 ToolExecutor

Translates Anthropic tool calls into StrataClient commands.

```swift
final class ToolExecutor {
    private let client: StrataClient
    private let currentBranch: String
    private let currentSpace: String

    /// Execute a tool call from the Anthropic API.
    /// Maps tool name + JSON input → StrataCommand → execute → JSON result.
    func execute(name: String, input: [String: Any]) async -> ToolExecutionResult {
        do {
            let command = try mapToCommand(name: name, input: input)
            let output = try await client.execute(command)
            return ToolExecutionResult(
                success: true,
                output: output,
                json: encodeOutput(output)
            )
        } catch {
            return ToolExecutionResult(
                success: false,
                output: nil,
                json: encodeError(error)
            )
        }
    }

    /// Map a tool name and input dict to a StrataCommand.
    private func mapToCommand(name: String, input: [String: Any]) throws -> StrataCommand {
        switch name {
        case "kv_put":
            let key = input["key"] as! String
            let value = try decodeStrataValue(input["value"]!)
            return .kvPut(key: key, value: value)
        case "kv_get":
            let key = input["key"] as! String
            return .kvGet(key: key)
        // ... all tools
        default:
            throw ToolError.unknownTool(name)
        }
    }
}
```

### 4.5 PanelFactory

Converts tool execution results into panel models for the workspace or inline artifacts for focus mode.

```swift
struct PanelFactory {
    /// Determine what panel(s) to create from a tool execution result.
    static func createPanels(
        toolName: String,
        output: StrataOutput,
        context: PanelContext
    ) -> [PanelModel] {
        switch (toolName, output) {
        case ("kv_list", .keys(let keys)):
            // Fetch values for each key to build a table
            return [.kvTable(keys: keys, context: context)]

        case ("kv_get", .maybeVersioned(let vv)):
            // Single key-value detail
            return [.kvDetail(value: vv, context: context)]

        case ("event_get", .versionedValues(let events)):
            return [.eventList(events: events, context: context)]

        case ("info", .databaseInfo(let info)):
            return [.databaseInfo(info: info)]

        case ("branch_list", .branchInfoList(let branches)):
            return [.branchInfo(branches: branches)]

        case ("search", .searchResults(let hits)):
            return [.searchResults(hits: hits, context: context)]

        // ... mappings for all tool/output combinations

        default:
            // Fallback: raw JSON output panel
            return [.rawOutput(json: encodeJSON(output))]
        }
    }
}
```

### 4.6 Conversation Model

```swift
struct Conversation {
    var turns: [ConversationTurn] = []
    var systemPrompt: String

    // System prompt includes database context
    static func systemPrompt(
        database: DatabaseInfo?,
        branch: String,
        space: String,
        visiblePanels: [PanelModel]
    ) -> String {
        """
        You are Strata Assistant, an AI assistant embedded in Strata Foundry. \
        You have access to a StrataDB database and can execute any database \
        command as a tool call.

        Current database: \(database?.path ?? "none open")
        Current branch: \(branch)
        Current space: \(space)
        Visible panels: \(visiblePanels.map(\.summary).joined(separator: ", "))

        When the user asks about data, use the appropriate tools to query \
        the database and provide answers. Format data clearly. When tool \
        results produce tabular data, the UI will render them as interactive \
        panels automatically.
        """
    }
}

struct ConversationTurn: Identifiable {
    let id = UUID()
    let role: Role          // .user, .assistant
    let text: String        // Text content
    let toolCalls: [ToolCall]       // Tool calls made (assistant only)
    let toolResults: [ToolResult]   // Results from tool execution
    let panels: [PanelModel]        // Panels generated from results
    let timestamp: Date
}
```

## 5. State Management

### 5.1 App State

```swift
@MainActor
final class AppState: ObservableObject {
    /// All open database windows
    @Published var openDatabases: [DatabaseDocument] = []

    /// API key (loaded from Keychain)
    @Published var apiKey: String?

    /// User preferences
    @Published var preferences: AppPreferences
}
```

### 5.2 Per-Window State

Each database window (NSDocument) owns its own state tree:

```swift
@MainActor
final class DatabaseDocument: ObservableObject {
    // Database connection
    let client: StrataClient

    // Strata Assistant (nil if no API key)
    var claude: ClaudeClient?

    // Current context
    @Published var currentBranch: String = "default"
    @Published var currentSpace: String = "default"

    // Workspace state
    @Published var panels: [PanelModel] = []
    @Published var conversation: Conversation

    // Undo stack
    let undoManager: StrataUndoManager

    // External change detection
    private var changePoller: ChangePoller?
}
```

### 5.3 Panel Models

```swift
/// A panel on the workspace canvas or an inline artifact in focus mode.
struct PanelModel: Identifiable {
    let id = UUID()
    var kind: PanelKind
    var position: CGPoint       // Workspace position
    var size: CGSize            // Workspace size
    var isMinimized: Bool = false
    var isPinned: Bool = false  // Pinned from focus mode

    var summary: String { ... } // One-line description for Claude context
}

enum PanelKind {
    case kvTable(KVTableState)
    case eventList(EventListState)
    case stateCells(StateCellsState)
    case jsonTree(JsonTreeState)
    case vectorCollection(VectorCollectionState)
    case branchInfo(BranchInfoState)
    case history(HistoryState)
    case databaseInfo(DatabaseInfoState)
    case searchResults(SearchResultsState)
    case rawOutput(String)
}
```

## 6. Undo System

Undo leverages Strata's versioning — every write produces a version number, and previous values can be read via `as_of` or history queries.

```swift
final class StrataUndoManager {
    private var undoStack: [UndoAction] = []
    private var redoStack: [UndoAction] = []

    struct UndoAction {
        let description: String
        let undoCommand: StrataCommand   // Command to reverse the action
        let redoCommand: StrataCommand   // Command to re-apply
    }

    /// Record an action that can be undone.
    /// Called by StrataClient after every successful write.
    func record(_ action: UndoAction) { ... }

    /// Undo the last action by executing undoCommand.
    func undo(client: StrataClient) async throws { ... }

    /// Redo the last undone action.
    func redo(client: StrataClient) async throws { ... }
}
```

For KV operations:
- `kv_put(key, newValue)` → undo is `kv_put(key, oldValue)` (restore previous) or `kv_delete(key)` (if key was new)
- `kv_delete(key)` → undo is `kv_put(key, oldValue)`
- Events are append-only — no undo for `event_append`

The StrataClient fetches the current value before writes to capture undo state. This adds one extra read per write but is necessary for correct undo.

## 7. External Change Detection

A background poller monitors for external database changes (e.g., from CLI tools, MCP, or the agent runtime).

```swift
final class ChangePoller {
    private let client: StrataClient
    private let interval: TimeInterval = 1.5  // seconds
    private var lastKnownVersion: UInt64 = 0
    private var task: Task<Void, Never>?

    func start(onChanges: @escaping () -> Void) {
        task = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(interval))
                let info = try? await client.execute(.info)
                if case .databaseInfo(let db) = info, db.latestVersion > lastKnownVersion {
                    lastKnownVersion = db.latestVersion
                    await MainActor.run { onChanges() }
                }
            }
        }
    }

    func stop() { task?.cancel() }
}
```

When changes are detected, all visible panels refresh their data. The refresh is debounced to avoid UI thrashing.

## 8. Threading Model

```
Main Thread (SwiftUI)
  |
  |-- ViewModels (@MainActor, publish state changes)
  |     |
  |     +-- async methods dispatch to...
  |
Background (Swift concurrency / DispatchQueue)
  |
  |-- StrataClient.execute() → FFI call → Rust
  |     |
  |     +-- strata_execute() runs on Rust's calling thread
  |           (Executor is Send+Sync, safe from any thread)
  |
  |-- ClaudeClient.sendMessage() → URLSession → Anthropic API
  |
  |-- ChangePoller → periodic FFI calls
```

Rules:
- **SwiftUI views** read `@Published` properties on the main thread
- **FFI calls** always happen off the main thread (via async dispatch)
- **Executor** (`&self`) can be called from any thread concurrently
- **Session** (`&mut self`, wrapped in `Mutex`) — one active caller at a time
- **API calls** use URLSession's built-in async support

## 9. Build Pipeline

### 9.1 Directory Layout

```
strata-foundry/
  StrataFoundry/                      # Xcode project
    StrataFoundry/                    # Swift source
      ...
    StrataFoundry.xcodeproj
  strata-foundry-bridge/              # Rust cdylib crate
    Cargo.toml
    src/
      lib.rs
      handle.rs
      convert.rs
  docs/
    PRD.md
    ARCHITECTURE.md
  Makefile
```

### 9.2 Build Steps

```makefile
BRIDGE_DIR = strata-foundry-bridge
DYLIB_NAME = libstrata_foundry_bridge.dylib
TARGET_DIR = $(BRIDGE_DIR)/target/release

# Build the Rust bridge dylib (universal binary for Apple Silicon + Intel)
bridge:
	cd $(BRIDGE_DIR) && cargo build --release --target aarch64-apple-darwin
	cd $(BRIDGE_DIR) && cargo build --release --target x86_64-apple-darwin
	lipo -create \
		$(BRIDGE_DIR)/target/aarch64-apple-darwin/release/$(DYLIB_NAME) \
		$(BRIDGE_DIR)/target/x86_64-apple-darwin/release/$(DYLIB_NAME) \
		-output $(BRIDGE_DIR)/target/release/$(DYLIB_NAME)

# Copy dylib to Xcode project
install: bridge
	cp $(TARGET_DIR)/$(DYLIB_NAME) StrataFoundry/Frameworks/

# Build everything
all: install
	xcodebuild -project StrataFoundry/StrataFoundry.xcodeproj \
		-scheme StrataFoundry \
		-configuration Release \
		build

# Development: build Rust + launch Xcode
dev: install
	open StrataFoundry/StrataFoundry.xcodeproj
```

### 9.3 Xcode Configuration

- **Framework Search Path:** `$(PROJECT_DIR)/Frameworks`
- **Runpath Search Path:** `@executable_path/../Frameworks`
- **Linking:** `libstrata_foundry_bridge.dylib` added to "Link Binary with Libraries" build phase
- **Copy Files Phase:** copies the dylib into `StrataFoundry.app/Contents/Frameworks/`
- **Code Signing:** The dylib is code-signed as part of the app bundle (required for notarization)

### 9.4 Distribution

DMG packaging:
1. Archive the app via `xcodebuild archive`
2. Export the `.app` from the archive
3. Codesign with Developer ID certificate (for notarization)
4. Submit to Apple notarization service (`xcrun notarytool`)
5. Staple the notarization ticket
6. Package into a DMG with `hdiutil`

## 10. Security Considerations

### API Key Storage
- Anthropic API key stored in macOS Keychain (not UserDefaults, not files)
- Key only loaded into memory when making API calls
- Never logged, never included in crash reports

### Database Access
- The app opens database files with user-level filesystem permissions
- No network access to database files — always local
- ReadOnly mode available for inspection without risk of modification

### FFI Safety
- All C strings validated for UTF-8 before conversion
- All handles validated before use (invalid handle → error JSON, not crash)
- Panic catching on every FFI boundary (`catch_unwind`)
- No raw pointer passing across FFI — integer handle IDs only

## 11. Open Questions

These are deferred for future design rounds:

1. **Streaming tool results** — Should Strata Assistant stream partial results as tool calls execute, or wait for all tools to complete? Streaming provides better UX for slow operations but complicates the tool-use loop.

2. **Conversation persistence** — Should conversation history persist across app launches? If so, stored where (in the Strata database itself, or a separate app-local store)?

3. **Panel layout persistence** — Should workspace panel arrangements be saved per-database?

4. **Offline tool execution** — The `/` command bar works without an API key. Should there be a richer command palette UI for users without API keys?

5. **Model selection** — Should users be able to choose the Claude model (Opus/Sonnet/Haiku) for Strata Assistant? Cost vs capability tradeoff.

6. **Rate limiting** — How to handle Anthropic API rate limits gracefully in the UI?

7. **Large result sets** — When a `kv_list` returns 10,000 keys, should the tool result be truncated before sending to Claude? The API has token limits.

8. **Multi-database Claude context** — If multiple database windows are open, does each have its own conversation, or is there a global Claude session?
