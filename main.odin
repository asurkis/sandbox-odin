package main

import "core:fmt"
import rl "vendor:raylib"

FIELD_SIZE :: [2]int{7, 7}
MARGIN :: [4]int{32, 64, 32, 32} // left, top, right, bottom
CELL_SIZE_HALF :: 64

CELL_SIZE :: 2 * CELL_SIZE_HALF
ROBOT_SIZE :: 2 * ROBOT_SIZE_HALF

ROBOT_SIZE_HALF :: 48
WIND_SHIELD_SIZE_HALF :: [2]int{40, 16}
WIND_SHIELD_OFFSET :: 8
ROBOT_OFFSET :: CELL_SIZE_HALF - ROBOT_SIZE_HALF

WINDOW_SIZE := CELL_SIZE * FIELD_SIZE + MARGIN.xy + MARGIN.zw

main :: proc() {
	game := init_game()
	strat := init_strategy()
	defer delete(game.field.cells)

	rl.InitWindow(i32(WINDOW_SIZE.x), i32(WINDOW_SIZE.y), "Main window")
	last_tick := rl.GetTime()
	unsaved_frame := true
	i_frame := 0
	for !rl.WindowShouldClose() {
		cur_tick := rl.GetTime()
		if !unsaved_frame && game.field.n_dirts > 0 && cur_tick >= last_tick + 0.0 {
			strat_step(&strat, &game)
			last_tick = cur_tick
			unsaved_frame = true
		}

		rl.BeginDrawing()
		rl.DrawFPS(20, 20)
		rl.ClearBackground(rl.WHITE)
		draw_game(&game)
		rl.EndDrawing()

		if unsaved_frame {
			unsaved_frame = false
			image := rl.LoadImageFromScreen()
			defer rl.UnloadImage(image)
			filename := fmt.ctprintf("out/frame%d.png", i_frame)
			defer delete(filename, allocator = context.temp_allocator)
			i_frame += 1
			// assert(rl.ExportImage(image, filename))
		}
	}
}

Strategy :: struct {
	state:          enum {
		READY,
		MOVING_FORWARD,
	},
	last_unplanted: [2]int,
	looped:         bool,
}

strat_step :: proc(strat: ^Strategy, game: ^Game) {
	try_plant_and_move_forward :: proc(strat: ^Strategy, game: ^Game) {
		strat.looped = false
		strat.last_unplanted = game.robot.pos + game.robot.forward
		if is_plantable(game) {
			plant(game)
			if is_free_front(game) do strat.state = .MOVING_FORWARD
		} else {
			if is_free_front(game) do move_forward(game)
		}
	}
	switch strat.state {
	case .READY: // do nothing
	case .MOVING_FORWARD:
		move_forward(game)
		strat.state = .READY
		return
	}
	if !is_free_back(game) && !is_free_left(game) && !is_free_right(game) {
		try_plant_and_move_forward(strat, game)
	} else if is_free_right(game) {
		turn_right(game)
		if is_free_right(game) do strat.state = .MOVING_FORWARD
	} else if is_free_front(game) {
		if strat.looped && strat.last_unplanted == game.robot.pos {
			try_plant_and_move_forward(strat, game)
		} else {
			move_forward(game)
			strat.looped = true
		}
	} else {
		turn_left(game)
	}
}

init_strategy :: proc() -> Strategy {
	return {}
}

init_game :: proc() -> Game {
	game: Game
	game.robot.forward = {1, 0}
	game.field.size = FIELD_SIZE
	game.field.cells = make([dynamic]Cell, 0, game.field.size.x * game.field.size.y)
	for row in 0 ..< game.field.size.y {
		for col in 0 ..< game.field.size.x {
			if row % 2 == 0 || col % 2 == 0 {
				append(&game.field.cells, Cell.DIRT)
				game.field.n_dirts += 1
			} else {
				append(&game.field.cells, Cell.WALL)
			}
		}
	}
	return game
}

