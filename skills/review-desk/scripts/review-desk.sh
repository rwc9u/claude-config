#!/bin/sh
# Entry point for review-desk.rb: installs watch's gems for whichever Ruby this shell resolves, then runs it.
set -e

dir=$(cd "$(dirname "$0")" && pwd)
export BUNDLE_GEMFILE="$dir/Gemfile"

if [ "$1" = watch ] && ! bundle check >/dev/null 2>&1; then
  echo "Installing review desk gems for $(ruby -e 'print RUBY_VERSION')..." >&2
  bundle install >&2
fi

exec ruby "$dir/review-desk.rb" "$@"
