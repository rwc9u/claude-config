#!/usr/bin/env ruby
# frozen_string_literal: true

# Convert a Spotify link to its Apple Music equivalent and open it in the Music app.
#
# Spotify and Apple Music use different catalog IDs, so there is no direct URL
# rewrite. This resolves the Spotify entity to clean title/artist metadata via the
# free Odesli (song.link) API, then looks up the exact Apple Music catalog item with
# the iTunes Search API to produce a direct deep link. A deep link is essential: an
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

require "json"
require "net/http"
require "uri"

ODESLI_ENDPOINT = "https://api.song.link/v1-alpha.1/links"
ITUNES_ENDPOINT = "https://itunes.apple.com/search"
SPOTIFY_HOST_RE = %r{\Ahttps?://open\.spotify\.com/}i
USER_AGENT = "spotify-to-apple-music-skill/1.0"

# Map Odesli entity types to the iTunes Search "entity" value and the result
# field that holds the direct Apple Music URL for that kind of item.
ITUNES_LOOKUP = {
  "song" => ["song", "trackViewUrl"],
  "album" => ["album", "collectionViewUrl"],
  "artist" => ["musicArtist", "artistViewUrl"],
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

def get_json(url, timeout: 20)
  uri = URI.parse(url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = uri.scheme == "https"
  http.open_timeout = timeout
  http.read_timeout = timeout
  request = Net::HTTP::Get.new(uri.request_uri, "User-Agent" => USER_AGENT)
  response = http.request(request)
  [response, JSON.parse(response.body)]
end

def resolve(spotify_url)
  query = URI.encode_www_form(url: spotify_url, userCountry: "US")
  response, data = get_json("#{ODESLI_ENDPOINT}?#{query}")
  unless response.is_a?(Net::HTTPSuccess)
    if response.code == "429"
      fail_with("Odesli rate limit hit (HTTP 429). Wait a moment and retry.")
    end
    fail_with("Odesli request failed: HTTP #{response.code}")
  end
  data
rescue SocketError, Timeout::Error, Errno::ECONNREFUSED => e
  fail_with("Could not reach the Odesli API: #{e.message}")
end

def entity_metadata(data)
  entity_id = data["entityUniqueId"]
  entity = data.dig("entitiesByUniqueId", entity_id) || {}
  [entity["title"], entity["artistName"], entity["type"]]
end

# Look up the exact Apple Music catalog item and return its direct URL.
#
# Returns nil when nothing matches or the lookup fails — callers fall back to a
# search URL. The artist is appended as a refinement; Apple Music's in-app search
# chokes on combined "title artist" strings (especially around '&'), but the
# iTunes Search API handles them fine and returns a precise deep link.
def itunes_deep_link(title, artist, entity_type)
  return nil if title.nil? || title.empty?

  entity_value, url_field = ITUNES_LOOKUP.fetch(entity_type, ["song", "trackViewUrl"])
  term = artist && !artist.empty? ? "#{title} #{artist}" : title
  params = URI.encode_www_form(term: term, entity: entity_value, limit: 5, country: "US")

  response, data = get_json("#{ITUNES_ENDPOINT}?#{params}")
  return nil unless response.is_a?(Net::HTTPSuccess)

  Array(data["results"]).each do |result|
    url = result[url_field]
    # Strip the affiliate/tracking suffix so the link opens cleanly.
    return url.sub(/[?&]uo=\d+\z/, "") if url && !url.empty?
  end
  nil
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
  data = resolve(spotify_url)

  platforms = data["linksByPlatform"] || {}
  apple = platforms["appleMusic"] || platforms["itunes"]
  title, artist, entity_type = entity_metadata(data)

  if apple && apple["url"]
    https_url = apple["url"]
    source = "direct Apple Music link (via Odesli)"
  elsif (deep_link = itunes_deep_link(title, artist, entity_type))
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
