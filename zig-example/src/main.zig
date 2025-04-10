const std = @import("std");
const rl = @cImport({
    @cInclude("raylib.h");
    @cInclude("raymath.h");
});

const WIDTH = 500;
const HEIGHT = 400;
const FPS = 20;
const RECT_SIZE = 30;

pub fn main() !void {
    rl.InitWindow(WIDTH, HEIGHT, "Hello, world!");

    rl.SetTargetFPS(FPS);
    var rect_pos: @Vector(2, i32) = .{ 0, 0 };
    var rect_speed: @Vector(2, i32) = .{ 4, 4 };
    var rect_color: rl.Color = .{ .r = 255, .g = 0, .b = 0, .a = 255 };
    var text_color: rl.Color = .{ .r = 0, .g = 255, .b = 0, .a = 255 };
    var buf: [1000]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buf);
    const alloc = fba.allocator();
    var bg_text = std.ArrayList(u8).init(alloc);
    defer bg_text.deinit();
    try bg_text.appendSlice("Hello, world!");
    var prng = std.Random.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.posix.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });
    const rand = prng.random();
    var i: u8 = 0;
    var paused = false;
    var is_renaming = false;
    while (!rl.WindowShouldClose()) {
        if (is_renaming) {
            const key = rl.GetKeyPressed();
            if (key == rl.KEY_ENTER) {
                is_renaming = false;
            } else if (key >= rl.KEY_A and key <= rl.KEY_Z or key == rl.KEY_SPACE) {
                if (bg_text.items.len < 99)
                    try bg_text.append(@intCast(if (key >= rl.KEY_A and key <= rl.KEY_Z) key + 32 else key)); // key is ascii
            } else if (key == rl.KEY_BACKSPACE)
                _ = bg_text.pop();
        } else {
            if (rl.IsKeyPressed(rl.KEY_SPACE)) {
                paused = !paused;
            }

            if ((rl.IsKeyDown(rl.KEY_LEFT) or rl.IsKeyDown(rl.KEY_A)) and rect_pos[0] > 0) {
                rect_pos[0] -= 5;
            }
            if ((rl.IsKeyDown(rl.KEY_RIGHT) or rl.IsKeyDown(rl.KEY_D)) and rect_pos[0] + RECT_SIZE < WIDTH) {
                rect_pos[0] += 5;
            }
            if ((rl.IsKeyDown(rl.KEY_DOWN) or rl.IsKeyDown(rl.KEY_S)) and rect_pos[1] + RECT_SIZE < HEIGHT) {
                rect_pos[1] += 5;
            }
            if ((rl.IsKeyDown(rl.KEY_UP) or rl.IsKeyDown(rl.KEY_W)) and rect_pos[1] > 0) {
                rect_pos[1] -= 5;
            }

            if (rl.IsKeyPressed(rl.KEY_R)) {
                is_renaming = true;
            }
        }

        rl.BeginDrawing();

        rl.ClearBackground(rl.BLACK);
        if (paused) {
            const text = "Paused";
            const w = rl.MeasureText(text, 50);
            rl.DrawText(text, @divFloor(WIDTH - w, 2), HEIGHT / 2 - 25, 50, text_color);
        } else {
            try bg_text.append(0);
            const w = rl.MeasureText(bg_text.items.ptr, 50);
            rl.DrawText(bg_text.items.ptr, @divFloor(WIDTH - w, 2), HEIGHT / 2 - 25, 50, text_color);
            _ = bg_text.pop();
        }

        rl.DrawRectangle(rect_pos[0] - 1, rect_pos[1] - 1, RECT_SIZE + 2, RECT_SIZE + 2, rl.WHITE);
        rl.DrawRectangle(rect_pos[0], rect_pos[1], RECT_SIZE, RECT_SIZE, rect_color);

        if (paused) {
            rl.EndDrawing();
            continue;
        }

        if (i == 2) {
            text_color.r = rand.int(u8);
            text_color.g = rand.int(u8);
            text_color.b = rand.int(u8);
            rect_color.r = rand.int(u8);
            rect_color.g = rand.int(u8);
            rect_color.b = rand.int(u8);
        }
        i = (i + 1) % 3;

        rect_pos[0] += rect_speed[0];
        rect_pos[1] += rect_speed[1];

        if (rect_pos[0] + RECT_SIZE >= WIDTH) rect_speed[0] *= -1;
        if (rect_pos[0] < 0) rect_speed[0] *= -1;
        if (rect_pos[1] + RECT_SIZE >= HEIGHT) rect_speed[1] *= -1;
        if (rect_pos[1] < 0) rect_speed[1] *= -1;

        rl.EndDrawing();
    }
}
