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
}
