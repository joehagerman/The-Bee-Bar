#!/usr/bin/env bash
# Launch The Bee Bar Application
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd "$DIR"

echo "🐝 Launching The Bee Bar..."
npm start
