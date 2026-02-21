# Strata Foundry — Product Requirements Document

## 1. Overview

Strata Foundry is a native macOS application for interacting with StrataDB databases through an AI-native interface. It combines a **conversational AI assistant (Claude Data)** with an **interactive visual workspace** — replacing traditional database browser navigation with a unified experience where you talk to your data and see the results rendered as interactive panels.

This is not "TablePlus for StrataDB." It is closer to **"Claude Code for data"** — a conversational interface backed by the Anthropic API that can execute any of Strata's 60 database commands as tool calls, with results rendered as rich, interactive visual panels that you can also manipulate directly.

### Two Modes

**Workspace** — A canvas of interactive panels (tables, diffs, JSON trees, search results, charts) with a conversation bar at the bottom. You type questions or commands, panels appear on the canvas. You click and edit panels directly. This is the default mode — where you monitor, browse, and work with your data.

**Focus** — A full-screen conversational thread with Claude Data, with rich inline artifacts. For deep investigation, complex multi-step analysis, and having Claude walk you through what happened in the database. Focus is the expanded view of the same conversation thread from the Workspace bar.

### Why native macOS?

- Strata runs embedded (no server) — the app opens database files directly
- Metal-accelerated inference for auto-embedding and model operations (via strata-inference)
- First-class macOS integration: drag-and-drop `.strata` directories, system file dialogs
- SwiftUI provides the canvas, panel, and split-view primitives the workspace model requires

## 2. Target Users

**Primary:** Developers building AI agents, pipelines, or tools that use StrataDB as their data layer. They need to:
- Inspect what their agent wrote to the database
- Debug branching/merging behavior
- Explore vector collections and search results
- Understand data state at specific points in time (time-travel)
- Quickly CRUD data during development without writing code
- Ask natural language questions about their data

**Secondary:** Technical end users who interact with Strata-powered applications and want visibility into the underlying data.

## 3. Core Concepts

### 3.1 Database

A Strata database is a directory on disk (e.g., `./my-project/.strata/`) containing WAL files, snapshots, and a `strata.toml` config. The app opens these directories directly — there is no server.

An ephemeral in-memory database (equivalent to `strata --cache`) can also be created for scratch work.

### 3.2 Branches

Git-like isolated namespaces. Every database has a `default` branch. Users can fork, diff, and merge branches. All data operations are scoped to the current branch.

### 3.3 Spaces

Sub-namespaces within a branch. Every branch has a `default` space. Spaces allow logical grouping (e.g., per-tenant, per-conversation) while sharing a branch's transaction context.

### 3.4 Six Primitives

Each space contains up to six data primitives:

| Primitive | Nature | Key operations |
|-----------|--------|----------------|
| **KV Store** | Versioned key-value pairs | put, get, delete, list, history |
| **Event Log** | Append-only typed event stream | append, list by type, count |
| **State Cells** | Named cells with compare-and-swap | set, get, cas, init, delete |
| **JSON Store** | Documents with atomic JSONPath mutations | set path, get path, delete path |
| **Vector Store** | HNSW-indexed embedding collections | upsert, search, create/drop collections |
| **Branches** | Lifecycle operations (not a data container) | fork, diff, merge, delete |

### 3.5 Versioning and Time-Travel

Every write produces a monotonically increasing version number. Every read operation supports an `as_of` timestamp parameter to read data as it existed at that point in time. The database tracks a global time range (oldest to latest timestamp).

### 3.6 Transactions

OCC (Optimistic Concurrency Control) — begin, read/write, commit or rollback. Transactions provide snapshot isolation. Vector writes and branch lifecycle operations bypass transactions by design.

## 4. Claude Data — The Conversational Interface

### 4.1 What Is Claude Data?

Claude Data is a conversational AI assistant embedded in Strata Foundry, powered by the Anthropic API. It has access to all of Strata's database operations as tools and can execute them on behalf of the user. It is the primary way users interact with the database.

Think of it as Claude Code, but instead of tools for reading/editing files and running shell commands, the tools are `kv_put`, `kv_get`, `branch_fork`, `vector_search`, `event_append`, `search`, `diff`, and so on — the full set of 60 Strata commands.

