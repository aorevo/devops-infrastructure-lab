#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV_DIR="$ROOT_DIR/.venv"
REQUIREMENTS="$ROOT_DIR/app/requirements.txt"

if [[ ! -f "$REQUIREMENTS" ]]; then
    echo "requirements.txt not found: $REQUIREMENTS"
    exit 1
fi

python3 -m venv "$VENV_DIR"

"$VENV_DIR/bin/python" -m pip install --upgrade pip
"$VENV_DIR/bin/python" -m pip install -r "$REQUIREMENTS"

echo "Dependencies installed."
echo "Activate environment:"
echo "source .venv/bin/activate"