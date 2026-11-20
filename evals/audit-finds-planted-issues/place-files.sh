#!/usr/bin/env bash
set -eu
cp -R "$(dirname "$0")/files/." .
# The planted code is stored as .fixture so security scanners don't report its
# deliberate bugs as the skill's own code. Give each file its real name back.
find . -name '*.fixture' -exec sh -c 'for f; do mv "$f" "${f%.fixture}"; done' sh {} +
