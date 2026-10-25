#!/usr/bin/env bash
# Launch Bee Desktop Application
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd "$DIR"

echo "🐝 Launching Bee Desktop..."
npm start
