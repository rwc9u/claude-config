---
name: denver-night-out
description: This skill should be used when the user asks "what live music is in Denver tonight", "what concerts are on in Denver", "any shows tonight", "what's going on at Denver breweries", "brewery events Thursday night", "find something to do in Denver tonight", or otherwise wants concerts, band shows, or brewery/taproom events in the Denver metro area for a specific night.
---

# Denver Night Out

Find live music and brewery events in the Denver metro for one specific night,
verified against venue and brewery sites rather than search snippets.

## Sources

`sources.yml` lists every site worth visiting and whether a plain fetch works on
it. Print it with the date filled into the URL templates:

```bash
ruby ~/.claude/skills/denver-night-out/scripts/list_sources.rb --date 2026-11-19
ruby ~/.claude/skills/denver-night-out/scripts/list_sources.rb --section breweries_west --fetch ok
```

Sections: `concert_listings`, `concert_venues`, `brewery_rosters`,
`breweries_central`, `breweries_east_north`, `breweries_south`,
`breweries_west`, `closed_breweries`. `--fetch blocked` shows the sites that
need a browser, the raw HTML, or an alternate source; the notes say which.

## Workflow

1. **Pin the date.** Resolve "tonight" / "Thursday" to a calendar date and its
   weekday first. If two parts of the request land on the same night, say so.
2. **Concerts: fetch, don't search.** Start with the two date-addressable
   listing pages (do303 by date, 303.show by month). Then confirm each headliner
   on the venue's own page, using the `fetch: ok` venues in `sources.yml`.
3. **Breweries: fan out by area.** There are ~150 in the metro, so run parallel
   agents, one per `breweries_*` section. Paste that section into the agent's
   brief as its starting roster, plus the `closed_breweries` list to skip, and
   have it check a `brewery_rosters` source for openings and closures since the
   last run. This is the expensive step: the first full pass took four agents
   10 to 19 minutes and roughly 230-250k tokens each. Say so before starting,
   and offer a single area if the user only cares about one part of town.
4. **Report** with the confirmed/unconfirmed split described below.

## Brief for each brewery agent

Each agent starts with no context, so the brief must include:

- The exact date and weekday.
- The neighborhoods and suburbs it owns, so batches do not overlap.
- Columns to return: brewery, area, event, time, whether the event is dated on
  the site or is a recurring weekly listing, source URL.
- Explicit values for the empty cases: "no event listed", "no calendar /
  social-only", "closed". No guessing.
- Third-party trivia directories are leads only, flagged as unverified.
- Closing counts: on roster, checked, with events, unreachable.

## Verification rules

- An aggregator listing is a lead. Mark an event confirmed only when the venue,
  promoter, or official ticket page shows it for that date.
- Many venue pages print "Thu, Nov 19" with no year. Check the weekday matches
  and that adjacent days look current before trusting it.
- When the venue's calendar loads and the show is missing, report the show as
  doubtful rather than dropping or repeating it.
- AEG venues (Mission, Gothic, Ogden, Bluebird) and AXS block plain fetches.
  Report them as agreed across listing sites but not venue-confirmed, or check
  in a browser.
- Do not guess venue domains. Guessed URLs redirected to unrelated sites or
  failed DNS; search for the venue's real site first.
- A venue that could not be loaded is "not checked", never "nothing on".
- Drop same-name hits from other cities (Denver, NC is a common one).
- Breweries close often. Confirm a brewery is open before listing its event.
- Multi-taproom breweries (Denver Beer Co, Cerebral, Resolute, Ratio, Odell,
  Downhill) share one events page. Attribute each event to the right taproom.
- Separate real events from food-truck-only listings and standing drink specials.

## Report format

Lead with counts, then tables. Split bigger shows from small rooms, and brewery
events dated on the site from recurring weekly ones. Always state how many
breweries were checked out of the roster and which sites could not be reached.
End with a Sources list.

## Maintaining sources.yml

After a run, update `sources.yml`: add newly useful sites, flip `fetch` when a
site starts or stops loading, mark closed breweries, and bump the
"Last verified" date.
