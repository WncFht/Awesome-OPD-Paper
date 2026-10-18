#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
latex_compiler="${TECTONIC:-tectonic}"
mkdir -p build
"$latex_compiler" --keep-logs --keep-intermediates --outdir build main.tex
cp build/main.pdf main.pdf
