#!/usr/bin/env bash
# Test script for standalone RBS generation
# Runs Claude Code to generate .rbs files for lib/

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$SCRIPT_DIR"

# Clean previous output
rm -rf sig

# Run Claude Code to generate standalone RBS
claude -p "Write standalone RBS signatures for all Ruby files in lib/. Create sig/*.rbs files. Use the ruby-rbs skill. Run steep check to validate. Avoid using untyped where possible." \
  --append-system-prompt "You have access to the ruby-rbs skill at $PLUGIN_DIR/skills/ruby-rbs/SKILL.md - load it first."
