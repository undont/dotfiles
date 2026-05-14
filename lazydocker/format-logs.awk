# Reformat docker compose --timestamps output for lazydocker.
# Input:  2026-05-14T16:16:11.814096093Z some message
# Output: 05-14 16:16:11.814 some message
#
# Lines that don't start with an RFC3339 timestamp pass through unchanged.
# fflush() per line so --follow streams stay live in the lazydocker panel.

{
    if (length($1) >= 20 && substr($1, 5, 1) == "-" && substr($1, 11, 1) == "T") {
        date = substr($1, 6, 5)
        rest = substr($1, 12)
        dot = index(rest, ".")
        if (dot > 0) {
            time = substr(rest, 1, dot - 1) "." substr(rest, dot + 1, 3)
        } else {
            time = substr(rest, 1, length(rest) - 1)
        }
        printf "%s %s %s\n", date, time, substr($0, length($1) + 2)
    } else {
        print
    }
    fflush()
}
