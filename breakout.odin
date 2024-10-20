package breakout

import fmt "core:fmt"
import math "core:math"
import linalg "core:math/linalg"
import rl "vendor:raylib"

SCREEN_SIZE :: 320
WINDOW_SIZE :: 640
PADDLE_WIDTH :: 50
PADDLE_HEIGHT :: 6
PADDLE_Y :: 260
PADDLE_SPEED :: 200
BALL_SPEED :: 260
BALL_RADIUS :: 4
BALL_START_Y :: 160
NUM_BLOCKS_X :: 10
NUM_BLOCKS_Y :: 8
BLOCK_WIDTH :: 28
BLOCK_HEIGHT :: 10

Blocks :: #type [NUM_BLOCKS_X][NUM_BLOCKS_Y]bool

BlockColor :: enum {
	Yellow,
	Green,
	Purple,
	Red,
}

Item :: enum {
	Block,
	Paddle,
}

row_colors := [NUM_BLOCKS_Y]BlockColor {
	.Red,
	.Red,
	.Purple,
	.Purple,
	.Green,
	.Green,
	.Yellow,
	.Yellow,
}

block_color_values := [BlockColor]rl.Color {
	.Yellow = {253, 249, 150, 255},
	.Green  = {180, 245, 190, 255},
	.Purple = {170, 120, 250, 255},
	.Red    = {250, 90, 85, 255},
}

block_score := [BlockColor]int {
	.Yellow = 10,
	.Green  = 20,
	.Purple = 30,
	.Red    = 40,
}

State :: struct {
	paddle:  rl.Rectangle,
	ball:    struct {
		pos:       rl.Vector2,
		direction: rl.Vector2,
	},
	blocks:  [NUM_BLOCKS_X][NUM_BLOCKS_Y]bool,
	score:   int,
	started: bool,
}

state_init :: proc() -> State {
	return State {
		paddle = {SCREEN_SIZE / 2 - PADDLE_WIDTH / 2, PADDLE_Y, PADDLE_WIDTH, PADDLE_HEIGHT},
		ball = {pos = {SCREEN_SIZE / 2, BALL_START_Y}, direction = {0, 0}},
		started = false,
		blocks = init_blocks(),
	}
}

restart :: proc(state: ^State) {
	state.paddle = {SCREEN_SIZE / 2 - PADDLE_WIDTH / 2, PADDLE_Y, PADDLE_WIDTH, PADDLE_HEIGHT}
	state.ball = {
		pos       = {SCREEN_SIZE / 2, BALL_START_Y},
		direction = {0, 0},
	}
	state.blocks = init_blocks()
	state.started = false
	state.score = 0
}

init_blocks :: proc() -> Blocks {
	blocks: [NUM_BLOCKS_X][NUM_BLOCKS_Y]bool
	for x in 0 ..< NUM_BLOCKS_X {
		for y in 0 ..< NUM_BLOCKS_Y {
			blocks[x][y] = true
		}
	}
	return blocks
}

paddle_velocity :: proc() -> f32 {
	velocity: f32

	if rl.IsKeyDown(.LEFT) {
		velocity -= PADDLE_SPEED
	}
	if rl.IsKeyDown(.RIGHT) {
		velocity += PADDLE_SPEED
	}

	return velocity
}


get_dt :: proc(state: ^State) -> f32 {
	return rl.GetFrameTime()
}

start_game :: proc(state: ^State) {
	paddle_middle := rl.Vector2{state.paddle.x + PADDLE_WIDTH / 2, PADDLE_Y}
	ball_to_middle := paddle_middle - state.ball.pos
	state.ball.direction = linalg.normalize0(ball_to_middle)
	state.started = true
}

reflect :: proc(dir, normal: rl.Vector2) -> rl.Vector2 {
	return linalg.normalize(linalg.reflect(dir, linalg.normalize(normal)))
}

is_normalized :: proc(item: rl.Vector2) -> bool {
	TOLERANCE :: 0.01
	normalized := linalg.normalize0(item)
	if math.abs(item.x - normalized.x) > TOLERANCE {return false}
	if math.abs(item.y - normalized.y) > TOLERANCE {return false}
	return true
}

move_paddle :: proc(state: ^State, dt: f32) {
	state.paddle.x += paddle_velocity() * dt
	state.paddle.x = clamp(state.paddle.x, 0, SCREEN_SIZE - PADDLE_WIDTH)
}

get_block_rect :: proc(x, y: int) -> rl.Rectangle {
	return {
		x = f32(20 + x * (BLOCK_WIDTH)),
		y = f32(40 + y * (BLOCK_HEIGHT)),
		width = BLOCK_WIDTH,
		height = BLOCK_HEIGHT,
	}
}

bounce_on_rect :: proc(
	state: ^State,
	previous_ball_pos: rl.Vector2,
	rect: rl.Rectangle,
	item: Item,
) {
	if rl.CheckCollisionCircleRec(state.ball.pos, BALL_RADIUS, rect) {
		normal: rl.Vector2

		// Collides with top of rect
		if previous_ball_pos.y < rect.y + rect.height {
			skew: f32
			if item == Item.Paddle {
				distance_from_center := state.ball.pos.x - (rect.x + rect.width / 2)
				skew = distance_from_center / rect.width * 0.5
			}
			normal += {skew, -1}
			state.ball.pos.y = rect.y - BALL_RADIUS
		}

		// Collides with bottom of rect
		if previous_ball_pos.y > rect.y + rect.height {
			normal += {0, 1}
			state.ball.pos.y = rect.y + rect.height + BALL_RADIUS
		}

		// Collides with left side of rect
		if previous_ball_pos.x < rect.x {
			normal += {-1, 0}
		}

		// Collides with right side of rect
		if previous_ball_pos.x > rect.x + rect.width {
			normal += {1, 0}
		}

		if normal != 0 {
			state.ball.direction = reflect(state.ball.direction, normal)
		}
	}
}