draw_game :: proc(game: ^Game) {
	for row in 0 ..< game.field.size.y {
		for col in 0 ..< game.field.size.x {
			color: rl.Color
			switch game.field.cells[col + game.field.size.x * row] {
			case .EMPTY:
				color = rl.BEIGE
			case .DIRT:
				color = rl.BROWN
			case .FLOWERS:
				color = rl.GREEN
			case .WALL:
				color = rl.MAROON
			}
			xy := MARGIN.xy + CELL_SIZE * {col, row}
			rl.DrawRectangle(i32(xy.x), i32(xy.y), CELL_SIZE, CELL_SIZE, color)
		}
	}
	xy := MARGIN.xy + CELL_SIZE * game.robot.pos + ROBOT_OFFSET
	rl.DrawRectangle(i32(xy.x), i32(xy.y), ROBOT_SIZE, ROBOT_SIZE, rl.RED)

	forward := game.robot.forward
	right := rotate_right(forward)

	off_forward := (ROBOT_SIZE_HALF - WIND_SHIELD_SIZE_HALF.y - WIND_SHIELD_OFFSET) * forward
	off_right := WIND_SHIELD_SIZE_HALF.x * right

	xy += ROBOT_SIZE_HALF + off_forward
	size_half := off_right - WIND_SHIELD_SIZE_HALF.y * forward
	size_half.x = abs(size_half.x)
	size_half.y = abs(size_half.y)
	xy -= size_half
	size := 2 * size_half
	rl.DrawRectangle(i32(xy.x), i32(xy.y), i32(size.x), i32(size.y), rl.BLUE)

	if game.field.n_dirts <= 0 {
		VICTORY: cstring : "Victory!"
		size := [2]int{0, 30}
		size.x = cast(int)rl.MeasureText(VICTORY, i32(size.y))
		xy := MARGIN.xy + (CELL_SIZE * FIELD_SIZE - size) / 2
		rl.DrawRectangle(i32(xy.x), i32(xy.y), i32(size.x), i32(size.y), {0, 0, 0, 127})
		rl.DrawText(VICTORY, i32(xy.x), i32(xy.y), i32(size.y), rl.GREEN)
	}
}

Cell :: enum {
	EMPTY,
	DIRT,
	FLOWERS,
	WALL,
}

Robot :: struct {
	pos:     [2]int,
	forward: [2]int,
}

Field :: struct {
	size:    [2]int,
	cells:   [dynamic]Cell,
	n_dirts: int,
}

Game :: struct {
	robot: Robot,
	field: Field,
}

move_forward :: proc(game: ^Game) {
	game.robot.pos += game.robot.forward
	_verify_state(game)
}

move_backward :: proc(game: ^Game) {
	game.robot.pos += game.robot.forward
	_verify_state(game)
}

turn_right :: proc(game: ^Game) {
	game.robot.forward = rotate_right(game.robot.forward)
	_verify_state(game)
}

turn_left :: proc(game: ^Game) {
	game.robot.forward = rotate_left(game.robot.forward)
	_verify_state(game)
}

plant :: proc(game: ^Game) {
	_verify_state(game)
	pos := game.robot.pos
	size := game.field.size
	cell := &game.field.cells[pos.x + size.x * pos.y]
	assert(cell^ == .DIRT)
	cell^ = .FLOWERS
	game.field.n_dirts -= 1
}

is_free_front :: proc(game: ^Game) -> bool {
	return _is_free(game, {1, 0})
}

is_free_back :: proc(game: ^Game) -> bool {
	return _is_free(game, {-1, 0})
}

is_free_right :: proc(game: ^Game) -> bool {
	return _is_free(game, {0, 1})
}

is_free_left :: proc(game: ^Game) -> bool {
	return _is_free(game, {0, -1})
}

is_plantable :: proc(game: ^Game) -> bool {
	cell := _get_cell(game, {}) or_return
	return cell == .DIRT
}

_is_free :: proc(game: ^Game, off: [2]int) -> bool {
	cell := _get_cell(game, off) or_return
	return cell == .EMPTY || cell == .DIRT
}

_get_cell :: proc(game: ^Game, off: [2]int) -> (cell: Cell, ok: bool) {
	pos := game.robot.pos
	forward := game.robot.forward
	right := rotate_right(forward)
	pos += off.x * forward + off.y * right
	size := game.field.size
	if 0 > pos.x || pos.x >= size.x do return
	if 0 > pos.y || pos.y >= size.y do return
	cell = game.field.cells[pos.x + size.x * pos.y]
	ok = true
	return
}

_verify_state :: proc(game: ^Game, operation := #caller_location) {
	acceptable := _is_free(game, {})
	if !acceptable do fmt.eprintln("Failed operation", operation.procedure)
	assert(acceptable)
}

rotate_right :: proc(v: [2]int) -> [2]int {
	return {-v.y, v.x}
}

rotate_left :: proc(v: [2]int) -> [2]int {
	return {v.y, -v.x}
}
