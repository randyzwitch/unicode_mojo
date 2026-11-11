from unicode_mojo import Normalizer, QuickCheck, normalize


def main() raises:
    print(normalize("cafe\u0301"))
    var normalizer = Normalizer("NFKC")
    var output = List[UInt8]()
    normalizer.normalize_into("ＫＡＤＯＫＡＷＡ ²", output)
    print(String(unsafe_from_utf8=output))
    print(normalizer.quick_check("already normalized") == QuickCheck.YES)
