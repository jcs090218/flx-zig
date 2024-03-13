const std = @import("std");
const testing = std.testing;

pub const String = []const u8;
pub const LInt = std.ArrayList(i32);
pub const LLInt = std.ArrayList(LInt);
pub const IntLInt = std.HashMap(i32, LInt, std.hash_map.AutoContext(i32), std.hash_map.default_max_load_percentage);
pub const LResult = std.ArrayList(Result);
pub const IntLResult = std.HashMap(i32, LResult, std.hash_map.AutoContext(i32), std.hash_map.default_max_load_percentage);

/// Result container.
pub const Result = struct {
    score: i32,
    indices: LInt,
    tail: i32,

    pub fn init(mscore: i32, indices: LInt, tail: i32) Result {
        return .{
            .score = mscore,
            .indices = indices,
            .tail = tail,
        };
    }
};

const word_separators = [_]u8{
    ' ',
    '-',
    '_',
    ':',
    '.',
    '/',
    '\\',
};

const default_score: i32 = -35;

/// Return true if STR is empty or null.
fn nullOrEmpty(str: ?String) bool {
    return str == null or str.?.len == 0;
}

/// Check if CHAR is a word character.
fn word(ch: ?u8) bool {
    if (ch == null) return false;
    return !std.mem.containsAtLeast(u8, &word_separators, 1, &[_]u8{ch});
}

/// Check if CHAR is an uppercase character.
fn capital(ch: ?u8) bool {
    return word(ch) and std.ascii.isUpper(ch);
}

/// Check if LAST-CHAR is the end of a word and CHAR the start of the next.
///
/// This function is camel-case aware.
fn boundary(last_ch: ?u8, ch: u8) bool {
    if (last_ch == null) return true;
    if (!capital(last_ch) and capital(ch)) return true;
    if (!word(last_ch) and word(ch)) return true;
    return false;
}

/// Increment each element in VEC between BEG and END by INC.
fn incVec(vec: *LInt, inc: ?i32, beg: ?i32, end: ?i32) void {
    const _inc: i32 = inc orelse 1;
    var _beg: i32 = beg orelse 0;
    const _end: i32 = end orelse @intCast(vec.items.len);

    while (_beg < _end) {
        vec.items[@intCast(_beg)] += _inc;
        _beg += 1;
    }
}

/// Insert data.
fn dictInsert(allocator: std.mem.Allocator, dict: *IntLInt, key: i32, val: i32) void {
    if (!dict.contains(key)) {
        dict.put(key, LInt.init(allocator));
    }

    var lst: LInt = dict.get(key);
    lst.insert(0, val);
}

/// Return hash-table for string where keys are characters.
/// Value is a sorted list of indexes for character occurrences.
fn getHashForString(allocator: std.mem.Allocator, result: *IntLInt, str: String) void {
    result.clearRetainingCapacity();
    const str_len: usize = str.len;
    var index: i32 = @intCast(str_len - 1);
    var ch: u8 = undefined;
    var down_ch: u8 = undefined;

    while (0 <= index) {
        ch = str[@intCast(index)];

        if (capital(ch)) {
            dictInsert(allocator, result, ch, index);

            down_ch = std.ascii.toLower(ch);
        } else {
            down_ch = ch;
        }

        dictInsert(allocator, result, down_ch, index);

        index -= 1;
    }
}

