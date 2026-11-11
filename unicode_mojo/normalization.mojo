"""Unicode 17 normalization primitives with static tables and reusable scratch."""
from std.collections.string import Codepoint
from unicode_mojo._normalization_tables import (
    properties,
    decomposition,
    decomposition_value,
    composition,
)

comptime UNICODE_VERSION = "17.0.0"
comptime _Row = Span[UInt8, ImmutAnyOrigin]


@fieldwise_init
struct QuickCheck(Copyable, Equatable, ImplicitlyCopyable, Movable):
    """YES guarantees normalization; NO rejects it; MAYBE needs a full check.

    Use the named constants. The integer representation is internal.
    """

    var _value: Int
    comptime YES = Self(0)
    comptime NO = Self(1)
    comptime MAYBE = Self(2)

    def __eq__(self, other: Self) -> Bool:
        return self._value == other._value


def _quick(row: _Row, shift: Int, mask: Int) -> QuickCheck:
    var at = 0
    var previous = 0
    var maybe = False
    while at < len(row):
        if (
            at + 8 <= len(row)
            and (
                row.unsafe_ptr()
                .unsafe_offset(at)
                .unsafe_bitcast[UInt64]()
                .unsafe_load()
                & 0x8080808080808080
            )
            == 0
        ):
            at += 8
            previous = 0
            continue
        var cp = _codepoint(row, at)
        var value = properties(cp)
        var check = (value >> shift) & mask
        if check == 1:
            return QuickCheck.NO
        maybe = maybe or check == 2
        var ccc = value & 255
        if ccc != 0 and previous > ccc:
            return QuickCheck.NO
        previous = ccc
    return QuickCheck.MAYBE if maybe else QuickCheck.YES


@always_inline
def _codepoint(row: _Row, mut at: Int) -> Int:
    var scalar, width = Codepoint.unsafe_decode_utf8_codepoint(row[at:])
    at += width
    return Int(scalar)


@always_inline
def _append_utf8(mut out: List[UInt8], cp: Int):
    var scalar = Codepoint(unsafe_unchecked_codepoint=UInt32(cp))
    var start = len(out)
    var size = scalar.utf8_byte_length()
    out.resize(start + size, 0)
    _ = scalar.unsafe_write_utf8(out.unsafe_ptr().unsafe_offset(start))


