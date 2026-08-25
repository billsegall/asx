#!/bin/bash
# Nightly test-suite health check — invoked by cron at 1am AEST daily.
#
# Headless Claude Code run: runs each repo's own pytest suite as a read-only
# check, reports failures via push notification + a project memory note.
# Takes no other action (no edits, no fixes, no commits/pushes) — enforced
# both by the prompt below and by --disallowedTools as a backstop.
set -euo pipefail

PROMPT='Run the pytest test suite for each of three local repos as a read-only health check: first cd into /home/bill/code/asx/asx-web and run python3 -m pytest -q, then /home/bill/code/asx/asx-data and run the same command, then /home/bill/code/asx/asx-announcements and run the same command. This is report-only: do not edit any file, do not fix any failing test, do not create any commit, do not push. Known flaky test: asx-data has a live-network test named test_fundamentals_all_returns_list that occasionally times out transiently; if that is the only failure across all three suites, rerun just that single test once before deciding whether to count it as a real failure. If every suite passes cleanly, print a one-line summary and stop; do not send a notification and do not write a memory note. If any suite has a real failure: first send a PushNotification with a concise summary naming which repo and how many tests failed. Second, write a project memory note: create or overwrite the file /home/bill/.claude/projects/-home-bill-code-asx/memory/nightly_test_failures.md with frontmatter name nightly-test-failures, description a one-line summary noting this records the most recent nightly pytest failure, metadata type project, and a body listing todays date, which repo, which specific tests failed, and their pytest failure output. Then add or update a one-line pointer to that file in /home/bill/.claude/projects/-home-bill-code-asx/memory/MEMORY.md so it surfaces in the next real session.'

cd /home/bill/code/asx
/home/bill/.local/bin/claude -p "$PROMPT" \
    --dangerously-skip-permissions \
    --disallowedTools "Edit,NotebookEdit,Bash(git commit*),Bash(git push*),Bash(rm *),Bash(sudo *)" \
    --max-budget-usd 2
