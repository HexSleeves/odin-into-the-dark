package renderer

import gameio "../io"

import eng "../engine"
import "core:encoding/json"

// ─── High Score Table ─────────────────────────────────────────────────────────

// ─── Render-owned score cache ─────────────────────────────────────────────────
// Loaded once on first call to score_cache_get; stays valid until
// render_scores_invalidate() is called (should be called by the score-write
// path after score_manager_save).

@(private = "file")
Score_Cache :: struct {
	table:  Score_Table,
	loaded: bool,
}

@(private = "file")
g_score_cache: Score_Cache

// Invalidate the cache so the next render of the scores overlay re-reads disk.
// CONDUCTOR WIRE-UP: call render_scores_invalidate() in gameplay/restart.odin
// immediately after score_manager_save(scores, &table) at line 35.
render_scores_invalidate :: proc() {
	if g_score_cache.loaded {
		score_table_destroy(&g_score_cache.table)
		g_score_cache.loaded = false
	}
}

// Return a pointer to the cached table, loading from disk on first access.
// Package-visible: the scores overlay in clay_overlays.odin reads through this.
@(private)
score_cache_get :: proc(scores: ^Score_Manager) -> ^Score_Table {
	if !g_score_cache.loaded {
		g_score_cache.table = score_manager_load(scores)
		g_score_cache.loaded = true
	}
	return &g_score_cache.table
}

MAX_SCORES :: 10
SCORES_FILE :: "scores.json"

Score_Entry :: struct {
	depth:       int,
	kills:       int,
	turns:       int,
	items_found: int,
	cause:       string,
}

Score_Table :: struct {
	scores: [MAX_SCORES]Score_Entry,
	count:  int,
}

Score_Manager :: struct {
	file_path: string,
	storage:   eng.Storage_Manager,
}

score_manager_make :: proc() -> Score_Manager {
	return Score_Manager{file_path = SCORES_FILE, storage = eng.storage_manager_make()}
}

score_manager_path :: proc(scores: ^Score_Manager) -> string {
	if scores == nil || scores.file_path == "" {
		return SCORES_FILE
	}
	return scores.file_path
}

score_table_destroy :: proc(table: ^Score_Table) {
	if table == nil {
		return
	}
	for i in 0 ..< table.count {
		if len(table.scores[i].cause) > 0 {
			delete(table.scores[i].cause, context.allocator)
		}
	}
	table^ = {}
}

// ─── Load / Save ──────────────────────────────────────────────────────────────

score_manager_load :: proc(scores: ^Score_Manager) -> Score_Table {
	result: Score_Table
	path := score_manager_path(scores)

	storage: ^eng.Storage_Manager = nil
	if scores != nil {
		storage = &scores.storage
	}
	data, read_ok := eng.storage_manager_read(storage, path, context.allocator)
	if !read_ok {
		// No file yet — return empty table
		return result
	}
	defer delete(data, context.allocator)

	parse_err := json.unmarshal(data, &result)
	if parse_err != nil {
		gameio.logger_warnf(.Scores, "parse failed for %s: %v", path, parse_err)
		return {}
	}

	return result
}

score_manager_save :: proc(scores: ^Score_Manager, table: ^Score_Table) {
	path := score_manager_path(scores)
	data, marshal_err := json.marshal(table^, allocator = context.allocator)
	if marshal_err != nil {
		gameio.logger_errorf(.Scores, "marshal failed: %v", marshal_err)
		return
	}
	defer delete(data, context.allocator)

	storage: ^eng.Storage_Manager = nil
	if scores != nil {
		storage = &scores.storage
	}
	if !eng.storage_manager_write(storage, path, data) {
		gameio.logger_errorf(.Scores, "write failed for %s", path)
	}
}

// ─── Insert (sorted: depth desc, kills desc, turns asc) ──────────────────────

// Returns 0-based rank of the inserted entry, or -1 if it didn't make the table.
insert_score :: proc(table: ^Score_Table, entry: Score_Entry) -> int {
	// Find insertion position
	insert_pos := table.count
	for i in 0 ..< table.count {
		s := table.scores[i]
		if entry.depth > s.depth ||
		   (entry.depth == s.depth && entry.kills > s.kills) ||
		   (entry.depth == s.depth && entry.kills == s.kills && entry.turns < s.turns) {
			insert_pos = i
			break
		}
	}

	// If it doesn't make the table, bail
	if insert_pos >= MAX_SCORES {
		return -1
	}

	if table.count >= MAX_SCORES && len(table.scores[MAX_SCORES - 1].cause) > 0 {
		delete(table.scores[MAX_SCORES - 1].cause, context.allocator)
		table.scores[MAX_SCORES - 1].cause = ""
	}

	// Shift entries down (drop the last one if full)
	end := min(table.count, MAX_SCORES - 1)
	for i := end; i > insert_pos; i -= 1 {
		table.scores[i] = table.scores[i - 1]
	}

	table.scores[insert_pos] = entry
	table.count = min(table.count + 1, MAX_SCORES)

	return insert_pos
}
