package game

import "core:fmt"
import rl "vendor:raylib"

Game :: struct {}

@(export)
on_init :: proc() -> rawptr {
	game := new(Game)
	return rawptr(game)
}

@(export)
on_deinit :: proc(game_rawptr: rawptr) {
	game := (^Game)(game_rawptr)
	free(game)
}

@(export)
on_reload :: proc(game_rawptr: rawptr) {
	game := (^Game)(game_rawptr)
}

@(export)
on_unload :: proc(game_rawptr: rawptr) {}

@(export)
on_frame :: proc(game_rawptr: rawptr) -> (game_continues: bool) {
	game_continues = !rl.WindowShouldClose()
	rl.BeginDrawing()
	defer rl.EndDrawing()
	rl.ClearBackground(rl.WHITE)
	rl.DrawRectangle(100, 100, 100, 100, rl.RED)
	return
}
