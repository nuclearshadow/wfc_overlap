package wfc_overlap

import rl "vendor:raylib"
import "core:fmt"
import "core:strings"
import "core:slice"
import "core:math"
import "core:math/rand"
import "core:time"

PIXEL_SCALE :: 10
OUTPUT_WIDTH :: 50
OUTPUT_HEIGHT :: 50

TILE_SIZE :: 3

Direction :: enum {
    UP,
    RIGHT,
    DOWN,
    LEFT,
}

dir_vecs := [Direction][2]int{
    .UP    = {  0, -1 },
    .RIGHT = {  1,  0 },
    .DOWN  = {  0,  1 },
    .LEFT  = { -1,  0 },
}

Cell :: struct {
    possible_tiles: [dynamic]^Tile,
    collapsed: bool,
    visited: bool,
}

Board :: struct {
    width, height: int,
    cells: []Cell
}

make_board :: proc(tiles: []Tile, width, height: int) -> (board: Board) {
    board.cells = make([]Cell, width * height)
    board.width = width
    board.height = height
    for &cell in board.cells {
        using cell
        possible_tiles = make(type_of(possible_tiles), len(tiles))
        for &tile, i in tiles {
            possible_tiles[i] = &tile
        }
    }
    return
}

delete_board :: proc(board: Board) {
    for &cell in board.cells {
        delete(cell.possible_tiles)
    }
    delete(board.cells)
}

cell_entropy :: proc(cell: Cell) -> f32 {
    total_freq: f32 = 0
    freq_log_sum: f32 = 0
    for tile in cell.possible_tiles {
        freq: f32 = f32(tile.frequency)
        total_freq += freq
        freq_log_sum += freq * math.log2(freq)
    }
    return math.log2(total_freq) - freq_log_sum / total_freq
}

cell_collapse :: proc(cell: ^Cell) {
    total_freq := 0
    for tile in cell.possible_tiles {
        total_freq += tile.frequency
    }
    n := rand.int_max(total_freq)
    chosen: ^Tile
    for tile in cell.possible_tiles {
        if n - tile.frequency < 0 {
            chosen = tile
            break
        }
        n -= tile.frequency
    }
    clear(&cell.possible_tiles)
    append(&cell.possible_tiles, chosen)
}

cell_reduce_entropy :: proc(cell: ^Cell, from_adj: []^Tile) {
    if cell.collapsed || cell.visited { return }
    #reverse for tile, i in cell.possible_tiles {
        if !slice.contains(from_adj, tile) {
            unordered_remove(&cell.possible_tiles, i)
        }
    }
}

cells_propogate :: proc(board: Board, x, y, depth: int) {
    MAX_DEPTH :: 10
    @(static) tiles: [dynamic]^Tile
    if depth > MAX_DEPTH { return }
    cell := &board.cells[y * board.width + x]
    if cell.collapsed || cell.visited { return }
    cell.visited = true
    // fmt.println(x, y)
    for dir in Direction {
        cx := x + dir_vecs[dir].x
        cy := y + dir_vecs[dir].y
        if cx < 0 || cy < 0 || cx >= board.width || cy >= board.height { continue }
        clear(&tiles)
        for tile in cell.possible_tiles {
            append(&tiles, ..tile.adjacencies[dir][:])
        }
        cell_reduce_entropy(&board.cells[cy * board.width + cx], tiles[:])
        // cells_propogate(board, cx, cy, depth + 1)
    }
    for dir in Direction {
        cx := x + dir_vecs[dir].x
        cy := y + dir_vecs[dir].y
        if cx < 0 || cy < 0 || cx >= board.width || cy >= board.height { continue }
        cells_propogate(board, cx, cy, depth + 1)
    }
}

wave_function_collapse :: proc(board: Board) -> bool {
    min_entropy_cell: ^Cell
    found_cell := false
    min_cell_index := -1
    for &cell, i in board.cells {
        cell.visited = false
        if cell.collapsed {
            continue
        }
        if !found_cell {
            min_entropy_cell = &cell
            min_cell_index = i
            found_cell = true
        } else if cell_entropy(cell) < cell_entropy(min_entropy_cell^) {
            min_entropy_cell = &cell
            min_cell_index = i
        }
    }
    if !found_cell {
        return true
    }
    // fmt.println("before collapse", min_entropy_cell)
    if len(min_entropy_cell.possible_tiles) == 0 {
        return false
    }
    cell_collapse(min_entropy_cell)
    // fmt.println("after collapse", min_entropy_cell)
    cells_propogate(board, min_cell_index % board.width, min_cell_index / board.width, 0)
    // fmt.println("after propogate", min_entropy_cell)
    min_entropy_cell.collapsed = true
    return true
}

