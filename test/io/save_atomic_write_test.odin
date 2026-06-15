#+build !js
package gameio

import gcore "../core"
import eng "../engine"
import gameui "../ui"
import "base:runtime"
import "core:testing"

// ─── In-memory filesystem fake ──────────────────────────────────────────────
//
// A tiny path→bytes store used to exercise the atomic-write / backup-recovery
// behavior of save_game_to_storage + load_game_from_storage without touching
// the real disk. Capacity is fixed; tests use only a handful of paths.

MEM_FS_MAX_FILES :: 8
MEM_FS_MAX_PATH :: 64

Mem_File :: struct {
	// path is OWNED (copied into path_buf); callers may free the string they pass.
	path_buf: [MEM_FS_MAX_PATH]u8,
	path_len: int,
	data:     [dynamic]u8,
	present:  bool,
}

Mem_File_System :: struct {
	files:        [MEM_FS_MAX_FILES]Mem_File,
	rename_avail: bool,
}

mem_file_set_path :: proc(f: ^Mem_File, path: string) {
	n := min(len(path), MEM_FS_MAX_PATH)
	for i in 0 ..< n {f.path_buf[i] = path[i]}
	f.path_len = n
}

mem_file_path :: proc(f: ^Mem_File) -> string {
	return string(f.path_buf[:f.path_len])
}

mem_fs_find :: proc(fs: ^Mem_File_System, path: string) -> int {
	for i in 0 ..< MEM_FS_MAX_FILES {
		if fs.files[i].present && mem_file_path(&fs.files[i]) == path {return i}
	}
	return -1
}

mem_fs_free_slot :: proc(fs: ^Mem_File_System) -> int {
	for i in 0 ..< MEM_FS_MAX_FILES {
		if !fs.files[i].present {return i}
	}
	return -1
}

mem_fs_destroy :: proc(fs: ^Mem_File_System) {
	for i in 0 ..< MEM_FS_MAX_FILES {
		if fs.files[i].data != nil {delete(fs.files[i].data)}
	}
}

mem_fs_read :: proc(ctx: rawptr, path: string, allocator: runtime.Allocator) -> ([]u8, bool) {
	fs := cast(^Mem_File_System)ctx
	idx := mem_fs_find(fs, path)
	if idx < 0 {return nil, false}
	src := fs.files[idx].data[:]
	buf := make([]u8, len(src), allocator)
	copy(buf, src)
	return buf, true
}

mem_fs_write :: proc(ctx: rawptr, path: string, data: []u8) -> bool {
	fs := cast(^Mem_File_System)ctx
	idx := mem_fs_find(fs, path)
	if idx < 0 {
		idx = mem_fs_free_slot(fs)
		if idx < 0 {return false}
		fs.files[idx].present = true
		mem_file_set_path(&fs.files[idx], path)
		fs.files[idx].data = make([dynamic]u8)
	}
	clear(&fs.files[idx].data)
	append(&fs.files[idx].data, ..data)
	return true
}

mem_fs_exists :: proc(ctx: rawptr, path: string) -> bool {
	fs := cast(^Mem_File_System)ctx
	return mem_fs_find(fs, path) >= 0
}

mem_fs_remove :: proc(ctx: rawptr, path: string) -> bool {
	fs := cast(^Mem_File_System)ctx
	idx := mem_fs_find(fs, path)
	if idx < 0 {return false}
	fs.files[idx].present = false
	clear(&fs.files[idx].data)
	return true
}

mem_fs_rename :: proc(ctx: rawptr, old_path, new_path: string) -> bool {
	fs := cast(^Mem_File_System)ctx
	old_idx := mem_fs_find(fs, old_path)
	if old_idx < 0 {return false}
	// Overwrite/insert destination.
	dst := mem_fs_find(fs, new_path)
	if dst < 0 {
		dst = mem_fs_free_slot(fs)
		if dst < 0 {return false}
		fs.files[dst].present = true
		mem_file_set_path(&fs.files[dst], new_path)
		fs.files[dst].data = make([dynamic]u8)
	}
	clear(&fs.files[dst].data)
	append(&fs.files[dst].data, ..fs.files[old_idx].data[:])
	fs.files[old_idx].present = false
	clear(&fs.files[old_idx].data)
	return true
}

