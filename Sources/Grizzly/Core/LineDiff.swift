import Foundation

/// Line diff and three-way merge, used when a file changes on disk while it has unsaved edits.
enum LineDiff {
    enum Op { case equal, insert, delete }
    struct Row: Equatable {
        let op: Op
        let text: String
    }

    /// Longest-common-subsequence diff. The common beginning and end are cut off first; when the changed middle is
    /// too large for the table it is reported as one block of deletions followed by one of insertions.
    static func diff(_ a: [String], _ b: [String]) -> [Row] {
        var lo = 0
        while lo < a.count, lo < b.count, a[lo] == b[lo] { lo += 1 }
        var ea = a.count, eb = b.count
        while ea > lo, eb > lo, a[ea - 1] == b[eb - 1] { ea -= 1; eb -= 1 }
        var rows = a[..<lo].map { Row(op: .equal, text: $0) }
        let x = Array(a[lo..<ea]), y = Array(b[lo..<eb])
        if x.isEmpty || y.isEmpty || x.count * y.count > 4_000_000 {
            rows += x.map { Row(op: .delete, text: $0) } + y.map { Row(op: .insert, text: $0) }
        } else {
            // lcs[i][j] = length of the LCS of x[i...] and y[j...]
            var lcs = [[Int32]](repeating: [Int32](repeating: 0, count: y.count + 1), count: x.count + 1)
            for i in stride(from: x.count - 1, through: 0, by: -1) {
                for j in stride(from: y.count - 1, through: 0, by: -1) {
                    lcs[i][j] = x[i] == y[j] ? lcs[i + 1][j + 1] + 1 : max(lcs[i + 1][j], lcs[i][j + 1])
                }
            }
            var i = 0, j = 0
            while i < x.count || j < y.count {
                if i < x.count, j < y.count, x[i] == y[j] { rows.append(Row(op: .equal, text: x[i])); i += 1; j += 1 }
                else if j < y.count, i == x.count || lcs[i][j + 1] >= lcs[i + 1][j] { rows.append(Row(op: .insert, text: y[j])); j += 1 }
                else { rows.append(Row(op: .delete, text: x[i])); i += 1 }
            }
        }
        rows += a[ea...].map { Row(op: .equal, text: $0) }
        return rows
    }

    /// One changed stretch of the base: lines `start..<end` of the base became `lines`.
    private struct Hunk { var start: Int; var end: Int; var lines: [String] }

    private static func hunks(base: [String], other: [String]) -> [Hunk] {
        var result: [Hunk] = []
        var pos = 0
        var current: Hunk?
        for row in diff(base, other) {
            switch row.op {
            case .equal:
                if let h = current { result.append(h); current = nil }
                pos += 1
            case .delete:
                if current == nil { current = Hunk(start: pos, end: pos, lines: []) }
                current!.end += 1; pos += 1
            case .insert:
                if current == nil { current = Hunk(start: pos, end: pos, lines: []) }
                current!.lines.append(row.text)
            }
        }
        if let h = current { result.append(h) }
        return result
    }

    private static func apply(_ hs: [Hunk], to base: [String], from s: Int, to e: Int) -> [String] {
        var out: [String] = []
        var pos = s
        for h in hs {
            out += base[pos..<h.start]
            out += h.lines
            pos = h.end
        }
        out += base[pos..<e]
        return out
    }

    struct Merge {
        let lines: [String]
        /// Stretches changed differently on both sides; each is written with conflict markers.
        let conflicts: Int
        var text: String { lines.joined(separator: "\n") }
    }

    /// `base` is the text the edits started from, `mine` the unsaved text, `theirs` what is on disk now.
    /// Changes that do not touch the same lines are combined; the rest is marked like git does
    /// (`<<<<<<<`, `=======`, `>>>>>>>`).
    static func merge(base: [String], mine: [String], theirs: [String]) -> Merge {
        let mh = hunks(base: base, other: mine), th = hunks(base: base, other: theirs)
        var out: [String] = []
        var conflicts = 0
        var i = 0, j = 0, pos = 0

        func overlaps(_ a: Hunk, _ b: Hunk) -> Bool {
            a.start < b.end && b.start < a.end || a.start == b.start
        }

        while i < mh.count || j < th.count {
            let useMine = j >= th.count || (i < mh.count && mh[i].start <= th[j].start)
            let a = useMine ? mh[i] : th[j]
            let conflictsWithOther = useMine ? (j < th.count && overlaps(a, th[j])) : (i < mh.count && overlaps(a, mh[i]))
            out += base[pos..<a.start]
            if !conflictsWithOther {
                out += a.lines
                pos = a.end
                if useMine { i += 1 } else { j += 1 }
                continue
            }
            // Grow the region while hunks from either side touch it.
            var s = a.start, e = a.end
            var mi = i, ti = j
            var grew = true
            while grew {
                grew = false
                while mi < mh.count, mh[mi].start < e || mh[mi].start == s { e = max(e, mh[mi].end); mi += 1; grew = true }
                while ti < th.count, th[ti].start < e || th[ti].start == s { e = max(e, th[ti].end); ti += 1; grew = true }
            }
            s = min(s, a.start)
            let m = apply(Array(mh[i..<mi]), to: base, from: s, to: e)
            let t = apply(Array(th[j..<ti]), to: base, from: s, to: e)
            if m == t { out += m }
            else {
                conflicts += 1
                out += ["<<<<<<< " + "mine"] + m + ["======="] + t + [">>>>>>> " + "disk"]
            }
            pos = e
            i = mi; j = ti
        }
        out += base[pos...]
        return Merge(lines: out, conflicts: conflicts)
    }
}
