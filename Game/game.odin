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
		need_reload := true
		need_reload |= game.background.width != WINDOW_WIDTH
		need_reload |= game.background.height != WINDOW_HEIGHT
		if need_reload {
			rl.UnloadTexture(game.background_gpu)
			// rl.UnloadImage(game.background)
			free(game.background.data)
			game.background_gpu = {}
			game.background = {}

			// game.background = rl.GenImagePerlinNoise(WINDOW_WIDTH, WINDOW_HEIGHT, 0, 0, 10)
			data := make([dynamic]u8, 4 * WINDOW_WIDTH * WINDOW_HEIGHT)
			for y in 0 ..< WINDOW_HEIGHT {
				for x in 0 ..< WINDOW_WIDTH {
					val := 0.5 + 0.5 * math.sin(f32(x) / 20)
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

	for dy in 0 ..< 15 {
		sample_sum: f64
		sample_integral: f64
		sample_dir := forward + (f64(dy) - 7) * right / 7
		FROX_DEPTH :: 80
		FARPLANE :: 4
		DEPTH :: 16
		for dx in 1 ..= FROX_DEPTH {
			dist0 := math.pow(2, f64(dx - 1) * FARPLANE / FROX_DEPTH)
			dist1 := math.pow(2, f64(dx) * FARPLANE / FROX_DEPTH)
			pos0 := game.pos + 20 * dist0 * sample_dir
			pos1 := game.pos + 20 * dist1 * sample_dir
			ipos := vec_cast(int, pos1)
			// fpos: [2]f64
			// fpos := math.round(pos)

			sample_b: u8
			// sample_pos_valid := true
			// sample_pos_valid &= 0 <= ipos.x && ipos.x < WINDOW_WIDTH
			// sample_pos_valid &= 0 <= ipos.y && ipos.y < WINDOW_HEIGHT
			// sample_i := 4 * (ipos.y * WINDOW_WIDTH + ipos.x)
			// if sample_pos_valid do sample_b = ([^]u8)(game.background.data)[sample_i]

			val := 0.5 + 0.5 * math.sin(f32(pos1.x) / 20)
			sample_b = u8(math.saturate(val) * 255)
			// sample := f64(sample_b) / 255
			sample := f64(val)
			// integral (0.5 + 0.5 * sin(a t + b)) = 0.5 t - 0.5 cos(a t + b) / a + C
			// a t0 + b = pos0.x / 20
			// a t1 + b = pos1.x / 20
			// a (t1 - t0) = pos1.x - pos0.x
			// a = (pos1.x - pos0.x) / (t1 - t0)
			// b = pos0.x - a t0
			a := (pos1.x - pos0.x) / math.max(dist1 - dist0, 0.01) / 20
			b := pos0.x / 20 - a * dist0
			integral := 0.5 * (dist1 - dist0)
			integral +=
				0.5 *
				(math.cos(a * dist0 + b) - math.cos(a * dist1 + b)) /
				(math.sign(a) * math.max(math.abs(a), 0.01))
			sample_sum += sample * (dist1 - dist0) / DEPTH
			sample_integral += integral / DEPTH
			color := rl.Color{sample_b, sample_b, sample_b, 255}
			rl.DrawCircleV(vec_cast(f32, pos1), 10, color)
		}
		{
			b := u8(math.saturate(sample_sum) * 255)
			color := rl.Color{b, b, b, 255}
			rl.DrawRectangle(i32(dy) * 50 + 50, WINDOW_HEIGHT - 150, 50, 50, color)
		}
		{
			b := u8(math.saturate(math.abs(sample_sum - sample_integral)) * 255)
			color := rl.Color{b, b, b, 255}
			rl.DrawRectangle(i32(dy) * 50 + 50, WINDOW_HEIGHT - 100, 50, 50, color)
		}
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

