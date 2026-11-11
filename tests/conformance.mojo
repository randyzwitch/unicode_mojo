"""All 20,034 Unicode 17 vectors and all 20 normalization invariants per row."""
from std.testing import assert_equal, assert_true
from unicode_mojo import Normalizer, QuickCheck


def decode_hex(text: StringSpan) -> String:
    var out = String()
    for word in text.split(" "):
        var cp = 0
        for byte in word.as_bytes():
            cp = cp * 16 + Int(byte - 48 if byte <= 57 else byte - 55)
        out += chr(cp)
    return out^


def main() raises:
    var vectors = List[List[String]]()
    for _ in range(5):
        vectors.append(List[String]())
    var corpus = open("tests/fixtures/normalization-17.0.0.txt", "r").read()
    for line in corpus.split("\n"):
        if line.byte_length() == 0 or line.startswith("#"):
            continue
        var fields = line.split(";")
        assert_equal(len(fields), 5)
        for k in range(5):
            vectors[k].append(decode_hex(fields[k]))
    assert_equal(len(vectors[0]), 20034)
    var checks = 0
    for form in [String("NFC"), String("NFD"), String("NFKC"), String("NFKD")]:
        var normalizer = Normalizer(form)
        for input in range(5):
            var expected = 1 if form == "NFC" else (
                2 if form == "NFD" else (3 if form == "NFKC" else 4)
            )
            if input >= 3 and form == "NFC":
                expected = 3
            if input >= 3 and form == "NFD":
                expected = 4
            for row in range(len(vectors[input])):
                ref source = vectors[input][row]
                ref target = vectors[expected][row]
                assert_equal(
                    normalizer.normalize(source),
                    target,
                    form + " input " + String(input) + " vector " + String(row),
                )
                var unchanged = source == target
                assert_equal(normalizer.is_normalized(source), unchanged)
                var quick = normalizer.quick_check(source)
                if quick == QuickCheck.YES:
                    assert_true(unchanged)
                elif quick == QuickCheck.NO:
                    assert_true(not unchanged)
                checks += 1
    print(
        "PASS",
        len(vectors[0]),
        "Unicode 17 vectors;",
        checks,
        "normalization invariants plus exact/quick checks",
    )