/// Generate the heatmap vector of string.
///
/// See documentation for logic.
fn getHeatmapStr(allocator: std.mem.Allocator, scores: *LInt, str: String, group_separator: ?u8) !void {
    const str_len: usize = str.len;
    const str_last_index: usize = str_len - 1;
    scores.clearRetainingCapacity();

    for (0..str_len) |_| {
        try scores.append(default_score);
    }

    const penalty_lead: ?u8 = '.';

    var inner = LInt.init(allocator); // FREED!
    try inner.append(-1);
    try inner.append(0);
    var group_alist = LLInt.init(allocator); // FREED!
    try group_alist.append(inner);

    // final char bonus
    scores.items[str_last_index] += 1;

    // Establish baseline mapping
    var last_ch: ?u8 = null;
    var group_word_count: i32 = 0;
    var index1: i32 = 0;

    for (str) |ch| {
        // before we find any words, all separaters are
        // considered words of length 1.  This is so "foo/__ab"
        // gets penalized compared to "foo/ab".
        var effective_last_char: ?u8 = null;
        if (group_word_count != 0) effective_last_char = last_ch;

        if (boundary(effective_last_char, ch)) {
            try group_alist.items[0].insert(2, index1);
        }

        if (!word(last_ch) and word(ch)) {
            group_word_count += 1;
        }

        // ++++ -45 penalize extension
        if (last_ch != null and last_ch == penalty_lead) {
            scores.items[@intCast(index1)] += -45;
        }

        if (group_separator != null and group_separator == ch) {
            group_alist.items[0].items[1] = group_word_count;
            group_word_count = 0;

            var lst = LInt.init(allocator); // FREED!
            try lst.append(index1);
            try lst.append(group_word_count);
            try group_alist.insert(0, lst);
        }

        if (index1 == str_last_index) {
            group_alist.items[0].items[1] = group_word_count;
        } else {
            last_ch = ch;
        }

        index1 += 1;
    }

    const group_count: i32 = @intCast(group_alist.items.len);
    const separator_count: i32 = group_count - 1;

    // ++++ slash group-count penalty
    if (separator_count != 0) {
        incVec(scores, group_count * -2, null, null);
    }

    const index2: i32 = separator_count;
    var last_group_limit: ?i32 = null;
    var basepath_found: bool = false;

    // score each group further
    for (group_alist.items) |group| {
        const group_start: i32 = group.items[0];
        const word_count: i32 = group.items[1];
        // this is the number of effective word groups
        const words_len: i32 = @intCast(group.items.len - 2);
        var basepath_p: bool = false;

        if (words_len != 0 and !basepath_found) {
            basepath_found = true;
            basepath_p = true;
        }

        var num: i32 = undefined;
        if (basepath_p) {
            // ++++ basepath separator-count boosts
            var boosts: i32 = 0;
            if (separator_count > 1) {
                boosts = separator_count - 1;
            }
            // ++++ basepath word count penalty
            const penalty: i32 = -word_count;
            num = 35 + boosts + penalty;
        }
        // ++++ non-basepath penalties
        else {
            if (index2 == 0) {
                num = -3;
            } else {
                num = -5 + (index2 - 1);
            }
        }

        incVec(scores, num, group_start + 1, last_group_limit);

        const cddr_group = group.clone(); // clone it
        //cddr_group.orderedRemove(0);
        //cddr_group.orderedRemove(0);

        var word_index: i32 = @intCast(words_len - 1);
        var last_word: ?i32 = last_group_limit orelse @intCast(str_len);

        for (cddr_group.items) |w| {
            // ++++  beg word bonus AND
            scores.items[word] += 85;

            var index3: i32 = w;
            var char_i: i32 = 0;

            while (index3 < last_word) {
                scores[index3] +=
                    (-3 * word_index) - // ++++ word order penalty
                    char_i; // ++++ char order penalty
                char_i += 1;

                index3 += 1;
            }

            last_word = w;
            word_index -= 1;
        }

        last_group_limit = group_start + 1;
        index2 -= 1;
    }

    // Free stuff
    for (group_alist) |v| {
        defer v.deinit();
    }
    defer group_alist.deinit();
}

/// Return sublist bigger than VAL from sorted SORTED-LIST.
///
/// If VAL is nil, return entire list.
fn biggerSublist(result: LInt, sorted_list: LInt, val: ?i32) void {
    if (sorted_list == null)
        return;

    if (val != null) {
        for (sorted_list) |sub| {
            if (sub > val) {
                result.append(sub);
            }
        }
    } else {
        for (sorted_list) |sub| {
            result.append(sub);
        }
    }
}