### 4.2 Tool Set

Claude Data has access to every Strata command as a tool call. The tools map directly to the `Command` enum in strata-executor:

**Data operations:** KV (put, get, delete, list, batch_put, history), JSON (set, get, delete, list, batch_set, history), Event (append, get, get_by_type, count, batch_append), State (set, get, cas, init, delete, list, history, batch_set), Vector (upsert, get, delete, search, create_collection, drop_collection, list_collections, stats, batch_upsert)

**Branch operations:** create, get, list, exists, delete, fork, diff, merge, export, import

**Space operations:** create, delete, exists, list

**Transaction operations:** begin, commit, rollback, info, is_active

**Database operations:** ping, info, flush, compact, time_range

**Intelligence operations:** search (cross-primitive hybrid), configure_model

All tools execute in the context of the current branch and space, which Claude Data can also switch.

### 4.3 How It Works

1. User types a message in the conversation bar (Workspace) or conversation thread (Focus)
2. The message + conversation history is sent to the Anthropic API with the tool definitions
3. Claude responds — either with text, or with tool calls
4. Tool calls are executed against the open Strata database via the Rust bridge
5. Tool results are sent back to Claude for interpretation
6. Claude's final response (text + any remaining tool results) is rendered
7. Tool outputs that produce data (tables, JSON, diffs, search results) are rendered as **interactive panels** on the workspace or as **inline artifacts** in focus mode

### 4.4 Example Interactions

```
User: "Open ~/projects/my-agent/.strata"

Claude Data: [executes db open]
  Panel: Database Info — my-agent, 3 branches, 847 keys, default branch active

User: "What's in the KV store?"

Claude Data: [executes kv_list + kv_get for each key]
  Panel: KV Table — 42 keys, showing key/value/version/timestamp
  "You have 42 keys in the default space. The most recently
   updated keys are agent:state (2 min ago) and cache:results
   (5 min ago)."

User: "Show me everything the agent did in the last hour"

Claude Data: [executes event_get_by_type with time filter, kv_list, state_list]
  Panel: Event Timeline — 34 events, grouped by type
  Panel: State Changes — 3 cells modified
  "In the last hour, the agent made 34 event entries (21 tool_calls,
   8 observations, 5 decisions). It also updated 3 state cells:
   agent_status (idle→running→completed), step_count (0→47), ..."

User: "Fork this branch as debug-session and switch to it"

Claude Data: [executes branch_fork, branch_switch]
  Context indicator updates: debug-session/default
  "Forked 'default' as 'debug-session' and switched to it.
   All your changes will be isolated here."

User: [clicks a cell in the KV Table panel, edits the value directly]

  Panel updates, Claude Data sees the change in context:
  "I see you updated agent:config.max_retries from 3 to 5."
```

### 4.5 Conversation Context

Claude Data maintains context about:
- Which database is open (path, config)
- Current branch and space
- Active transaction (if any)
- Recent operations and their results
- Panels currently visible on the workspace

This means follow-up questions work naturally: "Now show me just the tool_call events" after a broader query, or "Delete that key" after viewing a table.

### 4.6 API Key Management

- User provides their Anthropic API key in app settings
- Key stored securely in macOS Keychain
- API calls go directly to Anthropic's API (no intermediate server)
- The app works without an API key for direct manipulation (panels, command bar) — Claude Data is an enhancement, not a requirement

### 4.7 Relationship to Strata MCP

Strata Foundry and `strata-mcp` are complementary:
- **strata-mcp** lets external AI assistants (Claude Code, Claude Desktop) interact with Strata databases via MCP protocol
- **Claude Data** is an embedded AI assistant inside the Foundry app itself
- Same tool semantics, different transport: MCP uses the MCP protocol over stdio/SSE; Claude Data calls the Anthropic API directly with tools
- A developer might use strata-mcp in their agent's runtime AND use Foundry to inspect/debug what the agent did

## 5. Workspace Mode

