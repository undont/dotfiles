#!/usr/bin/env bash
set -euo pipefail

# searchable key cheatsheet built from the -N notes on the live bindings.
# --list prints the rows without fzf

SCRIPT_DIR="${BASH_SOURCE%/*}"
source "$SCRIPT_DIR/../_lib/common.sh"

TABLES=(root prefix copy-mode-vi)

# prints "table<TAB>key<TAB>note" for each noted binding
list_notes() {
    local table
    for table in "${TABLES[@]}"; do
        tmux list-keys -T "$table" -F "#{key_table}	#{key_string}	#{key_note}" 2>/dev/null || true
    done
}

# reads list_notes rows on stdin and prints them under a heading per group,
# taken from the note's "group: " prefix. notes without one are tmux's own
# defaults and go last. rows end in a tab and headings start with one, so
# fzf's --nth=1 searches rows only
render() {
    local mod="$1"
    awk -F '\t' -v mod="$mod" '
        BEGIN {
            n_order = split("tabs panes scroll session tools", order, " ")
            title["tabs"] = "TABS"; title["panes"] = "PANES"
            title["scroll"] = "SCROLL MODE"; title["session"] = "SESSION"
            title["tools"] = "PICKERS / TOOLS"; title["defaults"] = "TMUX DEFAULTS"
        }
        $3 == "" { next }
        {
            note = $3
            group = "defaults"
            if (match(note, /^[a-z]+: /)) {
                group = substr(note, 1, RLENGTH - 2)
                note = substr(note, RLENGTH + 1)
            }
            key = $2
            gsub(/C-/, "Ctrl+", key)
            gsub(/M-/, mod "+", key)
            gsub(/S-/, "Shift+", key)
            if ($1 == "prefix") key = "` " key
            if (!(group in rows)) seen[++n_seen] = group
            rows[group] = rows[group] sprintf("  %-16s %s\t\n", key, note)
        }
        function show(g) {
            if (!(g in rows) || (g in shown)) return
            printf "%s\t\033[1m%s\033[0m\n%s", (n_shown++ ? "\n" : ""), (g in title ? title[g] : toupper(g)), rows[g]
            shown[g] = 1
        }
        END {
            for (i = 1; i <= n_order; i++) show(order[i])
            for (i = 1; i <= n_seen; i++) if (seen[i] != "defaults") show(seen[i])
            show("defaults")
        }'
}

if [[ "${1:-}" == "--list" ]]; then
    list_notes | render "$(mod_key)"
    exit 0
fi

load_fzf_theme

list_notes | render "$(mod_key)" | fzf \
    --ansi \
    --reverse \
    --delimiter='\t' \
    --nth=1 \
    --tabstop=1 \
    --exact \
    --no-sort \
    --disabled \
    --cycle \
    --prompt ': ' \
    --border=rounded \
    --border-label=' j/k ↓/↑ · g/G top/bottom · f/b · d/u · / search · q/esc quit ' \
    --border-label-pos=bottom \
    --bind 'j:down,k:up,g:first,G:last,q:abort' \
    --bind 'f:page-down,b:page-up' \
    --bind 'd:half-page-down,u:half-page-up' \
    --bind 'enter:abort' \
    --bind 'change:transform:[[ $FZF_PROMPT == ": " ]] && echo "clear-query"' \
    --bind '/:enable-search+change-prompt(> )+unbind(j,k,g,G,f,b,d,u,q)' \
    --bind 'esc:transform:[[ $FZF_PROMPT == "> " ]] && echo "disable-search+clear-query+change-prompt(: )+rebind(j,k,g,G,f,b,d,u,q)" || echo "abort"' \
    --bind 'ctrl-k:up,ctrl-l:clear-query' \
    >/dev/null || true
