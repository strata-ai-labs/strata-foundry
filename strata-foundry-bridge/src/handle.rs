//! Handle registry — manages open database handles.
//!
//! Handles are integer IDs stored in a global concurrent map.
//! This avoids passing raw pointers across the FFI boundary.

use std::sync::atomic::{AtomicU64, Ordering};

use dashmap::DashMap;
use stratadb::{Command, Output, Strata};

/// Thread-safe registry of all open database handles.
pub struct HandleRegistry {
    next_id: AtomicU64,
    handles: DashMap<u64, Strata>,
}

impl HandleRegistry {
    pub fn new() -> Self {
        Self {
            next_id: AtomicU64::new(1),
            handles: DashMap::new(),
        }
    }

    /// Open a database at the given filesystem path.
    pub fn open(&self, path: &str) -> Result<u64, String> {
        let strata = Strata::open(path).map_err(|e| e.to_string())?;
        let id = self.next_id.fetch_add(1, Ordering::Relaxed);
        self.handles.insert(id, strata);
        Ok(id)
    }

    /// Open an in-memory (ephemeral) database.
    pub fn open_memory(&self) -> Result<u64, String> {
        let strata = Strata::cache().map_err(|e| e.to_string())?;
        let id = self.next_id.fetch_add(1, Ordering::Relaxed);
        self.handles.insert(id, strata);
        Ok(id)
    }

    /// Close a database handle.
    pub fn close(&self, id: u64) {
        self.handles.remove(&id);
    }

    /// Execute a JSON command against a handle. Returns JSON output.
    pub fn execute(&self, id: u64, command_json: &str) -> Result<String, String> {
        let handle = self.handles.get(&id).ok_or("invalid handle")?;

        let cmd: Command =
            serde_json::from_str(command_json).map_err(|e| format!("invalid command JSON: {e}"))?;

        let output: Output = handle.executor().execute(cmd).map_err(|e| {
            // Serialize the stratadb Error as JSON (it derives Serialize)
            serde_json::to_string(&e)
                .unwrap_or_else(|_| format!(r#"{{"Internal":{{"reason":"{e}"}}}}"#))
        })?;

        serde_json::to_string(&output).map_err(|e| format!("failed to serialize output: {e}"))
    }
}
