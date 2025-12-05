#!/usr/bin/env bash
# Test script for inline RBS generation
# Runs Claude Code to add inline RBS annotations to lib/ files

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$SCRIPT_DIR"

# Clean previous output - remove lib and sig, copy fresh from standalone/lib
rm -rf lib sig
cp -r ../standalone/lib lib

# Run Claude Code to generate inline RBS
claude -p "Add inline RBS annotations to all Ruby files in lib/. Use rbs-inline comment syntax (# rbs_inline: enabled, #: for types). Use the ruby-rbs skill. Run rbs-inline and steep check to validate. Avoid using untyped where possible." \
  --append-system-prompt "You have access to the ruby-rbs skill at $PLUGIN_DIR/skills/ruby-rbs/SKILL.md - load it first."
