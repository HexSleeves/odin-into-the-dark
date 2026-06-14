package renderer

import gameio "../io"

import eng "../engine"
import "base:runtime"
import "core:encoding/json"

// ─── High Score Table ─────────────────────────────────────────────────────────

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
	file_path:    string,
	storage:      eng.Storage_Manager,
	// Parsed-scores cache. The only in-process writer is score_manager_save, so a
	// write-through cache stays coherent without re-reading disk every frame.
	// Cached cause strings live on runtime.default_allocator (stable across
	// frames); score_manager_load hands back an owned clone on context.allocator.
	cached:       Score_Table,
	cache_loaded: bool,
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

// Deep-copy a Score_Table, cloning each cause string onto `allocator` so the copy
// owns its own storage (callers free with score_table_destroy / the matching delete).
score_table_clone :: proc(src: ^Score_Table, allocator := context.allocator) -> Score_Table {
	out: Score_Table
	if src == nil {
		return out
	}
	out.count = src.count
	for i in 0 ..< src.count {
		out.scores[i] = src.scores[i]
		if len(src.scores[i].cause) > 0 {
			out.scores[i].cause = clone_score_string(src.scores[i].cause, allocator)
		}
	}
	return out
}

@(private = "file")
clone_score_string :: proc(s: string, allocator: runtime.Allocator) -> string {
	buf := make([]u8, len(s), allocator)
	copy(buf, s)
	return string(buf)
}

// Free the cached table's owned strings (on runtime.default_allocator). Cache
// strings otherwise leak once at exit, which is harmless (no shutdown hook).
score_manager_cache_destroy :: proc(scores: ^Score_Manager) {
	if scores == nil || !scores.cache_loaded {
		return
	}
	for i in 0 ..< scores.cached.count {
		if len(scores.cached.scores[i].cause) > 0 {
			delete(scores.cached.scores[i].cause, runtime.default_allocator())
		}
	}
	scores.cached = {}
	scores.cache_loaded = false
}

// ─── Load / Save ──────────────────────────────────────────────────────────────

// Read scores.json from disk (no caching). Returns a table whose cause strings
// live on `allocator`.
@(private = "file")
score_read_from_disk :: proc(scores: ^Score_Manager, allocator: runtime.Allocator) -> Score_Table {
	result: Score_Table
	path := score_manager_path(scores)

	storage: ^eng.Storage_Manager = nil
	if scores != nil {
		storage = &scores.storage
	}
	data, read_ok := eng.storage_manager_read(storage, path, context.allocator)
	if !read_ok {
		// No file yet — empty table
		return result
	}
	defer delete(data, context.allocator)

	context.allocator = allocator
	parse_err := json.unmarshal(data, &result, allocator = allocator)
	if parse_err != nil {
		gameio.logger_warnf(.Scores, "parse failed for %s: %v", path, parse_err)
		return {}
	}

	return result
}

// Load the high-score table. Reads disk only on the first call (or after a
// score_manager_save); subsequent calls serve the cached parse. Returns an OWNED
// clone the caller must free with score_table_destroy.
score_manager_load :: proc(scores: ^Score_Manager) -> Score_Table {
	if scores == nil {
		// No manager to cache on — read straight from disk on context.allocator.
		return score_read_from_disk(scores, context.allocator)
	}

	if !scores.cache_loaded {
		scores.cached = score_read_from_disk(scores, runtime.default_allocator())
		scores.cache_loaded = true
	}

	return score_table_clone(&scores.cached, context.allocator)
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
		return
	}

	// Write-through: refresh the cache from the just-saved table so the next
	// load sees the new entry without re-reading disk.
	if scores != nil {
		score_manager_cache_destroy(scores)
		scores.cached = score_table_clone(table, runtime.default_allocator())
		scores.cache_loaded = true
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