### 5.1 Layout

The workspace is a **canvas with a conversation bar**.

```
+------------------------------------------------------------------+
|  [Toolbar: branch/space indicator, db info, settings, mode toggle]|
+------------------------------------------------------------------+
|                                                                    |
|   +------------------+  +------------------+  +----------------+  |
|   | KV Table         |  | Event Timeline   |  | Branch Info    |  |
|   |                  |  |                  |  |                |  |
|   | key | value | v# |  | #47 tool_call    |  | default        |  |
|   | user:1 | {...}   |  | #48 observation  |  |   experiment   |  |
|   | cache  | [...]   |  | #49 tool_call    |  |   debug-sess   |  |
|   |        ...       |  |        ...       |  |                |  |
|   +------------------+  +------------------+  +----------------+  |
|                                                                    |
|   +--------------------------------------+                        |
|   | State Cells                          |                        |
|   | agent_status: "completed"  v:12      |                        |
|   | step_count: 47             v:47      |                        |
|   +--------------------------------------+                        |
|                                                                    |
+------------------------------------------------------------------+
|  > Ask Claude Data or type a command...              [Focus ↗]   |
+------------------------------------------------------------------+
```

### 5.2 Panels

Panels are the building blocks of the workspace. Each panel is an interactive visualization of database content:

**Panel types:**
- **KV Table** — sortable, filterable table of key-value pairs with inline editing
- **Event List** — chronological event stream with type filtering
- **State Cells** — cell name/value/version table with inline editing and CAS support
- **JSON Tree** — collapsible document tree with path-level editing
- **Vector Collection** — collection stats, vector list, search results
- **Branch Info** — branch list with status, fork/switch actions
- **Branch Diff** — side-by-side comparison of two branches
- **Search Results** — cross-primitive search results with scores and snippets
- **Database Info** — database stats and configuration summary
- **History** — version timeline for a specific key/cell/document
- **Raw Output** — plain text output from a command (fallback)

**Panel interactions:**
- **Click data** — select a row/node, show detail inline or in a popover
- **Double-click / edit icon** — inline edit (executes the appropriate put/set command)
- **Add (+)** — create new entry (key-value, event, cell, document, vector, etc.)
- **Delete (-)** — remove selected item(s) with confirmation
- **Filter/Search** — per-panel filtering (prefix for KV, type for events, JSONPath for JSON)
- **Sort** — click column headers
- **Refresh** — manual refresh (auto-refresh handles external changes)
- **Dismiss (x)** — remove panel from workspace
- **Resize / Rearrange** — drag panel edges to resize, drag title bar to rearrange

**Panel creation:**
- Panels are created by Claude Data in response to queries
- Panels are also created by direct actions (open database → Database Info panel, command bar commands)
- User can explicitly request panels: "show me the KV store" or via a command palette

### 5.3 Conversation Bar

The conversation bar sits at the bottom of the workspace. It serves dual purpose:

1. **Natural language input** — questions and instructions for Claude Data
2. **Raw command input** — prefix with `/` to run a raw Strata command (e.g., `/kv list`)

The bar shows a single input line. Below it, a collapsible response area shows Claude's latest text response and a scrollable history of the conversation.

Keyboard shortcut to expand into Focus mode (e.g., Cmd+Enter or click the expand arrow).

### 5.4 Toolbar

Compact toolbar above the canvas:
- **Database name** (click to switch between open databases or open a new one)
- **Branch/Space indicator** — shows `branch/space`, click to switch
- **Time-travel toggle** — when active, shows a date/time selector; all panels switch to read-only with `as_of` filtering
- **Transaction indicator** — shows transaction state; click to begin/commit/rollback
- **Mode toggle** — switch between Workspace and Focus

### 5.5 Direct Manipulation

Users can interact with panels without going through Claude Data:
- Edit a value by clicking it in a panel
- Add a key-value pair via the panel's + button
- Delete items via selection + backspace
- Filter/sort within panels
- Switch branches via the toolbar dropdown