mem_fs_backend :: proc(fs: ^Mem_File_System) -> eng.Engine_File_System {
	backend := eng.Engine_File_System {
		ctx               = fs,
		read_entire_file  = mem_fs_read,
		write_entire_file = mem_fs_write,
		exists            = mem_fs_exists,
		remove            = mem_fs_remove,
	}
	if fs.rename_avail {
		backend.rename = mem_fs_rename
	}
	return backend
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

build_saveable_game :: proc(game: ^Game) {
	game_init_world(game)
	game.player.pos = Vec2{1, 1}
	game.player.hp = 10
	game.player.max_hp = 10
	game.depth = 3
	game.kills = 7
}

// ─── Tests ─────────────────────────────────────────────────────────────────

@(test)
save_game_writes_to_temp_then_renames_over_target_keeping_one_backup :: proc(t: ^testing.T) {
	fs := Mem_File_System {
		rename_avail = true,
	}
	defer mem_fs_destroy(&fs)
	storage := eng.storage_manager_make(mem_fs_backend(&fs))

	path := "save.dat"
	game: Game
	build_saveable_game(&game)
	defer game_cleanup(&game)
	turns := eng.turn_manager_make()

	// First save: no prior file, so no backup is produced.
	testing.expect(t, save_game_to_storage(&turns, &game, &storage, path))
	testing.expect(t, mem_fs_exists(&fs, path), "primary save must exist after rename")
	testing.expect(t, !mem_fs_exists(&fs, "save.dat.tmp"), "temp file must be renamed away")
	testing.expect(t, !mem_fs_exists(&fs, "save.dat.bak"), "no backup before a second save")

	// Second save: the existing primary must be rolled into a one-deep backup.
	testing.expect(t, save_game_to_storage(&turns, &game, &storage, path))
	testing.expect(t, mem_fs_exists(&fs, path), "primary save must exist after second rename")
	testing.expect(t, mem_fs_exists(&fs, "save.dat.bak"), "previous save must be kept as backup")
	testing.expect(t, !mem_fs_exists(&fs, "save.dat.tmp"), "temp file must be renamed away")
}

@(test)
save_game_falls_back_to_direct_write_when_rename_is_unavailable :: proc(t: ^testing.T) {
	fs := Mem_File_System {
		rename_avail = false, // WASM-like: no rename hook
	}
	defer mem_fs_destroy(&fs)
	storage := eng.storage_manager_make(mem_fs_backend(&fs))

	path := "save.dat"
	game: Game
	build_saveable_game(&game)
	defer game_cleanup(&game)
	turns := eng.turn_manager_make()

	testing.expect(t, save_game_to_storage(&turns, &game, &storage, path))
	// Direct write lands at the primary path with no temp/backup artifacts.
	testing.expect(t, mem_fs_exists(&fs, path), "direct write must land at the primary path")
	testing.expect(t, !mem_fs_exists(&fs, "save.dat.tmp"), "no temp file on the direct path")
	testing.expect(t, !mem_fs_exists(&fs, "save.dat.bak"), "no backup on the direct path")
}

@(test)
sparse_visited_floors_round_trip_end_to_end_at_correct_depths :: proc(t: ^testing.T) {
	// Full save → load through the real serializer with a SPARSE set of present
	// floors at non-contiguous depths. v14 writes only present floors as a
	// length-prefixed list; restore must rebuild the visited_floors stack with each
	// floor back at its original depth slot and absent depths left nil.
	fs := Mem_File_System {
		rename_avail = true,
	}
	defer mem_fs_destroy(&fs)
	storage := eng.storage_manager_make(mem_fs_backend(&fs))

	path := "save.dat"
	game: Game
	build_saveable_game(&game)
	defer game_cleanup(&game)

	// Populate present floors at depths 0, 4, and MAX_DEPTH (boundary). Depth 4 also
	// matches game.depth so it overlaps the live floor's depth slot.
	game.depth = 4
	present := []int{0, 4, gcore.MAX_DEPTH}
	for d in present {
		floor := new(Saved_Floor, runtime.default_allocator())
		floor.player_pos = Vec2{d + 1, d + 2}
		floor.rooms = make([dynamic]Room)
		floor.enemies = make([dynamic]Enemy)
		floor.items = make([dynamic]Item)
		floor.light_sources = make([dynamic]Light_Source)
		// Tag a unique tile per floor so we can prove the right floor landed.
		floor.tiles[d] = Tile {
			type = .Wall,
		}
		game.visited_floors[d] = floor
	}

	turns := eng.turn_manager_make()
	testing.expect(t, save_game_to_storage(&turns, &game, &storage, path))

	content := gcore.content_manager_make()
	defer gcore.content_manager_destroy(&content)
	loaded: Game
	defer game_cleanup(&loaded)
	loaded_turns := eng.turn_manager_make()
	camera := eng.camera_manager_make()
	vfx := eng.vfx_manager_make()
	ui := gameui.ui_manager_make(false)
	messages := eng.message_manager_make()

	testing.expect(
		t,
		load_game_from_storage(
			&content,
			&loaded_turns,
			&camera,
			&vfx,
			&ui,
			&messages,
			&loaded,
			&storage,
			path,
		),
	)

	// Present depths must be reconstructed at the right slots with the right payload.
	for d in present {
		f := loaded.visited_floors[d]
		testing.expectf(t, f != nil, "depth %d floor must be restored", d)
		if f == nil {continue}
		testing.expect_value(t, f.player_pos, Vec2{d + 1, d + 2})
		testing.expect_value(t, f.tiles[d].type, gcore.Tile_Type.Wall)
	}

	// Absent depths must stay nil — nothing was written for them.
	for d in 0 ..= gcore.MAX_DEPTH {
		is_present := false
		for p in present {
			if p == d {is_present = true; break}
		}
		if is_present {continue}
		testing.expectf(t, loaded.visited_floors[d] == nil, "absent depth %d must stay nil", d)
	}
}

@(test)
load_game_recovers_from_backup_when_primary_save_is_corrupt :: proc(t: ^testing.T) {
	fs := Mem_File_System {
		rename_avail = true,
	}
	defer mem_fs_destroy(&fs)
	storage := eng.storage_manager_make(mem_fs_backend(&fs))

	path := "save.dat"
	game: Game
	build_saveable_game(&game)
	defer game_cleanup(&game)
	turns := eng.turn_manager_make()

	// Write a good save, then a second save so a valid `.bak` exists.
	testing.expect(t, save_game_to_storage(&turns, &game, &storage, path))
	testing.expect(t, save_game_to_storage(&turns, &game, &storage, path))
	testing.expect(t, mem_fs_exists(&fs, "save.dat.bak"), "backup must exist for recovery test")

	// Simulate a torn write: flip a payload byte in the primary so its CRC fails.
	primary := mem_fs_find(&fs, path)
	testing.expect(t, primary >= 0)
	testing.expect(t, len(fs.files[primary].data) > size_of(Save_Header))
	fs.files[primary].data[size_of(Save_Header)] ~= 0xFF

	// Load must reject the corrupt primary and recover from the backup.
	content := gcore.content_manager_make()
	defer gcore.content_manager_destroy(&content)
	loaded: Game
	defer game_cleanup(&loaded)
	loaded_turns := eng.turn_manager_make()
	camera := eng.camera_manager_make()
	vfx := eng.vfx_manager_make()
	ui := gameui.ui_manager_make(false)
	messages := eng.message_manager_make()

	ok := load_game_from_storage(
		&content,
		&loaded_turns,
		&camera,
		&vfx,
		&ui,
		&messages,
		&loaded,
		&storage,
		path,
	)
	testing.expect(t, ok, "load must recover from the valid backup")
	testing.expect_value(t, loaded.depth, 3)
	testing.expect_value(t, loaded.kills, 7)

	// After a successful load all save artifacts are consumed (one load per save).
	testing.expect(t, !mem_fs_exists(&fs, path), "primary must be removed after load")
	testing.expect(t, !mem_fs_exists(&fs, "save.dat.bak"), "backup must be removed after load")
	testing.expect(t, !mem_fs_exists(&fs, "save.dat.tmp"), "temp must be removed after load")
}
