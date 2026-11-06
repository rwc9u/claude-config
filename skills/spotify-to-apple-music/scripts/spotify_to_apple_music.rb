#!/usr/bin/env ruby
# frozen_string_literal: true

# Convert a Spotify link to its Apple Music equivalent and open it in the Music app.
#
# Spotify and Apple Music use different catalog IDs, so there is no direct URL
# rewrite. This reads the title from Spotify's oEmbed endpoint and the artist from
# the public page's og:description, then looks up the exact Apple Music catalog item
# with the iTunes Search API to produce a direct deep link. A deep link is essential: an
# in-app "search" URL lands on the (usually empty) Library scope rather than the
# Apple Music catalog, so it is used only as a last resort.
#
# Usage:
#     spotify_to_apple_music.rb <spotify-url> [--web] [--print-only]
#
# Options:
#     --web         Open the https music.apple.com URL (default browser) instead of
#                   the music:// scheme that launches the Apple Music app.
#     --print-only  Resolve and print the Apple Music URL without opening anything.

require "cgi/escape"
require "json"
require "net/http"
require "uri"

SPOTIFY_OEMBED_ENDPOINT = "https://open.spotify.com/oembed"
ITUNES_ENDPOINT = "https://itunes.apple.com/search"
SPOTIFY_HOST_RE = %r{\Ahttps?://open\.spotify\.com/}i
USER_AGENT = "spotify-to-apple-music-skill/1.0"

# Map the Spotify URL kind to the iTunes Search "entity" value and the result
# fields holding the item's name and Apple Music URL. Playlists have no catalog match.
ITUNES_LOOKUP = {
  "track" => ["song", "trackName", "trackViewUrl"],
  "album" => ["album", "collectionName", "collectionViewUrl"],
  "artist" => ["musicArtist", "artistName", "artistLinkUrl"],
}.freeze

def fail_with(message)
  warn "Error: #{message}"
  exit 1
end

# Accept open.spotify.com URLs and spotify:track:... URIs; return an https URL.
def normalize_spotify_url(raw)
  raw = raw.strip.gsub(/\A["']|["']\z/, "")
  if raw.start_with?("spotify:")
    parts = raw.split(":")
    return "https://open.spotify.com/#{parts[1]}/#{parts[2]}" if parts.length >= 3

    fail_with("Unrecognized Spotify URI: #{raw}")
  end
  fail_with("Not a Spotify link: #{raw}") unless raw.match?(SPOTIFY_HOST_RE)

  # Drop tracking query params (e.g. ?si=...) that can confuse the resolver.
  parsed = URI.parse(raw)
  parsed.query = nil
  parsed.to_s
end

def http_get(url, timeout: 20)
  uri = URI.parse(url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = uri.scheme == "https"
  http.open_timeout = timeout
  http.read_timeout = timeout
  http.request(Net::HTTP::Get.new(uri.request_uri, "User-Agent" => USER_AGENT))
end

def get_json(url)
  response = http_get(url)
  [response, JSON.parse(response.body)]
end

def spotify_kind(spotify_url)
  URI.parse(spotify_url).path.split("/").reject(&:empty?).first
end

def spotify_title(spotify_url)
  query = URI.encode_www_form(url: spotify_url)
  response, data = get_json("#{SPOTIFY_OEMBED_ENDPOINT}?#{query}")
  fail_with("Spotify oEmbed request failed: HTTP #{response.code}") unless response.is_a?(Net::HTTPSuccess)

  data["title"]
end

# Track and album pages describe themselves as "Artist · Title · Song · 2026" and
# "Artist · album · 2018 · 25 songs", so the artist is the first segment.
def spotify_artist(spotify_url, kind)
  return nil unless %w[track album].include?(kind)

  response = http_get(spotify_url)
  return nil unless response.is_a?(Net::HTTPSuccess)

  description = response.body.force_encoding(Encoding::UTF_8)[/<meta property="og:description" content="([^"]*)"/, 1]
  return nil unless description

  CGI.unescapeHTML(description).split(" · ").first&.strip
end

def resolve(spotify_url)
  kind = spotify_kind(spotify_url)
  [spotify_title(spotify_url), spotify_artist(spotify_url, kind), kind]
rescue SocketError, Timeout::Error, Errno::ECONNREFUSED, JSON::ParserError => e
  fail_with("Could not read Spotify metadata: #{e.message}")
end

# Look up the exact Apple Music catalog item and return its direct URL.
#
# Returns nil when nothing matches or the lookup fails — callers fall back to a
# search URL. The artist is appended as a refinement; Apple Music's in-app search
# chokes on combined "title artist" strings (especially around '&'), but the
# iTunes Search API handles them fine and returns a precise deep link.
def itunes_deep_link(title, artist, kind)
  return nil if title.nil? || title.empty?
  return nil unless ITUNES_LOOKUP.key?(kind)

  entity_value, name_field, url_field = ITUNES_LOOKUP.fetch(kind)
  term = artist && !artist.empty? ? "#{title} #{artist}" : title
  params = URI.encode_www_form(term: term, entity: entity_value, limit: 5, country: "US")

  response, data = get_json("#{ITUNES_ENDPOINT}?#{params}")
  return nil unless response.is_a?(Net::HTTPSuccess)

  # iTunes often ranks remixes and features above the original, so prefer an exact name.
  candidates = Array(data["results"]).select { |result| result[url_field].to_s != "" }
  best = candidates.find { |result| result[name_field].to_s.casecmp?(title) } || candidates.first
  # Strip the affiliate/tracking suffix so the link opens cleanly.
  best && best[url_field].sub(/[?&]uo=\d+\z/, "")
rescue SocketError, Timeout::Error, Errno::ECONNREFUSED, JSON::ParserError
  nil
end

def apple_music_search_url(title, artist)
  term = [title, artist].compact.reject(&:empty?).join(" ")
  return nil if term.empty?

  "https://music.apple.com/us/search?term=#{URI.encode_www_form_component(term)}"
end

# Rewrite an https music.apple.com URL to the music:// scheme so macOS opens the
# Apple Music app instead of a browser.
def to_app_scheme(https_url)
  https_url.sub(%r{\Ahttps?://}, "music://")
end

def open_url(url)
  system("open", url, exception: true)
end

def main
  args = ARGV
  web = args.include?("--web")
  print_only = args.include?("--print-only")
  positionals = args.reject { |a| a.start_with?("--") }
  fail_with("Provide exactly one Spotify URL.") unless positionals.length == 1

  spotify_url = normalize_spotify_url(positionals.first)
  title, artist, kind = resolve(spotify_url)

  if (deep_link = itunes_deep_link(title, artist, kind))
    https_url = deep_link
    source = "direct Apple Music link (via iTunes lookup)"
  else
    https_url = apple_music_search_url(title, artist)
    fail_with("No Apple Music match and no metadata to build a search.") unless https_url
    source = "Apple Music search (no direct match found)"
  end

  label = [title, artist].compact.reject(&:empty?).join(" — ")
  label = spotify_url if label.empty?
  target = web ? https_url : to_app_scheme(https_url)

  puts label
  puts source
  puts target

  open_url(target) unless print_only
end

main if $PROGRAM_NAME == __FILE__
