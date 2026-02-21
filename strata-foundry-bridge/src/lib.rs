//! C-ABI bridge from Swift (Strata Foundry) to stratadb.
//!
//! All complex types cross the FFI boundary as JSON strings.
//! Integer handle IDs are used instead of raw pointers.

mod handle;

use std::ffi::{CStr, CString};
use std::os::raw::c_char;

use handle::HandleRegistry;

/// Global handle registry — manages all open database handles and sessions.
static REGISTRY: std::sync::LazyLock<HandleRegistry> = std::sync::LazyLock::new(HandleRegistry::new);

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Convert a C string pointer to a Rust &str. Returns None if null or invalid UTF-8.
unsafe fn cstr_to_str<'a>(ptr: *const c_char) -> Option<&'a str> {
    if ptr.is_null() {
        return None;
    }
    unsafe { CStr::from_ptr(ptr) }.to_str().ok()
}

/// Convert a Rust string to a C string the caller must free with `strata_free_string`.
fn to_c_string(s: &str) -> *mut c_char {
    CString::new(s).unwrap_or_default().into_raw()
}

/// Wrap a closure in panic-catching. Returns JSON error on panic.
fn catch_panic<F: FnOnce() -> String + std::panic::UnwindSafe>(f: F) -> *mut c_char {
    match std::panic::catch_unwind(f) {
        Ok(json) => to_c_string(&json),
        Err(_) => to_c_string(r#"{"error":{"Internal":{"reason":"panic in Rust bridge"}}}"#),
    }
}

/// Format a success result as JSON: `{"ok": <value>}`
fn ok_json(value: &str) -> String {
    format!(r#"{{"ok":{}}}"#, value)
}

/// Format an error result as JSON: `{"error": <error_json>}`
fn error_json(msg: &str) -> String {
    format!(r#"{{"error":{{"Internal":{{"reason":{}}}}}}}"#, serde_json::json!(msg))
}

// ---------------------------------------------------------------------------
// Database lifecycle
// ---------------------------------------------------------------------------

/// Open a database at the given path.
///
/// # Arguments
/// - `path`: null-terminated UTF-8 path to a `.strata` directory
/// - `config_json`: null-terminated JSON string for OpenOptions, or null for defaults
///
/// # Returns
/// JSON string (caller must free with `strata_free_string`):
/// - Success: `{"ok": <handle_id>}`
/// - Error: `{"error": {...}}`
#[no_mangle]
pub extern "C" fn strata_open(path: *const c_char, config_json: *const c_char) -> *mut c_char {
    catch_panic(|| {
        let path_str = match unsafe { cstr_to_str(path) } {
            Some(s) => s,
            None => return error_json("path is null or invalid UTF-8"),
        };

        let _config_str = unsafe { cstr_to_str(config_json) };
        // TODO: parse OpenOptions from config_json

        match REGISTRY.open(path_str) {
            Ok(id) => ok_json(&id.to_string()),
            Err(e) => error_json(&e),
        }
    })
}

/// Open an in-memory (ephemeral) database.
///
/// # Returns
/// JSON string: `{"ok": <handle_id>}` or `{"error": {...}}`
#[no_mangle]
pub extern "C" fn strata_open_memory() -> *mut c_char {
    catch_panic(|| match REGISTRY.open_memory() {
        Ok(id) => ok_json(&id.to_string()),
        Err(e) => error_json(&e),
    })
}

/// Close a database and free its handle.
#[no_mangle]
pub extern "C" fn strata_close(handle: u64) {
    REGISTRY.close(handle);
}

// ---------------------------------------------------------------------------
// Command execution
// ---------------------------------------------------------------------------

/// Execute a single command against a database.
///
/// # Arguments
/// - `handle`: handle ID from `strata_open`
/// - `command_json`: null-terminated JSON string (externally-tagged Command)
///
/// # Returns
/// JSON string (caller must free):
/// - Success: the Output JSON (externally-tagged)
/// - Error: `{"error": {...}}`
#[no_mangle]
pub extern "C" fn strata_execute(handle: u64, command_json: *const c_char) -> *mut c_char {
    catch_panic(|| {
        let json_str = match unsafe { cstr_to_str(command_json) } {
            Some(s) => s,
            None => return error_json("command_json is null or invalid UTF-8"),
        };

        match REGISTRY.execute(handle, json_str) {
            Ok(output) => output,
            Err(e) => error_json(&e),
        }
    })
}

// ---------------------------------------------------------------------------
// Memory management
// ---------------------------------------------------------------------------

/// Free a string returned by any `strata_*` function.
///
/// # Safety
/// `ptr` must have been returned by a `strata_*` function and not yet freed.
#[no_mangle]
pub unsafe extern "C" fn strata_free_string(ptr: *mut c_char) {
    if !ptr.is_null() {
        unsafe {
            let _ = CString::from_raw(ptr);
        }
    }
}

// ---------------------------------------------------------------------------
// Smoke test
// ---------------------------------------------------------------------------

/// Returns `{"ok": "strata-foundry-bridge"}`. Use to verify the dylib loads.
#[no_mangle]
pub extern "C" fn strata_ping() -> *mut c_char {
    to_c_string(r#"{"ok":"strata-foundry-bridge"}"#)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_open_memory_and_execute_ping() {
        let result_ptr = strata_open_memory();
        let result = unsafe { CStr::from_ptr(result_ptr) }.to_str().unwrap().to_string();
        unsafe { strata_free_string(result_ptr) };

        // Parse handle ID
        let v: serde_json::Value = serde_json::from_str(&result).unwrap();
        let handle_id = v["ok"].as_u64().expect("expected ok with handle id");

        // Execute Ping command
        let cmd = CString::new(r#"{"Ping":null}"#).unwrap();
        let out_ptr = strata_execute(handle_id, cmd.as_ptr());
        let out = unsafe { CStr::from_ptr(out_ptr) }.to_str().unwrap().to_string();
        unsafe { strata_free_string(out_ptr) };

        let v: serde_json::Value = serde_json::from_str(&out).unwrap();
        assert!(v["Pong"].is_object(), "Expected Pong, got: {}", out);

        strata_close(handle_id);
    }

    #[test]
    fn test_strata_ping() {
        let ptr = strata_ping();
        let s = unsafe { CStr::from_ptr(ptr) }.to_str().unwrap().to_string();
        unsafe { strata_free_string(ptr) };
        assert_eq!(s, r#"{"ok":"strata-foundry-bridge"}"#);
    }

    /// Debug: open the sample DB and print actual JSON responses.
    #[test]
    #[ignore]
    fn debug_sample_db_responses() {
        let path = "/Users/aniruddhajoshi/Documents/strata-foundry-sample/.strata";
        let path_c = CString::new(path).unwrap();

        let result_ptr = strata_open(path_c.as_ptr(), std::ptr::null());
        let result = unsafe { CStr::from_ptr(result_ptr) }.to_str().unwrap().to_string();
        unsafe { strata_free_string(result_ptr) };
        println!("strata_open => {result}");

        let v: serde_json::Value = serde_json::from_str(&result).unwrap();
        let handle_id = v["ok"].as_u64().expect(&format!("expected ok, got: {result}"));

        let commands = [
            ("Info", r#"{"Info":null}"#),
            ("KvList", r#"{"KvList":{}}"#),
            ("KvGet user:alice", r#"{"KvGet":{"key":"user:alice"}}"#),
            ("StateList", r#"{"StateList":{}}"#),
            ("EventLen", r#"{"EventLen":{}}"#),
            ("EventGet seq=0", r#"{"EventGet":{"sequence":0}}"#),
            ("EventGet seq=1", r#"{"EventGet":{"sequence":1}}"#),
            ("JsonList", r#"{"JsonList":{"limit":1000}}"#),
            ("BranchList", r#"{"BranchList":{}}"#),
            ("VectorListCollections", r#"{"VectorListCollections":{}}"#),
        ];

        for (name, cmd) in commands {
            let cmd_c = CString::new(cmd).unwrap();
            let out_ptr = strata_execute(handle_id, cmd_c.as_ptr());
            let out = unsafe { CStr::from_ptr(out_ptr) }.to_str().unwrap().to_string();
            unsafe { strata_free_string(out_ptr) };
            println!("\n{name}:\n  cmd: {cmd}\n  out: {out}");
        }

        strata_close(handle_id);
    }

    /// Create a sample database with realistic data.
    /// Run with:
    ///   cargo test create_sample_db -- --nocapture --ignored
    #[test]
    #[ignore]
    fn create_sample_db() {
        use stratadb::{Strata, Value};
        use std::collections::HashMap;

        let path = std::env::var("STRATA_SAMPLE_PATH")
            .unwrap_or_else(|_| "/Users/aniruddhajoshi/Documents/strata-foundry-sample/.strata".into());

        // Remove old sample if exists
        let _ = std::fs::remove_dir_all(&path);

        let db = Strata::open(&path).expect("failed to create sample db");

        // Helper to build objects
        fn obj(pairs: Vec<(&str, Value)>) -> Value {
            Value::Object(pairs.into_iter().map(|(k, v)| (k.to_string(), v)).collect::<HashMap<_, _>>())
        }

        // =====================================================================
        // KV Store — 15 keys across several namespaces
        // =====================================================================

        // Users
        db.kv_put("user:alice", obj(vec![
            ("name", Value::String("Alice Chen".into())),
            ("email", Value::String("alice@example.com".into())),
            ("age", Value::Int(30)),
            ("role", Value::String("admin".into())),
            ("active", Value::Bool(true)),
        ])).unwrap();
        db.kv_put("user:bob", obj(vec![
            ("name", Value::String("Bob Martinez".into())),
            ("email", Value::String("bob@example.com".into())),
            ("age", Value::Int(25)),
            ("role", Value::String("developer".into())),
            ("active", Value::Bool(true)),
        ])).unwrap();
        db.kv_put("user:carol", obj(vec![
            ("name", Value::String("Carol Kim".into())),
            ("email", Value::String("carol@example.com".into())),
            ("age", Value::Int(35)),
            ("role", Value::String("designer".into())),
            ("active", Value::Bool(false)),
        ])).unwrap();

        // Config
        db.kv_put("config:app_version", Value::String("2.1.0".into())).unwrap();
        db.kv_put("config:max_retries", Value::Int(3)).unwrap();
        db.kv_put("config:timeout_ms", Value::Int(5000)).unwrap();
        db.kv_put("config:debug_mode", Value::Bool(false)).unwrap();
        db.kv_put("config:allowed_origins", Value::Array(vec![
            Value::String("https://app.strata.dev".into()),
            Value::String("https://localhost:3000".into()),
            Value::String("https://staging.strata.dev".into()),
        ])).unwrap();

        // Counters
        db.kv_put("counter:page_views", Value::Int(48291)).unwrap();
        db.kv_put("counter:api_calls", Value::Int(152847)).unwrap();
        db.kv_put("counter:errors", Value::Int(37)).unwrap();

        // Cache
        db.kv_put("cache:trending_topics", Value::Array(vec![
            Value::String("rust".into()),
            Value::String("ai-agents".into()),
            Value::String("embedded-databases".into()),
            Value::String("swiftui".into()),
        ])).unwrap();
        db.kv_put("cache:exchange_rates", obj(vec![
            ("USD_EUR", Value::Float(0.92)),
            ("USD_GBP", Value::Float(0.79)),
            ("USD_JPY", Value::Float(149.85)),
            ("updated_at", Value::String("2026-02-20T15:00:00Z".into())),
        ])).unwrap();

        // Session
        db.kv_put("session:abc123", obj(vec![
            ("user_id", Value::String("alice".into())),
            ("created_at", Value::String("2026-02-20T14:30:00Z".into())),
            ("expires_at", Value::String("2026-02-21T14:30:00Z".into())),
            ("ip", Value::String("192.168.1.42".into())),
        ])).unwrap();

        // =====================================================================
        // State Cells — 8 cells tracking agent state
        // =====================================================================

        db.state_set("agent:status", Value::String("idle".into())).unwrap();
        db.state_set("agent:step_count", Value::Int(47)).unwrap();
        db.state_set("agent:last_action", Value::String("tool_call: search_docs".into())).unwrap();
        db.state_set("agent:memory_mb", Value::Float(128.5)).unwrap();
        db.state_set("agent:errors_total", Value::Int(2)).unwrap();
        db.state_set("agent:last_error", obj(vec![
            ("message", Value::String("API rate limit exceeded".into())),
            ("code", Value::Int(429)),
            ("timestamp", Value::String("2026-02-20T14:28:00Z".into())),
        ])).unwrap();
        db.state_set("pipeline:stage", Value::String("indexing".into())).unwrap();
        db.state_set("pipeline:progress", Value::Float(0.73)).unwrap();

        // =====================================================================
        // Event Log — 20 events simulating an agent run
        // =====================================================================

        db.event_append("system", obj(vec![
            ("action", Value::String("startup".into())),
            ("version", Value::String("1.0.0".into())),
        ])).unwrap();
        db.event_append("auth", obj(vec![
            ("action", Value::String("login".into())),
            ("user", Value::String("alice".into())),
            ("method", Value::String("api_key".into())),
        ])).unwrap();
        db.event_append("tool_call", obj(vec![
            ("tool", Value::String("web_search".into())),
            ("query", Value::String("rust embedded database benchmarks".into())),
            ("duration_ms", Value::Int(342)),
            ("results", Value::Int(15)),
        ])).unwrap();
        db.event_append("observation", obj(vec![
            ("content", Value::String("Found 15 results about embedded databases. Top result: StrataDB benchmarks show 2.3x improvement.".into())),
        ])).unwrap();
        db.event_append("decision", obj(vec![
            ("reasoning", Value::String("Results look promising. Will summarize the top 3 findings.".into())),
            ("confidence", Value::Float(0.85)),
        ])).unwrap();
        db.event_append("tool_call", obj(vec![
            ("tool", Value::String("read_document".into())),
            ("doc_id", Value::String("benchmark-report-2026".into())),
            ("duration_ms", Value::Int(89)),
        ])).unwrap();
        db.event_append("tool_call", obj(vec![
            ("tool", Value::String("read_document".into())),
            ("doc_id", Value::String("stratadb-architecture".into())),
            ("duration_ms", Value::Int(124)),
        ])).unwrap();
        db.event_append("observation", obj(vec![
            ("content", Value::String("Architecture doc describes 6 primitives: KV, Events, State, JSON, Vectors, Branches.".into())),
        ])).unwrap();
        db.event_append("tool_call", obj(vec![
            ("tool", Value::String("kv_put".into())),
            ("key", Value::String("cache:summary".into())),
            ("duration_ms", Value::Int(3)),
        ])).unwrap();
        db.event_append("error", obj(vec![
            ("message", Value::String("Rate limit exceeded for web_search".into())),
            ("code", Value::Int(429)),
            ("retry_after_ms", Value::Int(5000)),
        ])).unwrap();
        db.event_append("system", obj(vec![
            ("action", Value::String("rate_limit_backoff".into())),
            ("wait_ms", Value::Int(5000)),
        ])).unwrap();
        db.event_append("tool_call", obj(vec![
            ("tool", Value::String("web_search".into())),
            ("query", Value::String("strata vs redb vs sqlite comparison".into())),
            ("duration_ms", Value::Int(567)),
            ("results", Value::Int(8)),
        ])).unwrap();
        db.event_append("observation", obj(vec![
            ("content", Value::String("Comparison shows StrataDB excels at branching and time-travel. SQLite wins on raw read throughput.".into())),
        ])).unwrap();
        db.event_append("decision", obj(vec![
            ("reasoning", Value::String("Have enough data to write the summary. Will generate report.".into())),
            ("confidence", Value::Float(0.92)),
        ])).unwrap();
        db.event_append("tool_call", obj(vec![
            ("tool", Value::String("generate_text".into())),
            ("prompt_tokens", Value::Int(2048)),
            ("completion_tokens", Value::Int(512)),
            ("duration_ms", Value::Int(1843)),
        ])).unwrap();
        db.event_append("tool_call", obj(vec![
            ("tool", Value::String("json_set".into())),
            ("key", Value::String("doc:report".into())),
            ("duration_ms", Value::Int(5)),
        ])).unwrap();
        db.event_append("auth", obj(vec![
            ("action", Value::String("login".into())),
            ("user", Value::String("bob".into())),
            ("method", Value::String("oauth".into())),
        ])).unwrap();
        db.event_append("tool_call", obj(vec![
            ("tool", Value::String("kv_list".into())),
            ("prefix", Value::String("user:".into())),
            ("duration_ms", Value::Int(2)),
            ("results", Value::Int(3)),
        ])).unwrap();
        db.event_append("system", obj(vec![
            ("action", Value::String("checkpoint".into())),
            ("step", Value::Int(47)),
        ])).unwrap();
        db.event_append("system", obj(vec![
            ("action", Value::String("task_complete".into())),
            ("total_steps", Value::Int(47)),
            ("total_tool_calls", Value::Int(8)),
            ("total_tokens", Value::Int(4096)),
        ])).unwrap();

        // =====================================================================
        // JSON Store — 4 documents
        // =====================================================================

        db.json_set("doc:readme", "$", obj(vec![
            ("title", Value::String("Getting Started with StrataDB".into())),
            ("author", Value::String("Alice Chen".into())),
            ("created", Value::String("2026-01-15T10:00:00Z".into())),
            ("content", Value::String("StrataDB is an embedded database built for AI agents. It provides six data primitives, git-like branching, time-travel queries, and optimistic concurrency control.".into())),
            ("tags", Value::Array(vec![
                Value::String("docs".into()),
                Value::String("getting-started".into()),
                Value::String("tutorial".into()),
            ])),
            ("status", Value::String("published".into())),
        ])).unwrap();

        db.json_set("doc:changelog", "$", obj(vec![
            ("version", Value::String("0.5.1".into())),
            ("date", Value::String("2026-02-18".into())),
            ("changes", Value::Array(vec![
                obj(vec![
                    ("type", Value::String("feature".into())),
                    ("description", Value::String("Added branch diff and merge support".into())),
                ]),
                obj(vec![
                    ("type", Value::String("fix".into())),
                    ("description", Value::String("Fixed WAL compaction causing data loss on crash".into())),
                ]),
                obj(vec![
                    ("type", Value::String("perf".into())),
                    ("description", Value::String("2.3x faster vector search with HNSW segment compaction".into())),
                ]),
                obj(vec![
                    ("type", Value::String("fix".into())),
                    ("description", Value::String("OCC conflict detection now handles cross-branch reads".into())),
                ]),
            ])),
            ("breaking_changes", Value::Bool(false)),
        ])).unwrap();

        db.json_set("doc:agent-config", "$", obj(vec![
            ("name", Value::String("research-agent-v2".into())),
            ("model", Value::String("claude-sonnet-4-6".into())),
            ("max_steps", Value::Int(100)),
            ("tools", Value::Array(vec![
                Value::String("web_search".into()),
                Value::String("read_document".into()),
                Value::String("generate_text".into()),
                Value::String("kv_put".into()),
                Value::String("kv_get".into()),
                Value::String("json_set".into()),
            ])),
            ("temperature", Value::Float(0.7)),
            ("system_prompt", Value::String("You are a research assistant. Find information, analyze it, and produce structured reports.".into())),
        ])).unwrap();

        db.json_set("doc:report", "$", obj(vec![
            ("title", Value::String("Embedded Database Comparison 2026".into())),
            ("author", Value::String("research-agent-v2".into())),
            ("generated_at", Value::String("2026-02-20T15:30:00Z".into())),
            ("summary", Value::String("Analysis of 5 embedded databases across 12 benchmarks. StrataDB leads in branching, time-travel, and hybrid search. SQLite leads in raw read throughput. redb leads in write-heavy workloads.".into())),
            ("databases", Value::Array(vec![
                Value::String("StrataDB".into()),
                Value::String("SQLite".into()),
                Value::String("redb".into()),
                Value::String("LMDB".into()),
                Value::String("RocksDB".into()),
            ])),
            ("recommendation", Value::String("StrataDB recommended for AI agent workloads due to native branching and vector search.".into())),
        ])).unwrap();

        // =====================================================================
        // Branches — 3 total
        // =====================================================================

        db.create_branch("experiment").unwrap();
        db.create_branch("staging").unwrap();

        // Flush to disk
        db.flush().unwrap();

        println!("Sample database created at: {path}");
        println!("  KV: 15 keys (user:*, config:*, counter:*, cache:*, session:*)");
        println!("  State: 8 cells (agent:*, pipeline:*)");
        println!("  Events: 20 entries (system, auth, tool_call, observation, decision, error)");
        println!("  JSON: 4 documents (readme, changelog, agent-config, report)");
        println!("  Branches: 3 (default, experiment, staging)");
    }
}
