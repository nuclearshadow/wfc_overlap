package wfc_overlap

import rl "vendor:raylib"
import "core:fmt"
import "core:strings"

PIXEL_SCALE :: 10
OUTPUT_WIDTH :: 40
OUTPUT_HEIGHT :: 40

TILE_SIZE :: 3

Tile :: struct {
    pixels: [TILE_SIZE * TILE_SIZE]rl.Color,
    adjacencies: []^Tile,
}

tile_from_image :: proc(x, y: int, image_pixels: [^]rl.Color, image_width, image_height: int) -> Tile {
    tile: Tile = {}

    for i in 0..<TILE_SIZE {
        for j in 0..<TILE_SIZE {
            ix := (x + j) % image_width
            iy := (y + i) % image_height
            fmt.printf("(%d, %d) ", ix, iy)
            tile.pixels[i * TILE_SIZE + j] = image_pixels[iy * image_width + ix]
        }
    }
    fmt.println()
    return tile
}

create_tiles :: proc(image: rl.Image) -> []Tile {
    tiles: []Tile = make([]Tile, image.width * image.height)
    image_pixels := rl.LoadImageColors(image)
    defer rl.UnloadImageColors(image_pixels)

    for i in 0..<len(tiles) {
        tiles[i] = tile_from_image(i % auto_cast image.width, i / auto_cast image.width, image_pixels, auto_cast image.width, auto_cast image.height)
    }

    return tiles
}

delete_tiles :: proc(tiles: []Tile) {
    delete(tiles)
}

draw_tile :: proc(tile: Tile, x, y: i32) {
    for i in 0..<i32(TILE_SIZE) {
        for j in 0..<i32(TILE_SIZE) {
            rl.DrawRectangle(x + j * PIXEL_SCALE, y + i * PIXEL_SCALE, PIXEL_SCALE, PIXEL_SCALE, tile.pixels[i * TILE_SIZE + j])
        }
    }
}

main :: proc() {
    using rl
    InitWindow(800, 600, "Wave Function Collapse")
    defer CloseWindow()

    image := LoadImage("samples/City.png")
    defer UnloadImage(image)
    image_texture := LoadTextureFromImage(image)
    defer UnloadTexture(image_texture)
    image_pixels := LoadImageColors(image)
    defer UnloadImageColors(image_pixels)

    tiles := create_tiles(image)
    defer delete_tiles(tiles)

    for !WindowShouldClose() {
        BeginDrawing()
        ClearBackground(BLACK)

        PADDING :: 10

        sample_source_rect: Rectangle = { 0, 0, f32(image.width), f32(image.height) }
        sample_dest_rect: Rectangle = { PADDING, PADDING, sample_source_rect.width * PIXEL_SCALE, sample_source_rect.height * PIXEL_SCALE }
        DrawTexturePro(image_texture, sample_source_rect, sample_dest_rect, {0, 0}, 0, WHITE)
        DrawRectangleLinesEx(sample_dest_rect, 1, WHITE)

        TILE_ORIGIN :: [2]f32{ 100, PADDING }

        for i in 0..<image.width {
            for j in 0..<image.height {
                TILES_OFFSET :: 200
                draw_tile(tiles[i * image.width + j], j * (TILE_SIZE * PIXEL_SCALE + PADDING) + TILES_OFFSET + PADDING, i * (TILE_SIZE * PIXEL_SCALE + PADDING) + PADDING)
                DrawRectangleLines(j * (TILE_SIZE * PIXEL_SCALE + PADDING) + TILES_OFFSET + PADDING, i * (TILE_SIZE * PIXEL_SCALE + PADDING) + PADDING, TILE_SIZE * PIXEL_SCALE, TILE_SIZE * PIXEL_SCALE, WHITE)
            }
        }

        EndDrawing()
    }
}