handle_paddle_collision :: proc(state: ^State, previous_ball_pos: rl.Vector2) {
	bounce_on_rect(state, previous_ball_pos, state.paddle, Item.Paddle)
}

handle_screen_collision :: proc(state: ^State, previous_ball_pos: rl.Vector2) {
	// Collides with right side of screen
	if state.ball.pos.x + BALL_RADIUS > SCREEN_SIZE {
		state.ball.pos.x = SCREEN_SIZE - BALL_RADIUS
		state.ball.direction = reflect(state.ball.direction, {1, 0})
	}

	// Collides with left side of screen
	if state.ball.pos.x - BALL_RADIUS < 0 {
		state.ball.pos.x = BALL_RADIUS
		state.ball.direction = reflect(state.ball.direction, {-1, 0})
	}

	// Collides with top of screen
	if state.ball.pos.y - BALL_RADIUS < 0 {
		state.ball.pos.y = BALL_RADIUS
		state.ball.direction = reflect(state.ball.direction, {0, 1})
	}

	// Goes off the bottom of the screen
	if state.ball.pos.y + BALL_RADIUS > SCREEN_SIZE {
		restart(state)
	}
}


handle_block_collision :: proc(state: ^State, previous_ball_pos: rl.Vector2) {
	for x in 0 ..< NUM_BLOCKS_X {
		for y in 0 ..< NUM_BLOCKS_Y {
			if state.blocks[x][y] == false do continue
			block := get_block_rect(x, y)
			if rl.CheckCollisionCircleRec(state.ball.pos, BALL_RADIUS, block) {
				state.blocks[x][y] = false
				state.score += block_score[row_colors[y]]
				bounce_on_rect(state, previous_ball_pos, block, Item.Block)
				return
			}
		}
	}
}

move_ball :: proc(state: ^State, dt: f32) {
	if !state.started {
		state.ball.pos = {
			SCREEN_SIZE / 2 + f32(math.cos(rl.GetTime()) * SCREEN_SIZE / 4),
			BALL_START_Y,
		}
		return
	}

	previous_ball_pos := state.ball.pos
	assert(is_normalized(state.ball.direction))
	state.ball.pos += state.ball.direction * BALL_SPEED * dt

	handle_paddle_collision(state, previous_ball_pos)
	handle_screen_collision(state, previous_ball_pos)
	handle_block_collision(state, previous_ball_pos)

	assert(is_normalized(state.ball.direction))
}

draw_blocks :: proc(state: ^State) {
	for x in 0 ..< NUM_BLOCKS_X {
		for y in 0 ..< NUM_BLOCKS_Y {
			if state.blocks[x][y] == false do continue
			rect := get_block_rect(x, y)
			// Fill
			rl.DrawRectangleRec(rect, block_color_values[row_colors[y]])

			// Border
			top_left := rl.Vector2{rect.x, rect.y}
			top_right := rl.Vector2{rect.x + rect.width, rect.y}
			bottom_left := rl.Vector2{rect.x, rect.y + rect.height}
			bottom_right := rl.Vector2{rect.x + rect.width, rect.y + rect.height}
			rl.DrawLineEx(top_left, top_right, 1, {255, 255, 150, 100})
			rl.DrawLineEx(top_right, bottom_right, 1, {255, 255, 150, 100})
			rl.DrawLineEx(bottom_right, bottom_left, 1, {255, 255, 150, 100})
			rl.DrawLineEx(bottom_left, top_left, 1, {255, 255, 150, 100})
		}
	}
}

draw_score :: proc(state: ^State) {
	rl.DrawText(fmt.ctprint("Score: ", state.score), 5, 5, 10, rl.WHITE)
}

draw :: proc(state: ^State) {
	rl.BeginDrawing()
	rl.ClearBackground({150, 190, 220, 255})

	camera := rl.Camera2D {
		zoom = f32(rl.GetScreenHeight() / SCREEN_SIZE),
	}
	rl.BeginMode2D(camera)

	rl.DrawRectangleRec(state.paddle, {50, 150, 90, 255})
	rl.DrawCircleV(state.ball.pos, BALL_RADIUS, {200, 90, 20, 255})
	draw_blocks(state)
	draw_score(state)
	rl.EndMode2D()
	rl.EndDrawing()
}

main :: proc() {
	rl.SetConfigFlags({.VSYNC_HINT})
	rl.InitWindow(WINDOW_SIZE, WINDOW_SIZE, "Breakout")
	rl.SetTargetFPS(500)

	state := state_init()

	restart(&state)

	for !rl.WindowShouldClose() {
		if !state.started && rl.IsKeyPressed(.SPACE) {
			start_game(&state)
		}

		dt := get_dt(&state)
		move_paddle(&state, dt)
		move_ball(&state, dt)

		draw(&state)
		free_all(context.temp_allocator)
	}
	rl.CloseWindow()
}
