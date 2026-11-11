"""Alphabetic-word title casing with dataframe's existing casing policy.

Word starts follow non-Alphabetic characters, using Unicode 15 Alphabetic.
Mappings use the pinned Mojo standard library's full lower/upper mappings.
Capital sigma uses immediate Alphabetic neighbors, without skipping
case-ignorable characters. This is not UAX #29 word-boundary title casing.
"""
from std.collections.string import Codepoint
from .alphabetic import alphabetic_ranges, is_alphabetic
from .utf8 import unsafe_codepoint_width

comptime _Row = Span[UInt8, ImmutAnyOrigin]


@always_inline
def _codepoint_value[
    origin: Origin
](data: Pointer[UInt8, origin], at: Int, width: Int) -> UInt32:
    var scalar, _ = Codepoint.unsafe_decode_utf8_codepoint(
        Span(unsafe_ptr=data.unsafe_offset(at), length=width)
    )
    return scalar.to_u32()


@always_inline
def _ascii_row(row: _Row) -> Bool:
    var data = row.unsafe_ptr()
    var size = len(row)
    var b = 0
    while b + 8 <= size:
        if (
            data.unsafe_offset(b).unsafe_bitcast[UInt64]().unsafe_load()
            & 0x8080808080808080
        ) != 0:
            return False
        b += 8
    while b < size:
        if data[unsafe_offset=b] >= 0x80:
            return False
        b += 1
    return True


def _ends_word(row: _Row, at: Int, width: Int, ranges: List[UInt32]) -> Bool:
    """Whether the code point at `at` follows an alphabetic one and is not
    followed by one, checking adjacent code points without skipping
    case-ignorable characters."""
    var data = row.unsafe_ptr()
    if at == 0:
        return False
    var before = at - 1
    while before > 0 and (data[unsafe_offset=before] & 0xC0) == 0x80:
        before -= 1
    if not is_alphabetic(
        ranges,
        _codepoint_value(
            data, before, unsafe_codepoint_width(data[unsafe_offset=before])
        ),
    ):
        return False
    var after = at + width
    if after >= len(row):
        return True
    return not is_alphabetic(
        ranges,
        _codepoint_value(
            data, after, unsafe_codepoint_width(data[unsafe_offset=after])
        ),
    )


struct AlphabeticTitleCaser(Movable):
    """Reusable alphabetic table for independent complete input strings."""

    var _ranges: List[UInt32]

    def __init__(out self):
        self._ranges = alphabetic_ranges()

    def titlecase_into(self, text: StringSpan, mut output: List[UInt8]):
        """Append title-cased UTF-8, independently of the existing prefix.

        Input is borrowed validated UTF-8 and must not alias output.
        """
        var row = text.as_bytes()
        ref ranges = self._ranges
        if _ascii_row(row):
            var upper = True
            for b in range(len(row)):
                var byte = row.unsafe_ptr()[unsafe_offset=b]
                var lower = byte | 32 if byte >= 65 and byte <= 90 else byte
                var letter = lower >= 97 and lower <= 122
                output.append(lower - 32 if upper and letter else lower)
                upper = not letter
            return
        var data = row.unsafe_ptr()
        var size = len(row)
        var upper = True
        var b = 0
        while b < size:
            var width = unsafe_codepoint_width(data[unsafe_offset=b])
            var value = _codepoint_value(data, b, width)
            if value < 128:
                var lower = UInt8(
                    value | 32
                ) if value >= 65 and value <= 90 else UInt8(value)
                var letter = lower >= 97 and lower <= 122
                output.append(lower - 32 if upper and letter else lower)
                upper = not letter
                b += width
                continue
            # Lowercase the code point (final sigma: a capital
            # sigma ending a word becomes ς), then uppercase what follows
            # a character that is not alphabetic.
            var lowered: String
            if value == 0x3A3:
                lowered = "ς" if _ends_word(row, b, width, ranges) else "σ"
            else:
                lowered = String(
                    StringSpan(
                        unsafe_from_utf8=_Row(
                            unsafe_ptr=data.unsafe_offset(b), length=width
                        )
                    )
                ).lower()
            var low = lowered.unsafe_ptr()
            var at = 0
            while at < lowered.byte_length():
                var part = unsafe_codepoint_width(low[unsafe_offset=at])
                var point = _codepoint_value(low, at, part)
                var text = _Row(
                    unsafe_ptr=low.unsafe_offset(at)
                    .unsafe_mut_cast[False]()
                    .unsafe_origin_cast[ImmutAnyOrigin](),
                    length=part,
                )
                if upper:
                    output.extend(
                        String(StringSpan(unsafe_from_utf8=text))
                        .upper()
                        .as_bytes()
                    )
                else:
                    output.extend(text)
                upper = not is_alphabetic(ranges, point)
                at += part
            # Read only through `low` above; keep it alive until here.
            _ = lowered^
            b += width

    def titlecase(self, text: StringSpan) -> String:
        """Return a new owned string."""
        var output = List[UInt8](capacity=text.byte_length())
        self.titlecase_into(text, output)
        return String(unsafe_from_utf8=output)


def alphabetic_titlecase(text: StringSpan) -> String:
    """Title-case one string; reuse AlphabeticTitleCaser for many strings."""
    var caser = AlphabeticTitleCaser()
    return caser.titlecase(text)