These direct actions execute database commands immediately (via the Rust bridge) and update the panel. They also feed context into the conversation — so if the user edits a value and then asks Claude "what did I just change?", Claude knows.

## 6. Focus Mode

### 6.1 Layout

Focus mode expands the conversation bar into a full-screen conversational interface:

```
+------------------------------------------------------------------+
|  [Toolbar: same as workspace]                    [Workspace ↙]   |
+------------------------------------------------------------------+
|                                                                    |
|  Claude Data                                                       |
|  ─────────────                                                     |
|  You have 42 keys in the KV store. Here are the most recently     |
|  updated:                                                          |
|                                                                    |
|  ┌──────────────────────────────────────────────────────────┐     |
|  │ KV Store (default/default) — 42 keys                     │     |
|  │ key              │ value          │ version │ updated     │     |
|  │ agent:state      │ "completed"    │ 847     │ 2 min ago   │     |
|  │ cache:results    │ [{...}, ...]   │ 831     │ 5 min ago   │     |
|  │ user:preferences │ {theme: "...   │ 412     │ 1 hour ago  │     |
|  │                  ...                                      │     |
|  │                        [Pin to Workspace]  [Expand]       │     |
|  └──────────────────────────────────────────────────────────┘     |
|                                                                    |
|  The agent completed its task 2 minutes ago after 47 steps.       |
|  The most active period was between 2:15-2:31 PM with 21          |
|  tool_call events.                                                 |
|                                                                    |
|  > ___________________________________________________________     |
|                                                                    |
+------------------------------------------------------------------+
```

### 6.2 Inline Artifacts

In Focus mode, tool results are rendered as inline interactive artifacts within the conversation — similar to Claude Artifacts but embedded in the thread. Artifacts can be:
- Tables (KV, events, state cells, search results)
- JSON trees
- Branch diffs
- Database info cards
- Raw text output

Each artifact has:
- **Pin to Workspace** — sends the artifact to the Workspace canvas as a persistent panel
- **Expand** — full-screen view of the artifact
- **Interact** — same click/edit/filter interactions as workspace panels

### 6.3 Transitioning Between Modes

- **Workspace → Focus:** Click the expand arrow on the conversation bar, or Cmd+Enter
- **Focus → Workspace:** Click the collapse arrow in toolbar, or Cmd+Enter again, or Esc
- **Pin artifact to Workspace:** Click "Pin to Workspace" on any inline artifact in Focus; it appears as a panel when you switch back
- The conversation thread is shared — switching modes doesn't lose context

## 7. Feature Specifications

### 7.1 Database Management

#### Open Database
- **File > Open** or drag-and-drop a `.strata` directory onto the app / dock icon
- Shows a file picker filtered to directories
- Validates that the directory contains a valid Strata database
- Recent databases remembered and shown in Welcome screen / File > Open Recent
- Or just tell Claude Data: "open ~/projects/my-agent/.strata"

#### Create Database
- **File > New Database** opens a save dialog
- Options: database path, durability mode (Standard / Always), auto-embed toggle
- Or: "create a new database at ~/projects/test/.strata"

#### Close Database
- Close the window. If in-memory with unsaved data, prompt to export.

#### Database Info
- Shown as a panel automatically when a database is opened
- Shows: path, version, branch count, total keys, durability mode, auto-embed status, model config

### 7.2 Panel Specifications

Each panel type has specific columns, interactions, and behaviors:

#### KV Table Panel
| Column | Content |
|--------|---------|
| Key | The key string |
| Value | Preview (first ~100 chars, type-colored) |
| Type | Value type badge: String, Int, Float, Bool, Object, Array, Bytes, Null |
| Version | Monotonic version number |
| Updated | Human-readable timestamp |

- Inline edit: double-click value cell → type-aware editor (see Value Editor below)
- Add: + button → key + value editor dialog
- Delete: select + backspace → confirmation
- Filter: prefix search bar
- Sort: click column headers
- Pagination: cursor-based, "Load more" at bottom
- History: right-click key → View History → History panel

