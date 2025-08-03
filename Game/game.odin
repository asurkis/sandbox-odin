package game

import "base:runtime"
import "core:fmt"
import "core:math"
import "core:reflect"
import rl "vendor:raylib"

Game :: struct {
	prev_frame:  f64,
	unload_time: f64,
	pos:         [2]f64,
	vel:         [2]f64,
}

RADIUS :: 50
WINDOW_WIDTH :: 1920
WINDOW_HEIGHT :: 1080

@(export)
on_init :: proc() -> rawptr {
	game := new(Game)
	return game
}

@(export)
on_deinit :: proc(game_rawptr: rawptr) {
	game := (^Game)(game_rawptr)
	free(game)
}

@(export)
on_reload :: proc(game_rawptr: rawptr) -> rawptr {
	when #defined(Game_Old) {
		game_old := (^Game_Old)(game_rawptr)
		defer free(game_old)
		game_new := new(Game)
		for field_old in reflect.struct_fields_zipped(Game_Old) {
			type := field_old.type
			field_new := reflect.struct_field_by_name(Game, field_old.name)
			if type == field_new.type {
				field_ptr_old := ([^]byte)(uintptr(game_old) + field_old.offset)
				field_ptr_new := ([^]byte)(uintptr(game_new) + field_new.offset)
				copy(field_ptr_new[:type.size], field_ptr_old[:type.size])
			}
		}
		game_new.vel = {0.0, 0.0}
		game := game_new
	} else {
		game := (^Game)(game_rawptr)
	}
	load_time := rl.GetTime()
	game.prev_frame = load_time
	fmt.println(
		"Loaded at ",
		load_time,
		".  Reload took ",
		load_time - game.unload_time,
		" seconds.",
		sep = "",
	)
	// rl.SetTargetFPS(rl.GetMonitorRefreshRate(rl.GetCurrentMonitor()))
	rl.SetWindowSize(WINDOW_WIDTH, WINDOW_HEIGHT)
	return game
}

@(export)
on_unload :: proc(game_rawptr: rawptr) {
	game := (^Game)(game_rawptr)
	game.unload_time = rl.GetTime()
	fmt.print("Unloaded at ", game.unload_time, ".  ", sep = "")
}

@(export)
on_frame :: proc(game_rawptr: rawptr) -> (game_continues: bool) {
	game := (^Game)(game_rawptr)
	curr_frame := rl.GetTime()
	time_delta := curr_frame - game.prev_frame
	defer game.prev_frame = curr_frame

	mouse_pos: [2]f64
	mouse_pos.x = f64(rl.GetMouseX())
	mouse_pos.y = f64(rl.GetMouseY())
	stretch_dir := mouse_pos - game.pos
	game.vel += time_delta * (2 * stretch_dir + {0, 98})
	game.vel *= math.exp(-0.5 * time_delta)
	game.pos += time_delta * game.vel
	// game.pos = mouse_pos

	if game.pos.x < RADIUS {
		game.pos.x = 2 * RADIUS - game.pos.x
		game.vel.x = math.abs(game.vel.x)
	}
	if game.pos.y < RADIUS {
		game.pos.y = 2 * RADIUS - game.pos.y
		game.vel.y = math.abs(game.vel.y)
	}
	if game.pos.x > WINDOW_WIDTH - RADIUS {
		game.pos.x = 2 * (WINDOW_WIDTH - RADIUS) - game.pos.x
		game.vel.x = -math.abs(game.vel.x)
	}
	if game.pos.y > WINDOW_HEIGHT - RADIUS {
		game.pos.y = 2 * (WINDOW_HEIGHT - RADIUS) - game.pos.y
		game.vel.y = -math.abs(game.vel.y)
	}

	game_continues = !rl.WindowShouldClose()
	rl.BeginDrawing()
	defer rl.EndDrawing()
	rl.ClearBackground(rl.WHITE)
	rl.DrawLineEx(vec_cast(f32, game.pos), vec_cast(f32, mouse_pos), 5, rl.RED)
	rl.DrawCircleV(vec_cast(f32, game.pos), RADIUS, rl.BLUE)
	// rl.DrawFPS(10, 10)
	return
}

vec_cast :: proc($Out: typeid, x: [$N]$In) -> (y: [N]Out) {
	for i in 0 ..< N {
		y[i] = Out(x[i])
	}
	return
}
