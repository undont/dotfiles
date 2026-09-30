# reformats docker compose --timestamps output for lazydocker
# input:  2026-05-14T16:16:11.814096093Z some message
# output: 05-14 16:16:11.814 some message
#
# lines that don't start with an RFC3339 timestamp pass through unchanged.
# fflush() per line keeps --follow streams live in the lazydocker panel

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
