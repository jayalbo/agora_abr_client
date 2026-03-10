#!/usr/bin/env bash
# Capture device logs to help debug "Bad executable" (error 85) and other launch failures.
# Usage: Connect your iPhone, unlock it, then run this script. In Xcode, Build & Run.
# Let it capture for 10–20 seconds, then Ctrl+C. Search the output file for:
#   dyld, Library not loaded, image not found, code sign, signature, launch failed

OUT="${1:-device_log.txt}"

echo "Capturing device logs to: $OUT"
echo "Connect your iPhone, unlock it, then Build & Run from Xcode. Press Ctrl+C when done."
echo ""

log stream --device 2>&1 | tee "$OUT"
