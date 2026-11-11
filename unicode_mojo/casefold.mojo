"""Simple case-fold closure of code-point sets from frozen Polars 1.44.2 data.

This is simple folding for caseless set membership, not full string casefold.
For example sharp S does not expand into two characters here.
"""
from ._regex_tables import fold_keys, fold_next
from .ranges import canonical

comptime CASE_FOLD_SOURCE = "Polars 1.44.2 (Rust regex)"


struct CaseFolds(Copyable, Movable):
    """Simple case-folding orbits: `next[k]` is the member after `keys[k]`
    in its orbit, cyclically. Only code points with a folding appear."""

    var keys: List[UInt32]
    var next: List[UInt32]

    def __init__(out self):
        self.keys = fold_keys()
        self.next = fold_next()

    def _lower_bound(self, cp: UInt32) -> Int:
        var lo = 0
        var hi = len(self.keys)
        while lo < hi:
            var mid = (lo + hi) // 2
            if self.keys[mid] < cp:
                lo = mid + 1
            else:
                hi = mid
        return lo

    def fold(self, ranges: List[UInt32]) -> List[UInt32]:
        """The set closed under simple case folding."""
        var out = ranges.copy()
        for i in range(0, len(ranges), 2):
            var k = self._lower_bound(ranges[i])
            while k < len(self.keys) and self.keys[k] <= ranges[i + 1]:
                var member = self.next[k]
                while member != self.keys[k]:
                    out.append(member)
                    out.append(member)
                    member = self.next[self._lower_bound(member)]
                k += 1
        return canonical(out)
