const std = @import("std");
const testing = std.testing;

const flx = @import("root.zig");
const util = @import("util.zig");

/// XXX: Just a test
fn testArray() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // TODO: ..
    var it: flx.LInt = std.ArrayList(i32).init(allocator);
    std.debug.print("{}\n", .{@TypeOf(it)});
    defer it.deinit();

    try it.append(1);
    try it.append(2);

    it.items[1] = 99;

    for (it.items) |item| {
        std.debug.print("{d}\n", .{item});
    }

    std.debug.print("{d} {d}\n", .{ it.items[0], it.items[1] });
    std.debug.print("len: {d}\n", .{it.items.len});
}

/// XXX: Just a test
fn testHashmap() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var my_hash_map = flx.IntLInt.init(allocator);
    defer my_hash_map.deinit();

    var arr = flx.LInt.init(allocator);
    defer arr.deinit();

    try my_hash_map.put(1, arr);
    try my_hash_map.put(1, arr);

    std.debug.print("{?}", .{my_hash_map.get(0)});
}

/// XXX: Just a test
fn testArrArr() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var inner: flx.LInt = std.ArrayList(i32).init(allocator);
    defer inner.deinit();
    try inner.append(1);
    std.debug.print("{?}", .{inner.items[0]});
}

/// XXX: Just a test
fn testForTimes() !void {
    const len = 10;
    for (0..len) |i| {
        std.debug.print("{d}", .{i});
    }
}

/// XXX: Just a test
fn testForStr() !void {
    for ("abcd") |i| {
        std.debug.print("{c}", .{i});
    }
}

/// XXX: Just a test
fn testClone(allocator: std.mem.Allocator) !void {
    var inner = flx.LInt.init(allocator);
    try inner.append(-1);
    try inner.append(0);

    var group_alist = flx.LLInt.init(allocator);
    try group_alist.append(inner);

    for (group_alist.items) |group| {
        var cddr_group = group.clone() catch null;

        std.debug.print("{any}", .{cddr_group});

        const val: usize = 0;
        _ = cddr_group.?.orderedRemove(val);

        //cddr_group.?.orderedRemove();
        //std.debug.print("{!}", .{cddr_group});
    }
}

/// XXX: Just a test
fn testNested(allocator: std.mem.Allocator) !void {
    var str_info = flx.IntLInt.init(allocator);
    try util.dictInsert(allocator, &str_info, 0, 10);
    try util.dictInsert(allocator, &str_info, 0, 99);
    try util.dictInsert(allocator, &str_info, 1, 7);
    try util.dictInsert(allocator, &str_info, 1, 55);
    try util.dictInsert(allocator, &str_info, 1, 4);
    try util.dictInsert(allocator, &str_info, 1, 12);
    //try util.dictInsert(allocator, &str_info, 0, 99);

    std.debug.print("{any}\n", .{str_info.getPtr(0).?.*});
    std.debug.print("{?}\n", .{str_info.count()});
    std.debug.print("{?}\n", .{str_info.getPtr(0).?.*.items.len});
    std.debug.print("{?}\n", .{str_info.getPtr(1).?.*.items.len});

    // for (0..2) |i| {
    //     const arr = str_info.getPtr(@intCast(i)).?.*.*;
    //     const len: usize = arr.items.len;
    //     std.debug.print("----- {?}: {?}\n", .{ i, len });
    //     std.debug.print("  ", .{});
    //
    //     for (arr.items) |j| {
    //         std.debug.print("{?} ", .{ j });
    //     }
    //     std.debug.print("\n", .{});
    // }
}

/// XXX: Just a test
fn testCreate(allocator: std.mem.Allocator) !void {
    var lst1 = flx.LInt.init(allocator);
    var lst2 = flx.LInt.init(allocator);
    try lst1.append(1);
    try lst1.append(1);
    try lst1.append(1);
    try lst2.append(2);
    try lst2.append(2);
    std.debug.print("{d}\n", .{lst1.items.len});
    std.debug.print("{d}\n", .{lst2.items.len});
    std.debug.print("{*}\n", .{&lst1});
    std.debug.print("{*}\n", .{&lst2});
}

/// XXX: Just a test
fn repMem(allocator: std.mem.Allocator) !void {
    var indices = flx.LInt.init(allocator);
    try indices.append(0);
    const result = flx.Result.init(indices, 0, 0);
    result.deinit();
}

/// XXX: Just a test
fn testScore(allocator: std.mem.Allocator) !void {
    const result: ?flx.Result = flx.score(allocator, "switch-to-buffer", "stb");
    if (result != null) {
        std.debug.print("{d}\n", .{result.?.score});
        for (result.?.indices.items) |indice| {
            std.debug.print("{d} ", .{indice});
        }
        std.debug.print("\n", .{});
    }

    defer result.?.deinit();
}

/// Program Entry
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        //fail test; can't try in defer as defer is executed after we return
        if (deinit_status == .leak) {
            testing.expect(false) catch @panic("TEST FAIL");
        }
    }

    //try testArray();
    //try testHashmap();
    //try testArrArr();
    //try testForTimes();
    //try testForStr();
    //try testClone(allocator);
    //try testNested(allocator);
    //try testCreate(allocator);
    //try repMem(allocator);
    try testScore(allocator);
}

test "switch-to-buffer stb" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        //fail test; can't try in defer as defer is executed after we return
        if (deinit_status == .leak) {
            testing.expect(false) catch @panic("TEST FAIL");
        }
    }

    const result: ?flx.Result = flx.score(allocator, "switch-to-buffer", "stb");
    defer result.?.deinit();

    try testing.expect(result.?.score == 237);
}

test "switch-to-buffer z" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        //fail test; can't try in defer as defer is executed after we return
        if (deinit_status == .leak) {
            testing.expect(false) catch @panic("TEST FAIL");
        }
    }

    const result: ?flx.Result = flx.score(allocator, "switch-to-buffer", "z");
    if (result != null) {
        defer result.?.deinit();
    }

    try testing.expect(result == null);
}

test "hello-world hlw" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        //fail test; can't try in defer as defer is executed after we return
        if (deinit_status == .leak) {
            testing.expect(false) catch @panic("TEST FAIL");
        }
    }

    const result: ?flx.Result = flx.score(allocator, "hello-world", "hlw");
    defer result.?.deinit();

    try testing.expect(result.?.score == 159);
}