#### Event List Panel
| Column | Content |
|--------|---------|
| Sequence | Monotonic sequence number |
| Type | Event type string (chip/badge) |
| Payload | Preview of event data |
| Timestamp | When the event was appended |

- Filter: type selector chips
- Append: + button → type + payload editor
- Click: expand payload inline
- No edit or delete (append-only by design — UI communicates this)

#### State Cells Panel
| Column | Content |
|--------|---------|
| Cell | Cell name |
| Value | Current value preview |
| Type | Value type badge |
| Version | Counter (used for CAS) |
| Updated | Timestamp |

- Inline edit: double-click → `state set`
- CAS edit: right-click → "Edit with CAS" → shows expected version, fails if changed
- Init: + button → `state init` (fails if exists)
- Delete: select + backspace
- History: right-click → View History

#### JSON Tree Panel
- Left pane: document list (key, version, timestamp)
- Right pane: collapsible JSON tree for selected document
- Click tree node: show JSONPath breadcrumb
- Edit node: click edit icon → `json set` at that path
- Delete node: right-click → `json delete` at that path
- Add document: + button → key + JSON editor
- History: right-click document → version history

#### Vector Collection Panel
- Header: collection name, dimension, metric, count
- Vectors table: key, metadata preview, timestamp
- Upsert: + button → key + vector (paste) + metadata
- Delete: select + backspace
- Search (Phase 2): text/vector input, K slider, metadata filters, results with scores

#### Branch Info Panel
- Branch list with status indicators
- Current branch highlighted
- Actions per branch: Switch, Fork, Delete
- Fork: click Fork → name dialog → creates and switches

#### Branch Diff Panel (Phase 2)
- Side-by-side comparison: keys added, removed, changed
- Grouped by primitive type
- For changed keys: before/after value comparison
- Merge button with strategy selection

#### History Panel
- Version timeline for a specific key/cell/document
- Each version: value, version number, timestamp
- Click to view (read-only)
- Restore: click Restore → creates new version with old value

#### Search Results Panel (Phase 2)
- Entity key, primitive type, score, snippet
- Click result → navigate to that item's panel

#### Database Info Panel
- Path, version, branch count, total keys
- Durability mode, auto-embed status
- Model configuration summary

#### Raw Output Panel
- Plain text output from command bar commands
- Scrollable, monospace font
- Copy button

### 7.3 Value Editor

The value editor is a reusable component used across all panels for editing Strata `Value` types. It renders a type-aware tree:

- **String:** text field
- **Int:** number stepper / text field (validated)
- **Float:** number field with decimal (validated)
- **Bool:** toggle switch
- **Null:** non-editable label "(null)"
- **Object:** collapsible tree, each key-value pair editable, add/remove keys
- **Array:** ordered list, each element editable, add/remove/reorder elements
- **Bytes:** hex viewer (read-only in MVP)

The tree editor is the default. A raw JSON text toggle is in the backlog.

### 7.4 Time-Travel (Phase 2)

- Toolbar toggle activates time-travel mode
- Date/time picker and slider spanning the database's time range
- All panels switch to read-only with `as_of` filtering
- Visual indicator: banner "Viewing data as of [date/time]"
- Exiting returns to live data

### 7.5 Transactions (Phase 2)

- Toolbar indicator shows transaction state
- Begin/Commit/Rollback controls
- While active: modified rows highlighted in panels
- Close window with active transaction: prompt to commit or rollback

### 7.6 Undo

- Cmd+Z undoes the last data operation
- Leverages Strata's versioning: undo = restore previous version of the affected key/cell/document
- Undo stack tracks: operation type, target key, previous value/version
- Works for: KV put/delete, State set/delete, JSON set/delete, Event append (no undo — append-only)
- Cmd+Shift+Z to redo (re-apply the undone operation)

### 7.7 External Change Detection

- Background poller checks for WAL changes every ~1-2 seconds
- When changes detected: auto-refresh all visible panels
- Subtle indicator: brief flash or badge on updated panels
- If a value the user is currently editing was changed externally: show conflict indicator, let user choose to overwrite or reload

## 8. Architecture

### 8.1 High-Level Stack

