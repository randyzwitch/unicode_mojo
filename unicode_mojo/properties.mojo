"""Unicode property lookup and frozen regex-style character sets.

Property names use loose ASCII matching, including aliases and an optional
Is prefix. Unknown names raise Error. Results are owned canonical inclusive
range pairs over Unicode scalar values. Property data is Unicode 16.0;
word/digit/space sets preserve the existing Polars 1.44.2 snapshot.
"""
from ._property_tables import PROPERTY_INDEX, PROPERTY_RANGES
from ._regex_tables import word_ranges, digit_ranges, space_ranges

comptime PROPERTY_UNICODE_VERSION = "16.0.0"
comptime REGEX_CLASS_SOURCE = "Polars 1.44.2 (Rust regex)"


def _hex_digit(byte: UInt8) -> UInt32:
    if byte <= 57:
        return UInt32(byte - 48)
    if byte <= 70:
        return UInt32(byte - 55)
    return UInt32(byte - 87)


def _parse_ranges(
    table: StaticString, start: Int = 0, end: Int = -1
) -> List[UInt32]:
    """Read a table of whitespace-separated hex code points and `lo-hi`
    ranges."""
    var out = List[UInt32]()
    var value: UInt32 = 0
    var low: UInt32 = 0
    var in_token = False
    var ranged = False
    var bytes = table.as_bytes()
    for i in range(start, len(bytes) if end < 0 else end):
        var byte = bytes[i]
        if byte == 32 or byte == 10:
            if in_token:
                out.append(low if ranged else value)
                out.append(value)
            value = 0
            in_token = False
            ranged = False
        elif byte == 45:
            low = value
            value = 0
            ranged = True
        else:
            value = value * 16 + _hex_digit(byte)
            in_token = True
    if in_token:
        out.append(low if ranged else value)
        out.append(value)
    return out^


def property_ranges(name: StringSpan) raises -> List[UInt32]:
    """Unicode property names and values use loose ASCII matching."""
    var key = String()
    for byte in name.as_bytes():
        if byte == 95 or byte == 45 or byte == 32 or (byte >= 9 and byte <= 13):
            continue
        key += chr(Int(byte + 32 if byte >= 65 and byte <= 90 else byte))
    if key.startswith("is"):
        var trimmed = String(key[byte=2:])
        key = trimmed^
    var table = PROPERTY_INDEX.as_bytes()
    var wanted = key.as_bytes()
    var at = 0
    while at < len(table):
        var equal = True
        var size = 0
        while table[at] != 58:
            if size >= len(wanted):
                equal = False
            elif table[at] != wanted[size]:
                equal = False
            at += 1
            size += 1
        equal = equal and size == len(wanted)
        at += 1
        var start = 0
        while table[at] != 58:
            start = start * 10 + Int(table[at]) - 48
            at += 1
        at += 1
        var end = 0
        while table[at] != 10:
            end = end * 10 + Int(table[at]) - 48
            at += 1
        at += 1
        if equal:
            return _parse_ranges(PROPERTY_RANGES, start, end)
    raise Error("Unknown Unicode property: " + String(name))
