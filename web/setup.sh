#!/usr/bin/env bash
# Cocina Web — one-time setup script
# Run from inside the web/ directory: bash setup.sh

set -e

REQUIRED_RUBY="3.1"

echo "==> Checking Ruby version..."
RUBY_VER=$(ruby -e 'puts RUBY_VERSION' 2>/dev/null || echo "0")
MAJOR=$(echo "$RUBY_VER" | cut -d. -f1)
MINOR=$(echo "$RUBY_VER" | cut -d. -f2)

if [ "$MAJOR" -lt 3 ] || { [ "$MAJOR" -eq 3 ] && [ "$MINOR" -lt 1 ]; }; then
  echo ""
  echo "  Ruby $REQUIRED_RUBY+ is required (found $RUBY_VER)."
  echo ""
  echo "  Quickest fix on macOS:"
  echo "    brew install rbenv ruby-build"
  echo "    rbenv install 3.3.0"
  echo "    rbenv global 3.3.0"
  echo "    rbenv rehash"
  echo ""
  echo "  Then re-run: bash setup.sh"
  exit 1
fi

echo "  Ruby $RUBY_VER — OK"

echo "==> Installing bundler..."
gem install bundler --quiet

echo "==> Installing gems (bundle install)..."
bundle install

echo "==> Running migrations..."
bundle exec rails db:migrate

echo "==> Seeding default agents..."
ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY:-}" bundle exec rails cocina:seed_defaults

echo ""
echo "Done! Start the server with:"
echo "  bundle exec rails server"
echo ""
echo "Then open: http://localhost:3000"
