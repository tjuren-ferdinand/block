#!/usr/bin/env bash
# Run all tests: server suite + headless client logic suite + app smoke test.
set -e
cd "$(dirname "$0")/.."

echo "=== server tests ==="
(cd server && npm test)

echo "=== client logic tests ==="
godot --headless --path client --import >/dev/null 2>&1 || true
godot --headless --path client -s res://tests/run_tests.gd

echo "=== app smoke test ==="
godot --path client -- --smoke

echo "=== all green ==="