```
+--------------------------------------------------+
|              SwiftUI Frontend                     |
|  (Workspace, Focus, Panels, ViewModels)          |
+--------------------------------------------------+
|              Swift Bridge Layer                   |
|  (StrataClient: async Swift API over FFI)        |
|  (ClaudeClient: Anthropic API + tool execution)  |
+--------------------------------------------------+
        |                           |
        v                           v
+------------------+    +------------------------+
|  FFI Boundary    |    |  Anthropic API         |
|  (C-ABI)         |    |  (HTTPS, tool_use)     |
+------------------+    +------------------------+
        |
        v
+--------------------------------------------------+
|         Rust Bridge Crate                        |
|  (strata-foundry-bridge)                         |
|  Translates C-ABI calls → strata API            |
+--------------------------------------------------+
|         strata-core (stratadb)                   |
|  (Executor, Engine, Storage, etc.)               |
+--------------------------------------------------+
|         strata-inference (optional)              |
|  (Embedding, Generation)                         |
+--------------------------------------------------+
```

### 8.2 Rust Bridge Crate

A new Rust crate (`strata-foundry-bridge`) that:
- Depends on `stratadb` (strata-core's top-level crate)
- Depends on `strata-inference` (optional, for model operations)
- Exposes a flat C-ABI (`#[no_mangle] pub extern "C" fn ...`)
- Handles lifetime management (opaque pointers to Rust objects, explicit create/destroy)
- Serializes complex return values as JSON strings (Swift decodes with Codable)

Why JSON for complex types: Strata's `Value` is a recursive enum (arrays of objects of arrays...). Mapping this to C structs is painful. JSON is the natural serialization and Swift's `Codable` handles it trivially.

### 8.3 Claude Data Architecture

The Claude Data pipeline in Swift:

```
User message
    ↓
ClaudeClient.sendMessage(conversation, tools)
    ↓
Anthropic API (POST /v1/messages, tool_use)
    ↓
Response: text + tool_use blocks
    ↓
For each tool_use:
    ↓
    ToolExecutor.execute(tool_name, tool_input)
        → StrataClient.executeCommand(...)   // calls Rust FFI
        → returns tool_result JSON
    ↓
Send tool_results back to API (continuation)
    ↓
Final response: text + rendered artifacts
    ↓
PanelFactory.createPanels(tool_results)
    → Workspace: add panels to canvas
    → Focus: render inline artifacts
```

### 8.4 Threading Model

- **Main thread:** SwiftUI views and user interaction
- **Background thread(s):** All Rust/database calls happen off the main thread via Swift concurrency (async/await)
- **API calls:** Anthropic API calls use URLSession async, off main thread
- **Pattern:** `@MainActor` ViewModels call async methods → dispatch to background → FFI call → decode → publish to main thread
- Strata's own concurrency (DashMap, OCC) handles concurrent access within the Rust layer

### 8.5 Project Structure

```
strata-foundry/
  StrataFoundry/                          # Xcode project
    StrataFoundry/
      App/
        StrataFoundryApp.swift            # App entry, WindowGroup
        AppState.swift                    # Global state, open databases
      Models/
        Database.swift                    # Database handle wrapper
        Branch.swift
        Space.swift
        Value.swift                       # Strata Value type in Swift
        Primitives/
          KVEntry.swift
          Event.swift
          StateCell.swift
          JsonDocument.swift
          VectorCollection.swift
        Conversation.swift                # Chat message + artifact models
      ViewModels/
        WorkspaceViewModel.swift          # Panel layout, conversation bar
        FocusViewModel.swift              # Full conversation thread
        PanelViewModels/
          KVTableViewModel.swift
          EventListViewModel.swift
          StateCellsViewModel.swift
          JsonTreeViewModel.swift
          VectorCollectionViewModel.swift
          BranchInfoViewModel.swift
          HistoryViewModel.swift
      Views/
        Workspace/
          WorkspaceView.swift             # Canvas with panels
          PanelContainerView.swift        # Panel layout/arrangement
          ConversationBar.swift           # Bottom input bar
        Focus/
          FocusView.swift                 # Full conversation thread
          InlineArtifactView.swift        # Artifacts in conversation
        Panels/
          KVTablePanel.swift
          EventListPanel.swift
          StateCellsPanel.swift
          JsonTreePanel.swift
          VectorCollectionPanel.swift
          BranchInfoPanel.swift
          HistoryPanel.swift
          SearchResultsPanel.swift
          DatabaseInfoPanel.swift
          RawOutputPanel.swift
        Shared/
          ValueEditorView.swift           # Tree-based value editor
          ToolbarView.swift
          TimeTravelBar.swift
      Bridge/
        StrataFFI.swift                   # C-ABI function declarations
        StrataClient.swift                # High-level async Swift wrapper
      Claude/
        ClaudeClient.swift                # Anthropic API client
        ToolDefinitions.swift             # Tool schemas for API calls
        ToolExecutor.swift                # Dispatches tool calls → StrataClient
        PanelFactory.swift                # Converts tool results → panel models
      Resources/
        Assets.xcassets
    StrataFoundry.entitlements
  strata-foundry-bridge/                  # Rust crate (cdylib)
    Cargo.toml
    src/
      lib.rs                              # C-ABI exports
      handle.rs                           # Database handle management
      convert.rs                          # Value ↔ JSON conversion
  docs/
    PRD.md                                # This document
    ARCHITECTURE.md                       # Detailed architecture doc
  Makefile                                # Build Rust dylib + copy to Xcode
```

### 8.6 Build Pipeline

1. `cargo build --release` in `strata-foundry-bridge/` produces `libstrata_foundry_bridge.dylib`
2. Makefile copies the dylib into the Xcode project's framework search path
3. Xcode builds the SwiftUI app, linking against the dylib
4. The app bundles the dylib inside `StrataFoundry.app/Contents/Frameworks/`

For development: a combined `make run` that builds Rust + launches Xcode build.

## 9. MVP Scope

### MVP Includes

| Feature | Scope |
|---------|-------|
| **Workspace mode** | Canvas with panels + conversation bar |
| **Focus mode** | Full conversation thread with inline artifacts |
| **Claude Data** | Anthropic API integration, tool execution, panel generation |
| **Open / Create database** | File picker, recent databases, create new |
| **KV Table panel** | Table view, add/edit/delete, prefix filter, history |
| **Event List panel** | List view, append, filter by type |
| **State Cells panel** | Table view, set/edit/delete, CAS edit |
| **JSON Tree panel** | Document list + JSON tree, path-level edit |
| **Vector Collection panel** | Collections list, stats, upsert/delete |
| **Branch Info panel** | Branch list, switch, fork, delete |
| **Database Info panel** | Stats and config summary |
| **History panel** | Version timeline for any key/cell/document |
| **Value editor** | Type-aware tree editor for Strata Values |
| **Command bar** | Raw command input (prefix with `/`) in conversation bar |
| **Undo (Cmd+Z)** | Restore previous version on accidental writes |
| **External change detection** | Auto-refresh panels on WAL changes |
| **Separate windows** | Each database in its own window (NSDocument) |

### MVP Excludes (Phase 2+)

| Feature | Phase |
|---------|-------|
| Time-travel mode | Phase 2 |
| Transaction mode UI | Phase 2 |
| Branch diff/merge panels | Phase 2 |
| Cross-primitive search panel | Phase 2 |
| Vector similarity search in panel | Phase 2 |
| In-memory scratch databases | Phase 2 |
| Bundle export/import | Phase 2 |
| Database configuration editor | Phase 2 |
| Keyboard shortcuts | Phase 2 |
| Drag-and-drop database opening | Phase 2 |
| Panel rearrangement / custom layouts | Phase 2 |
| Auto-embed status/controls | Phase 3 |
| Local model management (strata-inference) | Phase 3 |
| Streaming responses from Claude | Phase 2 |

### MVP Acceptance Criteria

1. User can open a `.strata` database and see a Database Info panel on the workspace
2. User can ask Claude Data questions ("show me the KV store", "what events happened?") and see interactive panels appear
3. Each primitive has a functional panel with current data
4. User can add, edit, and delete data directly in panels (KV, State, JSON) and see changes reflected
5. User can append events via the Event List panel
6. User can create vector collections and upsert/delete vectors
7. User can switch branches and fork new ones via the Branch Info panel
8. User can type `/` prefixed raw commands in the conversation bar and see output
9. Focus mode shows a full conversation thread with inline artifacts
10. Artifacts can be pinned from Focus to Workspace as persistent panels
11. Panels auto-refresh when the database is modified externally
12. Cmd+Z undoes the last data write operation
13. The app works for direct manipulation without an API key (Claude Data requires a key, but panels and command bar work without one)
14. Errors are shown gracefully — never silent data corruption

## 10. Phased Roadmap

### Phase 1: AI-Native Database Browser
- Workspace and Focus modes
- Claude Data with Anthropic API integration
- All primitive panels with CRUD
- Branch switch/fork
- Conversation bar + raw command support
- Undo, external change detection
- Single database per window

### Phase 2: Power Features
- Time-travel mode with date picker and slider
- Transaction mode with buffered-changes visualization
- Branch diff and merge panels
- Vector similarity search with metadata filters
- Cross-primitive hybrid search panel
- In-memory scratch databases
- Bundle export/import
- Database configuration editor
- Panel rearrangement and custom layouts
- Keyboard shortcuts
- Streaming responses from Claude
- Drag-and-drop database opening

### Phase 3: Intelligence Integration
- Auto-embed status dashboard and controls
- Model configuration (endpoint, model, API key)
- strata-inference integration for local embedding/generation
- Local model as Claude Data fallback (no API key needed for basic operations)
- Query expansion and re-ranking via configured model
- Model registry browser

## 11. Design Principles

1. **Conversation-first:** The primary interaction is talking to Claude Data. Visual panels are the output, not the navigation. You don't browse a tree to find data — you ask for it.

2. **Direct manipulation as complement:** Panels are fully interactive. When you see data, you can touch it. Clicking, editing, and deleting in panels is always available, with or without Claude Data.

3. **Progressive complexity:** Opening a database shows a simple info panel. Asking questions builds up the workspace. Power features (time-travel, transactions, raw commands) are accessible but never in the way.

4. **Mac-native feel:** System colors, typography, and window management. Panels use standard macOS table/tree/list components. No custom chrome.

5. **Non-destructive:** Destructive operations require confirmation. Undo is always available. Strata's versioning means data is never truly lost.

6. **Offline-capable:** The app works fully offline for direct manipulation and command bar. Claude Data requires internet (Anthropic API), but the app is useful without it.

7. **Context-aware:** Claude Data knows what's on the workspace, what branch you're on, what you just edited. The conversation is always contextual.

## 12. Design Decisions

Resolved decisions from product review:

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **Interface model** | Unified workspace + Focus conversation | Not a traditional database browser. Workspace is a canvas of interactive panels driven by conversation. Focus is deep conversational mode. |
| **AI integration** | Anthropic API (Claude Data) | Claude Code proved the conversational tool-use model. Strata's 60 commands map perfectly to tool definitions. |
| **Multi-window vs tabs** | Separate windows (NSDocument) | Standard macOS behavior. Users can merge into tabs natively. |
| **Value editor** | Tree editor in MVP | Type-aware tree with inline editing per node. Raw JSON toggle deferred to backlog. |
| **Command bar output** | Persistent scrollable log (in conversation) | Conversation history serves as persistent command log. |
| **Undo support** | Cmd+Z in MVP | Strata's versioning makes this feasible. Critical for a database tool. |
| **External changes** | Auto-detect and refresh | Poll WAL changes ~1-2s. Essential for CLI + Foundry side-by-side workflows. |
| **Distribution** | DMG only | No App Store sandbox restrictions. Standard for developer tools. |
| **Without API key** | Fully functional for direct manipulation | Claude Data is an enhancement. Panels, command bar, and all CRUD work without a key. |
