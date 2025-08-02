package main

import "game"
import rl "vendor:raylib"

main :: proc() {
	game_state := game.on_init()
	defer game.on_deinit(game_state)
	game_continues := true

	rl.InitWindow(1280, 720, "Main window")
	for game_continues {
		game_continues = game.on_frame(game_state)
	}
}
