package main

import "core:fmt"
import rl "vendor:raylib"

FIELD_SIZE :: [2]int{7, 7}
MARGIN :: [4]int{32, 64, 32, 32} // left, top, right, bottom
CELL_SIZE_HALF :: 64

CELL_SIZE :: 2 * CELL_SIZE_HALF
ROBOT_SIZE :: 2 * ROBOT_SIZE_HALF

ROBOT_SIZE_HALF :: 48
WIND_SHIELD_SIZE_HALF :: [2]int{16, 40}
WIND_SHIELD_OFFSET :: [2]int{-8, WIND_SHIELD_SIZE_HALF.y}
ROBOT_OFFSET :: CELL_SIZE_HALF - ROBOT_SIZE_HALF

STEP_DURATION :: 0.25
WINDOW_SIZE := CELL_SIZE * FIELD_SIZE + MARGIN.xy + MARGIN.zw

main :: proc() {
	game := init_game()
	strat := init_strategy()
	defer delete(game.field.cells)

	rl.InitWindow(i32(WINDOW_SIZE.x), i32(WINDOW_SIZE.y), "Main window")
	for !rl.WindowShouldClose() {
		if !is_over(game) && empty(&game.anim.queue) {
			strat_step(&strat, &game)
		}

		rl.BeginDrawing()
		rl.DrawFPS(20, 20)
		rl.ClearBackground(rl.WHITE)
		draw_game(&game.anim)
		rl.EndDrawing()
	}
}

Strategy :: struct {
	last_unplanted: [2]int,
	looped:         bool,
}

