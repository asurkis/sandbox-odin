package game

import "base:runtime"
import "core:fmt"
import "core:math"
import "core:reflect"
import rl "vendor:raylib"

Game0 :: struct {
	version: i64,
}

Game1 :: struct {
	using game0:    Game0,
	prev_frame:     f64,
	unload_time:    f64,
	pos:            [2]f64,
	dir:            f64,
	background:     rl.Image,
	background_gpu: rl.Texture,
}

Game :: Game1

WINDOW_WIDTH :: 1920
WINDOW_HEIGHT :: 1080

@(export)
on_init :: proc() -> rawptr {
	game1 := new(Game1)
	return on_reload(game1)
	// return game
}

@(export)
on_deinit :: proc(game_rawptr: rawptr) {
	game := (^Game)(game_rawptr)
	free(game)
}

@(export)
on_reload :: proc(game_rawptr: rawptr) -> rawptr {
	game0 := (^Game0)(game_rawptr)
	if game0.version == 0 do game0.version = 1
	if game0.version >= 1 {
		game := (^Game1)(game0)
		NEED_RELOAD :: true
		if (NEED_RELOAD ||
			   game.background.width != WINDOW_WIDTH ||
			   game.background.height != WINDOW_HEIGHT) {
			rl.UnloadTexture(game.background_gpu)
			// rl.UnloadImage(game.background)
			free(game.background.data)
			game.background_gpu = {}
			game.background = {}

			// game.background = rl.GenImagePerlinNoise(WINDOW_WIDTH, WINDOW_HEIGHT, 0, 0, 10)
			data := make([dynamic]u8, 4 * WINDOW_WIDTH * WINDOW_HEIGHT)
			for y in 0 ..< WINDOW_HEIGHT {
				for x in 0 ..< WINDOW_WIDTH {
					val := 0.5 + 0.5 * math.sin(f32(x) / 5)
					val = math.saturate(val) * 255
					data[(y * WINDOW_WIDTH + x) * 4 + 0] = u8(val)
					data[(y * WINDOW_WIDTH + x) * 4 + 1] = u8(val)
					data[(y * WINDOW_WIDTH + x) * 4 + 2] = u8(val)
					data[(y * WINDOW_WIDTH + x) * 4 + 3] = 255
				}
			}
			game.background.data = raw_data(data)
			game.background.width = WINDOW_WIDTH
			game.background.height = WINDOW_HEIGHT
			game.background.mipmaps = 1
			game.background.format = rl.PixelFormat.UNCOMPRESSED_R8G8B8A8
			game.background_gpu = rl.LoadTextureFromImage(game.background)
		}
		game0 = &game.game0
	}
	game := (^Game)(game0)
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
	rl.SetTargetFPS(rl.GetMonitorRefreshRate(rl.GetCurrentMonitor()))
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

	mouse_delta := rl.GetMouseDelta()
	movement: [3]f64
	if rl.IsKeyDown(rl.KeyboardKey.W) do movement.x += 1
	if rl.IsKeyDown(rl.KeyboardKey.A) do movement.y -= 1
	if rl.IsKeyDown(rl.KeyboardKey.S) do movement.x -= 1
	if rl.IsKeyDown(rl.KeyboardKey.D) do movement.y += 1
	if rl.IsKeyDown(rl.KeyboardKey.LEFT_SHIFT) do movement.xy *= 5
	if rl.IsMouseButtonDown(rl.MouseButton.RIGHT) do movement.z = f64(mouse_delta.x)

	game.dir += movement.z / 100
	for game.dir >= math.π do game.dir -= math.τ
	for game.dir < -math.π do game.dir += math.τ

	dir_sin, dir_cos := math.sincos(game.dir)
	forward := [2]f64{dir_cos, dir_sin}
	right := [2]f64{-dir_sin, dir_cos}

	game.pos += (movement.x * forward + movement.y * right) * 100 * time_delta

	game_continues = !rl.WindowShouldClose()
	rl.BeginDrawing()
	defer rl.EndDrawing()
	rl.ClearBackground(rl.WHITE)
	rl.DrawTexture(game.background_gpu, 0, 0, rl.WHITE)
	// rl.DrawLineEx(vec_cast(f32, game.pos), vec_cast(f32, game.pos + 100 * forward), 10, rl.RED)
	rl.DrawCircleV(vec_cast(f32, game.pos), 10, rl.BLUE)

	for dy in 0 ..< 7 {
		sample_sum: f64
		for dx in 1 ..= 16 {
			dist := math.pow(2, 0.25 * f64(dx))
			offx := 20 * dist * forward
			offy := 4 * dist * (f64(dy) - 3) * right
			pos := game.pos + offx + offy
			ipos := vec_cast(int, pos)
			// fpos: [2]f64
			// fpos := math.round(pos)
			sample_b: u8
			if 0 <= ipos.x && ipos.x < WINDOW_WIDTH && 0 <= ipos.y && ipos.y < WINDOW_HEIGHT {
				sample_b = ([^]u8)(game.background.data)[4 * (ipos.y * WINDOW_WIDTH + ipos.x)]
			}
			sample := f64(sample_b) / 255
			sample_sum += sample
			// val := 0.5 + 0.5 * math.sin(f32(pos.x) / 10)
			// sample = u8(math.saturate(val) * 255)
			color := rl.Color{sample_b, sample_b, sample_b, 255}
			rl.DrawCircleV(vec_cast(f32, pos), 10, color)
		}
		sample_sum_b := u8(math.saturate(sample_sum / 16) * 255)
		color := rl.Color{sample_sum_b, sample_sum_b, sample_sum_b, 255}
		rl.DrawRectangle(i32(dy) * 50 + 50, WINDOW_HEIGHT - 150, 50, 100, color)
	}
	rl.DrawFPS(10, 10)
	return
}

vec_cast :: proc($Out: typeid, x: [$N]$In) -> (y: [N]Out) {
	for i in 0 ..< N {
		y[i] = Out(x[i])
	}
	return
}

