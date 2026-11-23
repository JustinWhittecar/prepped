#!/usr/bin/env bash
# Runs every test/*_test.lua from the repo root; exits non-zero if any fails.
cd "$(dirname "$0")" || exit 1
status=0
for t in test/*_test.lua; do
  luajit "$t" || status=1
done
exit $status