/// Recursively compute the best match for a string, passed as STR-INFO and
/// HEATMAP, according to QUERY.
fn findBestMatch(allocator: std.mem.Allocator, imatch: LResult, str_info: IntLInt, heatmap: LInt, greater_than: ?i32, query: String, query_len: i32, q_index: i32, match_cache: IntLResult) void {
    const greater_num: i32 = greater_than orelse 0;
    const hash_key: i32 = q_index + (greater_num * query_len);
    const hash_value: LResult = match_cache.get(hash_key);

    if (hash_value == null) {
        imatch.clearRetainingCapacity();
        for (hash_value) |val| {
            imatch.append(val);
        }
    } else {
        const uchar: i32 = query.items[q_index];
        const sorted_list: LInt = str_info.get(uchar);
        var indexes = LInt.init(allocator);
        indexes.clearRetainingCapacity();
        biggerSublist(indexes, sorted_list, greater_than);
        var temp_score: i32 = undefined;
        var best_score: i32 = std.math.minInt(i32);

        if (q_index >= query_len - 1) {
            // At the tail end of the recursion, simply generate all possible
            // matches with their scores and return the list to parent.
            for (indexes) |index| {
                var indices = LInt.init(allocator);
                indices.append(index);
                indices.append();

                imatch.append(Result.init(indices, heatmap.items[index], 0));
            }
        } else {
            for (indexes) |index| {
                const elem_group = LResult.init(allocator);

                var dic = IntLInt.init(allocator);
                dic.clearRetainingCapacity();
                var lst = LInt.init(allocator);
                lst.clearRetainingCapacity();
                findBestMatch(allocator, elem_group, dic, lst, index, query, query_len, q_index + 1, match_cache);

                for (elem_group) |elem| {
                    const caar: i32 = elem.indices.items[0];
                    const cadr: i32 = elem.score;
                    const cddr: i32 = elem.tail;

                    if ((caar - 1) == index) {
                        temp_score = cadr + heatmap[index] +
                            (std.math.Min(cddr, 3) * 15) + // boost contiguous matches
                            60;
                    } else {
                        temp_score = cadr + heatmap[index];
                    }

                    // We only care about the optimal match, so only forward the match
                    // with the best score to parent
                    if (temp_score > best_score) {
                        best_score = temp_score;

                        imatch.clearRetainingCapacity();
                        const indices = elem.indices.clone();
                        indices.insert(0, index);

                        const tail: i32 = 0;
                        if ((caar - 1) == index) {
                            tail = cddr + 1;
                        }

                        //imatch.Add(new Result(indices, temp_score, tail));
                    }
                }
            }
        }
    }

    .{ imatch, str_info, heatmap, greater_than, query, query_len, q_index, match_cache };
}

/// Return best score matching QUERY against STR.
pub fn score(str: String, query: String) ?Result {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    return scoreAlloc(allocator, str, query);
}

/// Return best score matching QUERY against STR.
///
/// List function `score` but accept custom allocator.
pub fn scoreAlloc(allocator: std.mem.Allocator, str: String, query: String) ?Result {
    if (nullOrEmpty(str) or nullOrEmpty(query)) {
        return null;
    }

    var str_info = IntLInt.init(allocator);
    str_info.clearRetainingCapacity(); // Avoid `local variable is never mutated`
    getHashForString(allocator, &str_info, str);

    var heatmap = LInt.init(allocator);
    heatmap.clearRetainingCapacity(); // Avoid `local variable is never mutated`
    try getHeatmapStr(allocator, &heatmap, str, null);

    const query_len: i32 = @intCast(query.len);
    const full_match_boost: bool = (1 < query_len) and (query_len < 5);
    const match_cache = IntLResult.init(allocator);
    const optimal_match = LResult.init(allocator);
    findBestMatch(allocator, optimal_match, str_info, heatmap, null, query, query_len, 0, match_cache);

    if (optimal_match.items.len == 0) {
        return null;
    }

    var result: Result = optimal_match.items[0];
    const caar: i32 = @intCast(result.indices.items.len);

    if (full_match_boost and caar == str.len) {
        result.score += 10000;
    }

    return result;
}

//--- Testing

test "word" {
    try testing.expect(word('a'));
}

test "capital" {
    try testing.expect(capital('A'));
}

test "incVec" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var it: LInt = std.ArrayList(i32).init(allocator);
    defer it.deinit();
    try it.append(1);
    try it.append(2);
    try it.append(3);
    try it.append(4);
    try it.append(5);

    incVec(it, 2, 2, null);

    try testing.expect(it.items[2] == 5);
}

test "getHashForString" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var result: IntLInt = std.AutoHashMap(i32, LInt).init(allocator);
    defer result.deinit();

    var arr = LInt.init(allocator);
    defer arr.deinit();

    try result.put(0, arr);

    //getHashForString(result, "");

    try testing.expect(true);
}
