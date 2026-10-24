#!/usr/bin/env bash
# rebuild a tmux window layout from its pane rectangles
# source this file: source "${BASH_SOURCE%/*}/../_lib/layout.sh"

[[ -n "${_TMUX_LAYOUT_SH_LOADED:-}" ]] && return 0
_TMUX_LAYOUT_SH_LOADED=1

# turn pane rectangles into the split-window steps that rebuild them.
#
# tmux layouts are built from full-length cuts, so any group of panes either
# has vertical lines no pane crosses (columns) or horizontal ones (rows). the
# group's pane keeps the first column/row and each split creates a pane for
# the rest, recursively. the pane that keeps the first part always ends up as
# the top-left pane of its area, so a window's first pane is its top-left one
# and every new pane is named after the top-left pane of the area it ends up in
#
# sizes are percentages of the pane being split (split-window -l N%), so the
# steps rebuild the same proportions in a window of any size. percentages are
# rounded, so cells can be off by one
#
# input (stdin): one pane per line: <id> <left> <top> <width> <height>
# output: one split per line, in order: <split pane> <h|v> <percent> <new pane>
#   h = side by side (split-window -h), v = stacked (split-window -v)
# exits 1 if the rectangles aren't a tmux layout; any output is then partial
# and must be ignored
layout_splits() {
    awk '
        NF >= 5 {
            n++
            id[n] = $1; L[n] = $2; T[n] = $3; R[n] = $2 + $4; B[n] = $3 + $5
        }

        # bounds of a set of pane numbers ("1 4 5")
        function bounds(set,    m, k, p) {
            m = split(set, p, " ")
            minL = minT = 1e9; maxR = maxB = -1
            for (k = 1; k <= m; k++) {
                if (L[p[k]] < minL) minL = L[p[k]]
                if (T[p[k]] < minT) minT = T[p[k]]
                if (R[p[k]] > maxR) maxR = R[p[k]]
                if (B[p[k]] > maxB) maxB = B[p[k]]
            }
            return m
        }

        # top-left pane of a set
        function first(set,    m, k, p, best) {
            m = split(set, p, " ")
            best = p[1]
            for (k = 2; k <= m; k++)
                if (T[p[k]] < T[best] || (T[p[k]] == T[best] && L[p[k]] < L[best])) best = p[k]
            return best
        }

        # cut positions along an axis that no pane crosses, ascending.
        # a pane starting at c is past a cut there; one ending at c - 1 (the
        # border column/row) is before it
        function cuts(set, axis, lo, out,    m, k, j, p, c, ok, nc, seen) {
            m = split(set, p, " ")
            nc = 0
            for (k = 1; k <= m; k++) {
                c = (axis == "h") ? L[p[k]] : T[p[k]]
                if (c <= lo || (c in seen)) continue
                seen[c] = 1
                ok = 1
                for (j = 1; j <= m && ok; j++) {
                    if (axis == "h" && L[p[j]] < c && R[p[j]] >= c) ok = 0
                    if (axis == "v" && T[p[j]] < c && B[p[j]] >= c) ok = 0
                }
                if (ok) out[++nc] = c
            }
            # insertion sort, nc is tiny
            for (k = 2; k <= nc; k++)
                for (j = k; j > 1 && out[j - 1] > out[j]; j--) { c = out[j]; out[j] = out[j - 1]; out[j - 1] = c }
            return nc
        }

        function solve(set,    m, axis, lo, hi, nc, cut, k, j, c, p, child, rest, start, pct, holder, newp) {
            m = bounds(set)
            if (m == 1) return
            lo = minL; hi = maxR; axis = "h"
            nc = cuts(set, "h", lo, cut)
            if (nc == 0) {
                lo = minT; hi = maxB; axis = "v"
                nc = cuts(set, "v", lo, cut)
            }
            if (nc == 0) { bad = 1; return }

            # child k spans [cut[k-1], cut[k]) along the axis
            split(set, p, " ")
            for (k = 1; k <= nc + 1; k++) child[k] = ""
            for (j = 1; j <= m; j++) {
                c = (axis == "h") ? L[p[j]] : T[p[j]]
                for (k = 1; k <= nc && c >= cut[k]; k++) ;
                child[k] = child[k] " " p[j]
            }

            # the area from child k to the end is split into child k and the rest
            for (k = 1; k <= nc; k++) {
                rest = ""
                for (j = k + 1; j <= nc + 1; j++) rest = rest child[j]
                start = (k == 1) ? lo : cut[k - 1]
                pct = int(100 * (hi - cut[k]) / (hi - start) + 0.5)
                if (pct < 1) pct = 1
                if (pct > 99) pct = 99
                holder = first(child[k] rest)
                newp = first(rest)
                print id[holder], axis, pct, id[newp]
            }
            for (k = 1; k <= nc + 1; k++) solve(child[k])
        }

        END {
            if (n == 0) exit 0
            all = ""
            for (i = 1; i <= n; i++) all = all " " i
            solve(all)
            if (bad) exit 1
        }
    '
}
