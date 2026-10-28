#!/bin/bash
# The post-clean prompt (after_clean_menu): rescan or quit.
#
# What the assertions below are shaped around:
#
#   * the return value IS the control flow: the main loop rescans on 0 and exits
#     on 1, so every row here asserts the status, never the prompt text. Quit is
#     the default and has to be reached by every path that is not an explicit
#     `r` — an unknown key, Esc, and a closed stdin included. Nothing is at risk
#     in either direction (the clean has already run), so the failure worth
#     defending against is the loop that will not let go: a prompt that re-asks
#     on an unrecognized key, or one that spins forever on EOF.
#   * keys are read from fd 3, exactly as they are in the real run — cdm never
#     reads fd 0, which under `curl | bash` is the script itself. Each call
#     below redirects fd 3 from a here-document, so this exercises the same
#     read the tool uses rather than a stand-in.
#   * open(1) is shadowed by a function that records its argument, so the rows
#     below can assert the prompt never hands anything to the browser.

. "$(dirname "$0")/lib.sh"

# ---- local helpers ---------------------------------------------------------

T_OPEN_LOG="$HOME/open.log"
: > "$T_OPEN_LOG"

# Shadows open(1) for the rest of this file. Records what it was asked to open,
# one line per call, and reports success as the real one would.
open() { printf '%s\n' "$*" >> "$T_OPEN_LOG"; return 0; }

# t_menu <keys> — run the prompt with <keys> on fd 3, swallow the prompt text,
# echo its exit status. The keys go in as one string: each `read -n 1` takes the
# next character, so "bq" is two answers.
t_menu() {
    local rc
    after_clean_menu 3<<EOF >/dev/null 2>&1
$1
EOF
    rc=$?
    echo "$rc"
}

# t_menu_out <keys> — the same, but echoing what the prompt PRINTED, with the
# escapes stripped, so a row can assert on visible text.
t_menu_out() {
    after_clean_menu 3<<EOF 2>&1 | sed "s/$(printf '\033')\[[0-9;]*m//g"
$1
EOF
}

t_opened() { cat "$T_OPEN_LOG"; }
t_reset()  { : > "$T_OPEN_LOG"; }

# ---- the three answers -----------------------------------------------------

assert_eq "0" "$(t_menu r)" "r rescans"
assert_eq "0" "$(t_menu R)" "R rescans too"
assert_eq "1" "$(t_menu q)" "q quits"
assert_eq "1" "$(t_menu Q)" "Q quits too"

# Enter is the default answer and reaches `read -n 1` as the empty line
# delimiter, never as a literal CR — so an empty key IS Enter, the same way the
# main menu reads it.
assert_eq "1" "$(t_menu '')" "Enter takes the default (quit)"

# Anything unrecognized quits rather than re-asking. The clean has already run,
# so there is nothing to lose by leaving, and a prompt that will not accept an
# answer is worse than one that takes the wrong one.
assert_eq "1" "$(t_menu x)" "an unrecognized key takes the default (quit)"
assert_eq "1" "$(t_menu $'\033')" "Esc takes the default (quit)"

# No answer at all: a closed stdin, i.e. no terminal or a Ctrl-D. It must return,
# not spin — this is the case that would hang a piped run forever.
assert_eq "1" "$(after_clean_menu 3</dev/null >/dev/null 2>&1; echo $?)" \
    "EOF on fd 3 takes the default (quit)"

# Nothing above went anywhere near the browser.
assert_eq "" "$(t_opened)" "answering the prompt never opens anything on its own"

# `b` used to open a donate link; it is gone, so it is an unrecognized key now.
t_reset
assert_eq "1" "$(t_menu b)" "b is not a key — it takes the default (quit)"
assert_eq "" "$(t_opened)" "b opens nothing"

test_summary
