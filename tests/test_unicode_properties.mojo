"""Property aliases, version boundaries, set algebra, and simple folding."""
from std.testing import (
    TestSuite,
    assert_equal,
    assert_true,
    assert_false,
    assert_raises,
)
from unicode_mojo import PROPERTY_UNICODE_VERSION, property_ranges, CaseFolds
from unicode_mojo.properties import word_ranges, digit_ranges, space_ranges
from unicode_mojo.ranges import (
    MAX_CODEPOINT,
    canonical,
    contains,
    contains_bounds,
    size,
    negate,
    union,
    intersect,
    difference,
    symmetric_difference,
)


def test_property_aliases_and_borrowed_names() raises:
    assert_equal(PROPERTY_UNICODE_VERSION, "16.0.0")
    var greek = property_ranges("Greek")
    for name in [
        String("IsGreek"),
        String("sC = gReK"),
        String(" Script = Greek "),
    ]:
        assert_equal(property_ranges(name), greek)
    assert_true(contains(greek, 0x03B1))
    assert_false(contains(greek, 0x41))
    assert_equal(
        property_ranges("gc=Lu"),
        property_ranges("General_Category=Uppercase_Letter"),
    )
    assert_equal(property_ranges("Lu"), property_ranges("gc=Lu"))
    assert_equal(property_ranges(" White- _Space\t"), space_ranges())
    assert_equal(property_ranges("Nd"), digit_ranges())
    var owner = String("prefix:Script=Greek:excluded")
    var name = StringSpan(unsafe_from_utf8=owner.as_bytes()[7:19])
    assert_equal(property_ranges(name), greek)
    var changed = property_ranges("Greek")
    changed[0] = 0
    changed.append(UInt32.MAX)
    assert_equal(property_ranges("Greek"), greek)


def test_property_kinds_scalar_boundaries_and_versions() raises:
    assert_true(contains(property_ranges("scx=Hira"), 0x30FC))
    assert_false(contains(property_ranges("sc=Hira"), 0x30FC))
    assert_true(contains(property_ranges("sc=Common"), 0x30FC))
    var age = property_ranges("age=3.0")
    assert_true(contains(age, 0x41))
    assert_true(contains(age, 0x20AC))
    assert_false(contains(age, 0x1F600))
    assert_true(
        contains(property_ranges("Grapheme_Cluster_Break=Extend"), 0x0301)
    )
    assert_true(contains(property_ranges("Word_Break=ALetter"), 0x41))
    assert_true(contains(property_ranges("Sentence_Break=Lower"), 0x61))
    assert_true(contains(property_ranges("Emoji"), 0x1F600))
    assert_true(contains(property_ranges("Alphabetic"), 0x1C89))
    var any = property_ranges("Any")
    for cp in [0, 0xD7FF, 0xE000, 0xFFFF, 0x10FFFF]:
        assert_true(contains(any, UInt32(cp)))
    for cp in [0xD800, 0xDFFF, 0x110000]:
        assert_false(contains(any, UInt32(cp)))
    assert_equal(size(any), 0x110000 - 0x800)
    assert_false(contains(property_ranges("Assigned"), 0x0378))
    assert_true(contains(digit_ranges(), 0x0660))
    assert_true(contains(word_ranges(), 0x0300))
    assert_true(contains(word_ranges(), 0x200C))
    assert_false(contains(word_ranges(), 0x1F600))


def test_unknown_properties_raise() raises:
    for name in [
        String(""),
        String("unknown"),
        String("gc=unknown"),
        String("sc==Latin"),
        String("Greek\x00"),
    ]:
        with assert_raises(contains="Unknown Unicode property"):
            _ = property_ranges(name)


def test_simple_folding_orbits_and_no_full_string_expansion() raises:
    var folds = CaseFolds()
    var kelvin = folds.fold([UInt32(0x6B), UInt32(0x6B)])
    assert_equal(
        kelvin,
        [
            UInt32(0x4B),
            UInt32(0x4B),
            UInt32(0x6B),
            UInt32(0x6B),
            UInt32(0x212A),
            UInt32(0x212A),
        ],
    )
    var sigma = folds.fold([UInt32(0x03C2), UInt32(0x03C2)])
    assert_equal(
        sigma, [UInt32(0x03A3), UInt32(0x03A3), UInt32(0x03C2), UInt32(0x03C3)]
    )
    var sharp = folds.fold([UInt32(0x00DF), UInt32(0x00DF)])
    assert_true(contains(sharp, 0x1E9E))
    assert_false(contains(sharp, 0x53))
    assert_false(contains(sharp, 0x73))
    assert_equal(folds.fold(kelvin), kelvin)
    assert_equal(folds.fold(List[UInt32]()), List[UInt32]())


def _set(mask: Int) -> List[UInt32]:
    var values = List[UInt32]()
    for bit in range(5):
        if mask & (1 << bit):
            values.append(UInt32(bit))
            values.append(UInt32(bit))
    return canonical(values)


def test_range_algebra_matches_boolean_membership() raises:
    for a_mask in range(32):
        var a = _set(a_mask)
        var count = 0
        for bit in range(5):
            count += Int(Bool(a_mask & (1 << bit)))
        assert_equal(size(a), count)
        for b_mask in range(32):
            var b = _set(b_mask)
            var both = union(a, b)
            var common = intersect(a, b)
            var left = difference(a, b)
            var either = symmetric_difference(a, b)
            for cp in range(5):
                var in_a = Bool(a_mask & (1 << cp))
                var in_b = Bool(b_mask & (1 << cp))
                assert_equal(contains(both, UInt32(cp)), in_a or in_b)
                assert_equal(contains(common, UInt32(cp)), in_a and in_b)
                assert_equal(contains(left, UInt32(cp)), in_a and not in_b)
                assert_equal(contains(either, UInt32(cp)), in_a != in_b)
    var input: List[UInt32] = [
        8,
        9,
        2,
        4,
        0,
        0,
        3,
        7,
        1,
        1,
        MAX_CODEPOINT,
        MAX_CODEPOINT,
    ]
    var sorted = canonical(input)
    assert_equal(
        sorted,
        [UInt32(0), UInt32(9), UInt32(MAX_CODEPOINT), UInt32(MAX_CODEPOINT)],
    )
    assert_equal(negate(sorted), [UInt32(10), UInt32(MAX_CODEPOINT - 1)])
    assert_equal(negate(List[UInt32]()), [UInt32(0), UInt32(MAX_CODEPOINT)])
    assert_true(contains_bounds(sorted, MAX_CODEPOINT, 1, 2))
    assert_false(contains_bounds(sorted, 5, 1, 2))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
