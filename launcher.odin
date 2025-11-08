package main

import "game"
import rl "vendor:raylib"

main :: proc() {
	rl.InitWindow(1920, 1080, "Main window")
	game_state := game.on_init()
	defer game.on_deinit(game_state)
	game_continues := true

	for game_continues {
		game_continues = game.on_frame(game_state)
	}
}