strat_step :: proc(strat: ^Strategy, game: ^Game) {
	try_plant_and_move_forward :: proc(strat: ^Strategy, game: ^Game) {
		strat.looped = false
		strat.last_unplanted = game.robot.pos + game.robot.forward
		if is_plantable(game) do plant(game)
		if is_free_front(game) do move_forward(game)
	}
	if !is_free_back(game) && !is_free_left(game) && !is_free_right(game) {
		try_plant_and_move_forward(strat, game)
	} else if is_free_right(game) {
		turn_right(game)
		if is_free_right(game) do move_forward(game)
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
	game.anim.robot = game.robot
	game.anim.field = game.field
	game.anim.field.cells = make([dynamic]Cell, game.field.size.x * game.field.size.y)
	copy(game.anim.field.cells[:], game.field.cells[:])
	game.anim.queue = {}
	game.anim.last_tick = rl.GetTime()
	return game
}

deinit_game :: proc(g: Game) {
	delete(g.field.cells)
	delete(g.anim.field.cells)
}

draw_game :: proc(game: ^AnimGame) {
	cur_tick := rl.GetTime()

	committed := game.last_tick + STEP_DURATION < cur_tick
	if committed {
		anim, ok := pop(&game.queue)
		if ok do switch anim in anim {
		case AnimRobotMove:
			game.robot.pos = anim.pos
		case AnimRobotTurnRight:
			game.robot.forward = vec_rotate_right(game.robot.forward)
			game.robot.dir = (game.robot.dir + 1) % 4
		case AnimRobotTurnLeft:
			game.robot.forward = vec_rotate_left(game.robot.forward)
			game.robot.dir = (game.robot.dir + 3) % 4
		case AnimCell:
			cell := &game.field.cells[anim.pos.x + game.field.size.x * anim.pos.y]
			if cell^ == .DIRT && anim.next != .DIRT do game.field.n_dirts -= 1
			cell^ = anim.next
		}
		game.last_tick = cur_tick
	}
	for row in 0 ..< game.field.size.y {
		for col in 0 ..< game.field.size.x {
			color := cell_color(game.field.cells[col + game.field.size.x * row])
			xy := MARGIN.xy + CELL_SIZE * {col, row}
			rl.DrawRectangle(i32(xy.x), i32(xy.y), CELL_SIZE, CELL_SIZE, color)
		}
	}

	robot_pos := vec_cast(f64, game.robot.pos)
	robot_rot := 90 * f64(game.robot.dir)

	anim, ok := peek(&game.queue)
	if ok && !committed {
		step := clamp((cur_tick - game.last_tick) / STEP_DURATION, 0, 1)
		step = step * step * (3 - 2 * step) // smooth step

		switch anim in anim {
		case AnimRobotMove:
			next_pos := vec_cast(f64, anim.pos)
			robot_pos = step * next_pos + (1 - step) * robot_pos
		case AnimRobotTurnRight:
			robot_rot += 90 * step
		case AnimRobotTurnLeft:
			robot_rot -= 90 * step
		case AnimCell:
			color := cell_color(anim.next)
			xy := MARGIN.xy + CELL_SIZE * anim.pos
			rl.DrawRectangle(i32(xy.x), i32(xy.y), CELL_SIZE, i32(step * CELL_SIZE), color)
		}
	}

	robot_center := vec_cast(f64, MARGIN.xy) + CELL_SIZE * (robot_pos + 0.5)

	rect := rl.Rectangle {
		x      = f32(robot_center.x),
		y      = f32(robot_center.y),
		width  = ROBOT_SIZE,
		height = ROBOT_SIZE,
	}
	rl.DrawRectanglePro(rect, ROBOT_SIZE_HALF, f32(robot_rot), rl.RED)

	rect = rl.Rectangle {
		x      = f32(robot_center.x),
		y      = f32(robot_center.y),
		width  = f32(2 * WIND_SHIELD_SIZE_HALF.x),
		height = f32(2 * WIND_SHIELD_SIZE_HALF.y),
	}
	rl.DrawRectanglePro(rect, vec_cast(f32, WIND_SHIELD_OFFSET), f32(robot_rot), rl.BLUE)

	if game.field.n_dirts <= 0 {
		VICTORY: cstring : "Victory!"
		size := [2]int{0, 30}
		size.x = cast(int)rl.MeasureText(VICTORY, i32(size.y))
		text_margin :: [2]int{10, 10}
		xy := MARGIN.xy + (CELL_SIZE * FIELD_SIZE - size) / 2
		rl.DrawRectangle(
			i32(xy.x - text_margin.x),
			i32(xy.y - text_margin.y),
			i32(size.x + 2 * text_margin.x),
			i32(size.y + 2 * text_margin.y),
			{0, 0, 0, 127},
		)
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
	dir:     int,
}

Field :: struct {
	size:    [2]int,
	cells:   [dynamic]Cell,
	n_dirts: int,
}

Game :: struct {
	robot: Robot,
	field: Field,
	anim:  AnimGame,
}

AnimRobotMove :: struct {
	pos: [2]int,
}

AnimRobotTurnLeft :: struct {
}
AnimRobotTurnRight :: struct {
}

AnimCell :: struct {
	pos:  [2]int,
	next: Cell,
}

AnimStep :: union {
	AnimRobotMove,
	AnimRobotTurnLeft,
	AnimRobotTurnRight,
	AnimCell,
}

AnimGame :: struct {
	robot:     Robot,
	field:     Field,
	queue:     Queue(AnimStep, 10),
	last_tick: f64,
}

move_forward :: proc(game: ^Game) {
	game.robot.pos += game.robot.forward
	assert(push(&game.anim.queue, AnimRobotMove{pos = game.robot.pos}))
	_verify_state(game)
}

move_backward :: proc(game: ^Game) {
	game.robot.pos -= game.robot.forward
	assert(push(&game.anim.queue, AnimRobotMove{pos = game.robot.pos}))
	_verify_state(game)
}

turn_right :: proc(game: ^Game) {
	game.robot.forward = vec_rotate_right(game.robot.forward)
	game.robot.dir += 1
	assert(push(&game.anim.queue, AnimRobotTurnRight{}))
	_verify_state(game)
}

turn_left :: proc(game: ^Game) {
	game.robot.forward = vec_rotate_left(game.robot.forward)
	game.robot.dir -= 1
	assert(push(&game.anim.queue, AnimRobotTurnLeft{}))
	_verify_state(game)
}

plant :: proc(game: ^Game) {
	_verify_state(game)
	pos := game.robot.pos
	size := game.field.size
	cell := &game.field.cells[pos.x + size.x * pos.y]
	assert(push(&game.anim.queue, AnimCell{pos = pos, next = .FLOWERS}))
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

is_over :: proc(game: Game) -> bool {
	return game.field.n_dirts <= 0
}

_is_free :: proc(game: ^Game, off: [2]int) -> bool {
	cell := _get_cell(game, off) or_return
	return cell == .EMPTY || cell == .DIRT
}

_get_cell :: proc(game: ^Game, off: [2]int) -> (cell: Cell, ok: bool) {
	pos := game.robot.pos
	forward := game.robot.forward
	right := vec_rotate_right(forward)
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

cell_color :: proc(cell: Cell) -> (color: rl.Color) {
	switch cell {
	case .EMPTY:
		color = rl.BEIGE
	case .DIRT:
		color = rl.BROWN
	case .FLOWERS:
		color = rl.GREEN
	case .WALL:
		color = rl.MAROON
	}
	return
}

vec_rotate_right_int :: proc(v: [2]int) -> [2]int {
	return {-v.y, v.x}
}

vec_rotate_left_int :: proc(v: [2]int) -> [2]int {
	return {v.y, -v.x}
}

vec_rotate_right_f64 :: proc(v: [2]f64) -> [2]f64 {
	return {-v.y, v.x}
}

vec_rotate_left_f64 :: proc(v: [2]f64) -> [2]f64 {
	return {v.y, -v.x}
}

vec_rotate_right :: proc {
	vec_rotate_right_int,
	vec_rotate_right_f64,
}

vec_rotate_left :: proc {
	vec_rotate_left_int,
	vec_rotate_left_f64,
}

vec_cast :: proc($Out: typeid, vin: [$N]$In) -> (vout: [N]Out) {
	for i in 0 ..< N {
		vout[i] = Out(vin[i])
	}
	return
}
