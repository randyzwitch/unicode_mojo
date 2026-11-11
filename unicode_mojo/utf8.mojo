"""Append validated Unicode scalars to shared output byte buffers."""
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
