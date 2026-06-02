package main

import "core:encoding/json"
import "core:os"

// ─── High Score Table ─────────────────────────────────────────────────────────

MAX_SCORES :: 10
SCORES_FILE :: "scores.json"

Score_Entry :: struct {
	depth: int,
	kills: int,
	turns: int,
	cause: string,
}

Score_Table :: struct {
	scores: [MAX_SCORES]Score_Entry,
	count:  int,
}

// ─── Load / Save ──────────────────────────────────────────────────────────────

load_scores :: proc() -> Score_Table {
	result: Score_Table

	data, read_err := os.read_entire_file(SCORES_FILE, context.allocator)
	if read_err != nil {
		// No file yet — return empty table
		return result
	}
	defer delete(data, context.allocator)

	parse_err := json.unmarshal(data, &result)
	if parse_err != nil {
		logger_warnf(.Scores, "parse failed for %s: %v", SCORES_FILE, parse_err)
		return {}
	}

	return result
}

save_scores :: proc(table: ^Score_Table) {
	data, marshal_err := json.marshal(table^, allocator = context.allocator)
	if marshal_err != nil {
		logger_errorf(.Scores, "marshal failed: %v", marshal_err)
		return
	}
	defer delete(data, context.allocator)

	write_err := os.write_entire_file(SCORES_FILE, data)
	if write_err != nil {
		logger_errorf(.Scores, "write failed for %s: %v", SCORES_FILE, write_err)
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

	// Shift entries down (drop the last one if full)
	end := min(table.count, MAX_SCORES - 1)
	for i := end; i > insert_pos; i -= 1 {
		table.scores[i] = table.scores[i - 1]
	}

	table.scores[insert_pos] = entry
	table.count = min(table.count + 1, MAX_SCORES)

	return insert_pos
}
