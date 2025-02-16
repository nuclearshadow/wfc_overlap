package wfc_overlap

import rl "vendor:raylib"

Tile :: struct {
    pixels: [TILE_SIZE * TILE_SIZE]rl.Color,
    adjacencies: [Direction][dynamic]^Tile,
    frequency: int
}

tile_from_image :: proc(x, y: int, image_pixels: [^]rl.Color, image_width, image_height: int) -> Tile {
    tile: Tile = { frequency = 1 }

    for i in 0..<TILE_SIZE {
        for j in 0..<TILE_SIZE {
            ix := (x + j) % image_width
            iy := (y + i) % image_height
            tile.pixels[i * TILE_SIZE + j] = image_pixels[iy * image_width + ix]
        }
    }
    return tile
}

make_tiles :: proc(image: rl.Image) -> []Tile {
    overlaps :: proc(tile1, tile2: ^Tile, offset: [2]int) -> bool {
        for i in 0 ..< TILE_SIZE - abs(offset.y) {
            for j in 0 ..< TILE_SIZE  - abs(offset.x) {
                t1_i := i + max(0, offset.y)
                t1_j := j + max(0, offset.x)
                t2_i := i - min(0, offset.y)
                t2_j := j - min(0, offset.x)
                if tile1.pixels[t1_i * TILE_SIZE + t1_j] != tile2.pixels[t2_i * TILE_SIZE + t2_j] {
                    return false
                }
            }
        }
        return true
    }
    
    tiles: [dynamic]Tile
    image_pixels := rl.LoadImageColors(image)
    defer rl.UnloadImageColors(image_pixels)

    outer: for i in 0..< image.width * image.height {
        tile := tile_from_image(int(i % image.width), int(i / image.width), image_pixels, auto_cast image.width, auto_cast image.height)
        for &other in tiles {
            if tile.pixels == other.pixels {
                other.frequency += 1
                continue outer
            }
        }
        append(&tiles, tile)
    }

    for &tile in tiles {
        for &other in tiles {
            for dir in Direction {
                if overlaps(&tile, &other, dir_vecs[dir]) {
                    append(&tile.adjacencies[dir], &other)
                }
            }
        }
    }

    return tiles[:]
}

delete_tiles :: proc(tiles: []Tile) {
    for &tile in tiles {
        for dir in Direction {
            delete(tile.adjacencies[dir])
        }
    }
    delete(tiles)
}

draw_tile :: proc(tile: Tile, x, y: i32) {
    for i in 0..<i32(TILE_SIZE) {
        for j in 0..<i32(TILE_SIZE) {
            rl.DrawRectangle(x + j * PIXEL_SCALE, y + i * PIXEL_SCALE, PIXEL_SCALE, PIXEL_SCALE, tile.pixels[i * TILE_SIZE + j])
        }
    }
    rl.DrawRectangleLines(x, y, TILE_SIZE * PIXEL_SCALE, TILE_SIZE * PIXEL_SCALE, rl.WHITE)
}