def _decompose(mut out: List[Int], cp: Int, compatible: Bool):
    if cp >= 0xAC00 and cp < 0xAC00 + 11172:
        var syllable = cp - 0xAC00
        out.append(0x1100 + syllable // 588)
        out.append(0x1161 + (syllable % 588) // 28)
        if syllable % 28 != 0:
            out.append(0x11A7 + syllable % 28)
        return
    if cp >= 128:
        var mapped = decomposition(cp, compatible)
        if mapped[1] != 0:
            for k in range(mapped[1]):
                _decompose(out, decomposition_value(mapped[0] + k), compatible)
            return
    out.append(cp)


def _sort_marks(mut values: List[Int], start: Int, end: Int):
    # Short runs use bounded insertion; long adversarial runs use a stable
    # counting sort over the 256 canonical classes, avoiding quadratic work.
    if end - start <= 32:
        for i in range(start + 1, end):
            var value = values[i]
            var ccc = properties(value) & 255
            var j = i
            while j > start and (properties(values[j - 1]) & 255) > ccc:
                values[j] = values[j - 1]
                j -= 1
            values[j] = value
        return
    var positions = List[Int](length=256, fill=0)
    for i in range(start, end):
        positions[properties(values[i]) & 255] += 1
    var total = 0
    for i in range(256):
        var count = positions[i]
        positions[i] = total
        total += count
    var sorted = List[Int](unsafe_uninit_length=end - start)
    for i in range(start, end):
        var ccc = properties(values[i]) & 255
        sorted[positions[ccc]] = values[i]
        positions[ccc] += 1
    for i in range(start, end):
        values[i] = sorted[i - start]


def _order(mut values: List[Int]):
    var start = 0
    var previous = 0
    var unsorted = False
    for i in range(len(values)):
        var ccc = properties(values[i]) & 255
        if ccc == 0:
            if unsorted:
                _sort_marks(values, start, i)
            start = i + 1
            unsorted = False
        elif previous > ccc:
            unsorted = True
        previous = ccc
    if unsorted:
        _sort_marks(values, start, len(values))


@always_inline
def _compose(a: Int, b: Int) -> Int:
    if a >= 0x1100 and a < 0x1100 + 19 and b >= 0x1161 and b < 0x1161 + 21:
        return 0xAC00 + ((a - 0x1100) * 21 + b - 0x1161) * 28
    if (
        a >= 0xAC00
        and a < 0xAC00 + 11172
        and (a - 0xAC00) % 28 == 0
        and b > 0x11A7
        and b < 0x11A7 + 28
    ):
        return a + b - 0x11A7
    return composition(a, b)


def _recompose(mut values: List[Int]) -> Int:
    var write = 0
    var starter = -1
    var previous = 0
    for i in range(len(values)):
        var cp = values[i]
        var ccc = properties(cp) & 255
        var combined = -1
        if cp >= 128 and starter >= 0 and (previous == 0 or previous < ccc):
            combined = _compose(values[starter], cp)
        if combined >= 0:
            values[starter] = combined
        else:
            if ccc == 0:
                starter = write
            values[write] = cp
            write += 1
            previous = ccc
    return write


struct Normalizer(Movable):
    """A validated normalization form and reusable decomposition scratch.

    Input is borrowed validated UTF-8. Each call treats it as a complete text;
    concatenating individually normalized fragments can require normalization
    again across their boundary. One instance belongs to one worker at a time.
    """

    var _shift: Int
    var _mask: Int
    var _compose: Bool
    var _compatible: Bool
    var _scratch: List[Int]

    def __init__(out self, form: StringSpan = "NFC") raises:
        """Choose NFC, NFD, NFKC or NFKD; reject any other spelling."""
        if (
            form != "NFC"
            and form != "NFD"
            and form != "NFKC"
            and form != "NFKD"
        ):
            raise Error("Normalization form must be NFC, NFD, NFKC or NFKD")
        self._shift = 8 if form == "NFC" else (
            10 if form == "NFD" else (11 if form == "NFKC" else 13)
        )
        self._mask = 3 if form == "NFC" or form == "NFKC" else 1
        self._compose = form == "NFC" or form == "NFKC"
        self._compatible = form == "NFKC" or form == "NFKD"
        self._scratch = List[Int]()

    def quick_check(self, text: StringSpan) -> QuickCheck:
        """Check without allocating; MAYBE does not mean unnormalized."""
        return _quick(text.as_bytes(), self._shift, self._mask)

    def normalize_into(mut self, text: StringSpan, mut output: List[UInt8]):
        """Append normalized UTF-8 to output, preserving its existing prefix.

        Input must not alias output. Scratch capacity is retained across calls.
        The appended text is normalized independently of the existing prefix.
        """
        var row = text.as_bytes()
        if _quick(row, self._shift, self._mask) == QuickCheck.YES:
            output.extend(row)
            return
        self._scratch.clear()
        var at = 0
        while at < len(row):
            var cp = _codepoint(row, at)
            if cp < 128:
                self._scratch.append(cp)
            else:
                _decompose(self._scratch, cp, self._compatible)
        _order(self._scratch)
        var size = _recompose(self._scratch) if self._compose else len(
            self._scratch
        )
        for k in range(size):
            _append_utf8(output, self._scratch[k])

    def normalize(mut self, text: StringSpan) -> String:
        """Return an owned normalized string, reusing this normalizer's scratch."""
        var output = List[UInt8](capacity=text.byte_length())
        self.normalize_into(text, output)
        return String(unsafe_from_utf8=output)

    def is_normalized(mut self, text: StringSpan) -> Bool:
        """Check exactly, normalizing only when the quick check says MAYBE."""
        var check = self.quick_check(text)
        if check == QuickCheck.YES:
            return True
        if check == QuickCheck.NO:
            return False
        return self.normalize(text) == text


def normalize(text: StringSpan, form: StringSpan = "NFC") raises -> String:
    """Normalize a string; reuse Normalizer when processing many strings."""
    var normalizer = Normalizer(form)
    return normalizer.normalize(text)


def is_normalized(text: StringSpan, form: StringSpan = "NFC") raises -> Bool:
    """Return whether text is in the requested normalization form."""
    var normalizer = Normalizer(form)
    return normalizer.is_normalized(text)
