"""Code-point slices, reversal, and explicit character-set trimming.

Inputs are borrowed validated UTF-8. These operations work on code points,
not grapheme clusters. Byte bounds let columnar consumers retain their own
storage and avoid allocating a string for every row.
"""
from .utf8 import (
    count_codepoints,
    unsafe_advance_codepoints,
    unsafe_next_codepoint_boundary,
    unsafe_previous_codepoint_boundary,
)


def codepoint_slice_bounds(
    text: StringSpan, offset: Int, length: Int = -1
) -> Tuple[Int, Int]:
    """Return half-open byte bounds for a clipped slice by code-point index.

    Negative offsets count from the end; any negative length takes the
    remainder. Indices and lengths outside the text are clipped.
    """
    var start = offset if offset >= 0 else max(
        count_codepoints(text) + offset, 0
    )
    var first = unsafe_advance_codepoints(text, 0, start)
    var last = text.byte_length() if length < 0 else (
        unsafe_advance_codepoints(text, first, length)
    )
    return (first, last)


def slice_codepoints(text: StringSpan, offset: Int, length: Int = -1) -> String:
    """Return an owned string using codepoint_slice_bounds semantics."""
    var first, last = codepoint_slice_bounds(text, offset, length)
    return String(StringSpan(unsafe_from_utf8=text.as_bytes()[first:last]))


def reverse_codepoints_into(text: StringSpan, mut output: List[UInt8]):
    """Append the text's code points in reverse, preserving output's prefix.

    Input must not alias output. Reversal treats this input independently
    of earlier output and does not preserve grapheme clusters.
    """
    var last = text.byte_length()
    var bytes = text.as_bytes()
    while last > 0:
        var first = unsafe_previous_codepoint_boundary(text, last)
        output.extend(bytes[first:last])
        last = first


def reverse_codepoints(text: StringSpan) -> String:
    """Return an owned string with its code points reversed."""
    var output = List[UInt8](capacity=text.byte_length())
    reverse_codepoints_into(text, output)
    return String(unsafe_from_utf8=output)


struct CodepointTrimSet(Movable):
    """A reusable explicit set of characters to remove from string edges.

    Empty characters means an empty removal set. No default whitespace
    policy is implied; supply the exact characters to remove.
    """

    var _ascii: List[Bool]
    var _unicode: List[String]

    def __init__(out self, characters: StringSpan):
        self._ascii = List[Bool](length=128, fill=False)
        self._unicode = List[String]()
        var row = characters.as_bytes()
        var at = 0
        while at < len(row):
            var end = unsafe_next_codepoint_boundary(characters, at)
            if end - at == 1:
                self._ascii[Int(row[at])] = True
            else:
                self._unicode.append(
                    String(StringSpan(unsafe_from_utf8=row[at:end]))
                )
            at = end

    @always_inline
    def _contains(self, text: StringSpan, first: Int, last: Int) -> Bool:
        var row = text.as_bytes()
        if last - first == 1:
            return self._ascii[Int(row[first])]
        var part = StringSpan(unsafe_from_utf8=row[first:last])
        for candidate in self._unicode:
            if candidate == part:
                return True
        return False

    def bounds(
        self, text: StringSpan, leading: Bool = True, trailing: Bool = True
    ) -> Tuple[Int, Int]:
        """Return half-open byte bounds after trimming the selected edges."""
        var first = 0
        var last = text.byte_length()
        if leading:
            while first < last:
                var end = unsafe_next_codepoint_boundary(text, first)
                if not self._contains(text, first, end):
                    break
                first = end
        if trailing:
            while last > first:
                var start = unsafe_previous_codepoint_boundary(text, last)
                if not self._contains(text, start, last):
                    break
                last = start
        return (first, last)

    def trim(
        self, text: StringSpan, leading: Bool = True, trailing: Bool = True
    ) -> String:
        """Return an owned trimmed string using this removal set."""
        var first, last = self.bounds(text, leading, trailing)
        return String(StringSpan(unsafe_from_utf8=text.as_bytes()[first:last]))
