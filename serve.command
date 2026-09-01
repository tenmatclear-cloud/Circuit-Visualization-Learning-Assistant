#!/bin/zsh
cd "$(dirname "$0")"
echo "Serving Circuit Visualization Learning Assistant at http://localhost:8080"
ruby server.rb
