#!/bin/bash
cd "$(dirname "$0")"

if ! command -v node >/dev/null 2>&1; then
  echo "Node.js 20 oder neuer ist erforderlich."
  echo "Bitte Node.js von https://nodejs.org installieren und diese Datei erneut starten."
  read -r -p "Enter zum Beenden..."
  exit 1
fi

node_major="$(node -p 'Number(process.versions.node.split(".")[0])')"
if [ "$node_major" -lt 20 ]; then
  echo "Gefunden: Node.js $(node --version)"
  echo "Bitte Node.js 20 oder neuer installieren."
  read -r -p "Enter zum Beenden..."
  exit 1
fi

open "http://localhost:4173"
node scripts/serve.mjs