draw_board :: proc(board: Board, x, y: i32) {
    for i in 0..<board.height {
        for j in 0..<board.width {
            cell := board.cells[i * board.width + j]
            if cell.collapsed {
                // fmt.println(cell)
                rl.DrawRectangle(x + PIXEL_SCALE*i32(j), 
                    y + PIXEL_SCALE*i32(i),
                    PIXEL_SCALE,
                    PIXEL_SCALE,
                    cell.possible_tiles[0].pixels[5],
                )
            }
        }
    }
}

main :: proc() {
    rand.reset(cast(u64)time.to_unix_nanoseconds(time.now()))
    // rand.reset(9)
    using rl
    InitWindow(800, 600, "Wave Function Collapse")
    defer CloseWindow()
    SetTargetFPS(60)
    SetWindowState(ConfigFlags{ .WINDOW_RESIZABLE })

    image := LoadImage("samples/Flowers.png")
    defer UnloadImage(image)
    image_texture := LoadTextureFromImage(image)
    defer UnloadTexture(image_texture)
    
    tiles := make_tiles(image)
    defer delete_tiles(tiles)

    // for tile, i in tiles {
    //     fmt.println("Tile", i)
    //     fmt.println("Pixels", tile.pixels)
    //     fmt.println("Frequency", tile.frequency)
    //     fmt.println("Adj", len(tile.adjacencies))
    // }

    board := make_board(tiles, OUTPUT_WIDTH, OUTPUT_HEIGHT)
    defer delete_board(board)

    for !WindowShouldClose() {
        window_width := GetRenderWidth()
        window_height := GetRenderHeight()
        if !wave_function_collapse(board) {
            delete_board(board)
            board = make_board(tiles, OUTPUT_WIDTH, OUTPUT_HEIGHT)
        }
        collapsed := slice.reduce(board.cells, 0, proc(count: int, cell: Cell) -> int {
            return count + 1 if cell.collapsed else count
        })
        // fmt.println("Collapsed count:", collapsed)

        BeginDrawing()
        ClearBackground(BLACK)

        PADDING :: 10

        sample_source_rect: Rectangle = { 0, 0, f32(image.width), f32(image.height) }
        sample_dest_rect: Rectangle = { PADDING, PADDING, sample_source_rect.width * PIXEL_SCALE, sample_source_rect.height * PIXEL_SCALE }
        DrawTexturePro(image_texture, sample_source_rect, sample_dest_rect, {0, 0}, 0, WHITE)
        DrawRectangleLinesEx(sample_dest_rect, 1, WHITE)

        tile_x: i32 = PADDING
        tile_y: i32 = cast(i32)sample_dest_rect.height + PADDING*2
        for tile in tiles {
            draw_tile(tile, tile_x, tile_y)
            tile_y += TILE_SIZE*PIXEL_SCALE + PADDING
            if tile_y > window_height - (TILE_SIZE*PIXEL_SCALE + PADDING) {
                tile_y = cast(i32)sample_dest_rect.height + PADDING*2
                tile_x += TILE_SIZE*PIXEL_SCALE + PADDING
            }
        }

        output_x := window_width - (OUTPUT_WIDTH * PIXEL_SCALE) - PADDING
        DrawRectangle(output_x, PADDING, OUTPUT_WIDTH * PIXEL_SCALE, OUTPUT_HEIGHT * PIXEL_SCALE, BLACK)
        draw_board(board, output_x, PADDING)
        DrawRectangleLines(output_x, PADDING, OUTPUT_WIDTH * PIXEL_SCALE, OUTPUT_HEIGHT * PIXEL_SCALE, WHITE)

        // Debug Drawing
        // ------------------------------------------------------------------------------------------------------
        // TILES_OFFSET :: 200
        // INDEX :: 5
        // draw_tile(tiles[INDEX], TILES_OFFSET, PADDING)
        // for dir, i in Direction {
        //     for adj, j in tiles[INDEX].adjacencies[dir] {
        //         draw_tile(adj^, TILES_OFFSET + (PIXEL_SCALE*TILE_SIZE + PADDING) * i32(j), 2*PADDING + PIXEL_SCALE*TILE_SIZE + (PIXEL_SCALE*TILE_SIZE + PADDING)*i32(i))
        //     }
        // }
        
        // for i in 0..<image.width {
        //     for j in 0..<image.height {
        //         draw_tile(tiles[i * image.width + j], j * (TILE_SIZE * PIXEL_SCALE + PADDING) + TILES_OFFSET + PADDING, i * (TILE_SIZE * PIXEL_SCALE + PADDING) + PADDING)
        //     }
        // }
        // ------------------------------------------------------------------------------------------------------

        EndDrawing()
    }
}
