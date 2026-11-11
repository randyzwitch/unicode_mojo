"""Counting, traversal, and emission of validated UTF-8."""
from std.collections.string import Codepoint


@always_inline
def unsafe_append_codepoint(mut out: List[UInt8], cp: Int):
    """Append a valid Unicode scalar to an independent output buffer.

    The caller must guarantee 0 <= cp <= 0x10FFFF excluding surrogates.
    Existing output bytes are retained; invalid scalars are not checked.
    """
    var scalar = Codepoint(unsafe_unchecked_codepoint=UInt32(cp))
    var start = len(out)
    var size = scalar.utf8_byte_length()
    out.resize(start + size, 0)
    _ = scalar.unsafe_write_utf8(out.unsafe_ptr().unsafe_offset(start))


@always_inline
def unsafe_codepoint_width(lead: UInt8) -> Int:
    """Width of a leading byte in validated UTF-8; not a byte validator."""
    if lead < 0x80:
        return 1
    if lead < 0xE0:
        return 2
    if lead < 0xF0:
        return 3
    return 4


@always_inline
def count_codepoints(text: StringSpan) -> Int:
    """Count Unicode scalars, including combining marks separately.

    Input is borrowed validated UTF-8. This is not a grapheme count or a
    validator. Complete 32-byte blocks use SIMD; the tail stays in bounds.
    """
    var row = text.as_bytes()
    var p = row.unsafe_ptr()
    var count = 0
    var i = 0
    while i + 32 <= len(row):
        var bytes = p.unsafe_offset(i).unsafe_load[width=32]()
        count += Int(
            (bytes & SIMD[DType.uint8, 32](192))
            .ne(SIMD[DType.uint8, 32](128))
            .cast[DType.uint8]()
            .reduce_add()
        )
        i += 32
    while i < len(row):
        count += Int((p.unsafe_offset(i)[] & 192) != 128)
        i += 1
    return count


@always_inline
def unsafe_next_codepoint_boundary(text: StringSpan, at: Int) -> Int:
    """Return the boundary after the scalar starting at byte offset at.

    The caller guarantees that at is a code-point boundary with
    0 <= at < text.byte_length(). Input must be validated UTF-8.
    """
    var row = text.as_bytes()
    var p = row.unsafe_ptr()
    var end = at + 1
    while end < len(row) and (p[unsafe_offset=end] & 192) == 128:
        end += 1
    return end


@always_inline
def unsafe_previous_codepoint_boundary(text: StringSpan, at: Int) -> Int:
    """Return the boundary before a known boundary at byte offset at.

    The caller guarantees 0 < at <= text.byte_length() and validated UTF-8.
    """
    var row = text.as_bytes()
    var p = row.unsafe_ptr()
    var first = at - 1
    while first > 0 and (p[unsafe_offset=first] & 192) == 128:
        first -= 1
    return first


@always_inline
def unsafe_advance_codepoints(text: StringSpan, at: Int, count: Int) -> Int:
    """Advance at most count scalars, clipping to the end of the text.

    The caller guarantees a boundary 0 <= at <= text.byte_length() in
    validated UTF-8. A nonpositive count leaves at unchanged.
    """
    var i = at
    var left = count
    while left > 0 and i < text.byte_length():
        i = unsafe_next_codepoint_boundary(text, i)
        left -= 1
    return i
