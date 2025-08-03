package main

import "core:dynlib"
import "core:fmt"
import "core:os/os2"
import rl "vendor:raylib"

main :: proc() {
	game_continues := true

	rl.InitWindow(1920, 1080, "Main window")
	reload_dll()

	for game_continues {
		dll_load_requested := rl.IsKeyPressed(rl.KeyboardKey.F2)
		dll_unload_requested := rl.IsKeyPressed(rl.KeyboardKey.F3)
		dll_reload_requested := rl.IsKeyPressed(rl.KeyboardKey.F5)

		if dll_load_requested do load_dll()
		if dll_unload_requested do unload_dll()
		if dll_reload_requested do reload_dll()

		if dll_loaded {
			game_continues = game_dll.on_frame(game_state)
		} else {
			if rl.WindowShouldClose() do game_continues = false
			rl.BeginDrawing()
			rl.ClearBackground(rl.WHITE)
			rl.DrawText("game.dll not loaded", 100, 100, 20, rl.RED)
			rl.EndDrawing()
		}
	}

	if dll_loaded {
		game_dll.on_deinit(game_state)
		ok := dynlib.unload_library(game_dll.__handle)
		if ok {
			// fmt.println("Successfully unloaded game.dll")
		} else {
			// fmt.println("Failed to unload game.dll")
		}
	}
}

Game_Symbol_Table :: struct {
	on_init:   proc() -> rawptr,
	on_deinit: proc(_: rawptr),
	on_reload: proc(_: rawptr) -> rawptr,
	on_unload: proc(_: rawptr),
	on_frame:  proc(_: rawptr) -> bool,
	__handle:  dynlib.Library,
}

game_dll: Game_Symbol_Table
dll_loaded := false
game_state: rawptr = nil

load_dll :: proc() {
	if dll_loaded do return
	// fmt.println("Trying to reload game.dll")
	count, _ := dynlib.initialize_symbols(&game_dll, "game")
	dll_loaded = count == 5
	if count == -1 {
		// fmt.println("Could not load game.dll")
	} else if !dll_loaded {
		// fmt.println("Found only", count, "symbols")
	} else {
		// fmt.println("Successfully loaded game.dll")
	}

	if dll_loaded {
		if game_state == nil {
			game_state = game_dll.on_init()
		} else {
			game_state = game_dll.on_reload(game_state)
		}
	}
}

unload_dll :: proc() {
	if !dll_loaded do return
	// fmt.println("Trying to unload game.dll")
	dll_loaded = false
	game_dll.on_unload(game_state)
	ok := dynlib.unload_library(game_dll.__handle)
	assert(ok)
	// fmt.println("Successfully unloaded game.dll")
	game_dll = {}
}

reload_dll :: proc() {
	unload_dll()
	{
		process_desc: os2.Process_Desc
		process_desc.command = {
			"odin",
			"build",
			"game",
			"-build-mode:dll",
			"-define:RAYLIB_SHARED=true",
			"-debug",
		}
		// process_desc.stdin = os2.stdin
		process_desc.stdout = os2.stdout
		process_desc.stderr = os2.stderr
		process, err := os2.process_start(process_desc)
		if err != nil do return
		defer _ = os2.process_close(process)
		for {
			process_state, err := os2.process_wait(process)
			if err != nil do return
			if process_state.exited {
				if process_state.exit_code == 0 {
					break
				} else {
					return
				}
			}
		}
	}
	load_dll()
}
