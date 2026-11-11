"""Set operations on flat inclusive code-point range pairs.

Inputs contain ordered pairs lo, hi in 0..0x10FFFF. Except for canonical(),
sets must already be sorted, disjoint and nonadjacent. The domain includes
surrogates: negate() complements code points, not only Unicode scalar values.
No input is mutated. Returned lists own their storage.
"""
comptime MAX_CODEPOINT: UInt32 = 0x10FFFF


def canonical(ranges: List[UInt32]) -> List[UInt32]:
    """Sort ranges by start and merge overlapping or adjacent ones."""
    var keys = List[UInt64](capacity=len(ranges) // 2)
    for i in range(0, len(ranges), 2):
        keys.append((UInt64(ranges[i]) << 32) | UInt64(ranges[i + 1]))
    sort(Span(keys))
    var out = List[UInt32](capacity=len(ranges))
    for key in keys:
        var lo = UInt32(key >> 32)
        var hi = UInt32(key & 0xFFFFFFFF)
        var n = len(out)
        if n > 0 and lo <= out[n - 1] + 1:
            if hi > out[n - 1]:
                out[n - 1] = hi
        else:
            out.append(lo)
            out.append(hi)
    return out^


def negate(ranges: List[UInt32]) -> List[UInt32]:
    var out = List[UInt32]()
    var next: UInt32 = 0
    for i in range(0, len(ranges), 2):
        if ranges[i] > next:
            out.append(next)
            out.append(ranges[i] - 1)
        next = ranges[i + 1] + 1
    if next <= MAX_CODEPOINT:
        out.append(next)
        out.append(MAX_CODEPOINT)
    return out^


def union(a: List[UInt32], b: List[UInt32]) -> List[UInt32]:
    var both = a.copy()
    both.extend(b.copy())
    return canonical(both)


def intersect(a: List[UInt32], b: List[UInt32]) -> List[UInt32]:
    var out = List[UInt32]()
    var i = 0
    var j = 0
    while i < len(a) and j < len(b):
        var lo = max(a[i], b[j])
        var hi = min(a[i + 1], b[j + 1])
        if lo <= hi:
            out.append(lo)
            out.append(hi)
        if a[i + 1] < b[j + 1]:
            i += 2
        else:
            j += 2
    return out^


def difference(a: List[UInt32], b: List[UInt32]) -> List[UInt32]:
    return intersect(a, negate(b))


def symmetric_difference(a: List[UInt32], b: List[UInt32]) -> List[UInt32]:
    return union(difference(a, b), difference(b, a))


@always_inline
def contains_bounds(
    ranges: List[UInt32], cp: UInt32, var lo: Int, var hi: Int
) -> Bool:
    """Search a bounded slice of canonical range pairs."""
    var points = ranges.unsafe_ptr()
    while lo < hi:
        # lo and hi index range pairs; their sum is nonnegative and
        # bounded by the Unicode domain. Both endpoints are in bounds.
        var mid = (lo + hi) >> 1
        if cp < points[unsafe_offset=2 * mid]:
            hi = mid
        elif cp > points[unsafe_offset=2 * mid + 1]:
            lo = mid + 1
        else:
            return True
    return False


def contains(ranges: List[UInt32], cp: UInt32) -> Bool:
    """Binary search over the ranges."""
    return contains_bounds(ranges, cp, 0, len(ranges) >> 1)


def size(ranges: List[UInt32]) -> Int:
    var total = 0
    for i in range(0, len(ranges), 2):
        total += Int(ranges[i + 1] - ranges[i]) + 1
    return total
