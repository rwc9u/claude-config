---
name: spotify-to-apple-music
description: This skill should be used when the user shares a Spotify link (open.spotify.com or spotify: URI) and asks to "open this in Apple Music", "play this in Apple Music", "convert this Spotify link to Apple Music", "find this on Apple Music", or otherwise wants a Spotify track, album, artist, or playlist opened in the Apple Music app on macOS.
---

# Spotify to Apple Music

Take a Spotify link, resolve it to its Apple Music equivalent, and open it in the
Apple Music app on macOS.

## When to Use

Invoke this skill when the user:
- Pastes a Spotify link and wants to listen in Apple Music
- Asks to convert or look up a Spotify track/album/artist on Apple Music
- Wants a Spotify URI (`spotify:track:...`) opened in the Music app

## How It Works

Spotify and Apple Music use different catalog IDs, so a link cannot be rewritten
directly. The script:

1. Resolves the Spotify entity to clean title/artist metadata via the free
   [Odesli / song.link](https://odesli.co) API (using Odesli's own Apple Music
   link when present).
2. Looks up the exact Apple Music catalog item with the **iTunes Search API** to
   build a direct deep link (e.g. `…/album/<name>/<id>?i=<track-id>`).
3. Opens that deep link via the `music://` scheme so the **Apple Music app**
   launches straight to the item rather than a browser.

A deep link is important: an in-app `search?term=` URL lands on the (usually
empty) **Library** scope rather than the Apple Music catalog, so a search URL is
only used as a last resort when no catalog match is found.

## How to Use

Run the script with the Spotify URL:

```bash
ruby skills/spotify-to-apple-music/scripts/spotify_to_apple_music.rb "<spotify-url>"
```

Accepted input forms:
- `https://open.spotify.com/track/<id>` (tracking params like `?si=...` are stripped)
- `https://open.spotify.com/album/<id>`, `/artist/<id>`, `/playlist/<id>`
- `spotify:track:<id>` URI form

### Options

- `--web` — open the `https://music.apple.com/...` URL in the default browser
  instead of launching the Apple Music app.
- `--print-only` — resolve and print the Apple Music URL without opening anything
  (useful for confirming the match before opening).

### Examples

```bash
# Resolve and open in the Apple Music app
ruby skills/spotify-to-apple-music/scripts/spotify_to_apple_music.rb \
  "https://open.spotify.com/track/0VjIjW4GlUZAMYd2vXMi3b"

# Just show the resolved link
ruby skills/spotify-to-apple-music/scripts/spotify_to_apple_music.rb \
  "https://open.spotify.com/album/1ATL5GLyefJaxhQzSPVrLX" --print-only
```

The script prints the resolved title/artist, whether it was a direct match or a
search fallback, and the Apple Music URL it opened.

## Notes

- Requires macOS (`open` command) and Ruby (standard library only — no gems).
- The Odesli API is unauthenticated and rate-limited; on HTTP 429 the script
  reports the limit so you can retry after a moment.
