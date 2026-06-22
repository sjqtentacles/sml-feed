# sml-feed

A unified **RSS 2.0** + **Atom 1.0** feed parser and generator in pure Standard
ML. One `feed` value reads from (and writes to) either syndication format, so
you can parse RSS and emit Atom (or vice versa) through a single model.

Built on the sjqtentacles ecosystem:

- XML parsing/serialization via vendored [`sml-xml`](https://github.com/sjqtentacles/sml-xml) (which itself vendors [`sml-unicode`](https://github.com/sjqtentacles/sml-unicode))
- Date/time instants via vendored [`sml-datetime`](https://github.com/sjqtentacles/sml-datetime)

No FFI, no system clock, no external dependencies — **deterministic** and
byte-identical under both [MLton](http://mlton.org/) and
[Poly/ML](https://www.polyml.org/). Timestamps are part of the input data, never
read from the environment, and element/attribute ordering on output is fixed.

## Status

- 37 assertions, green on MLton and Poly/ML (byte-identical output).
- Vendors `sml-xml` (+ `sml-unicode`) and `sml-datetime` (Layout B), so the repo
  builds standalone.
- RFC-conformant dates: RSS `pubDate`/`lastBuildDate` use **RFC 822**
  (`Mon, 06 Sep 2021 16:45:00 GMT`); Atom uses **RFC 3339**
  (`2021-09-06T16:45:00Z`). RFC-822 formatting/parsing is derived deterministically
  from the datetime fields (sml-datetime has no RFC-822 helper); RFC-3339 reuses
  `DateTime.formatDateTimeISO` / `parseDateTimeISO`.
- Round-trips: parsing then regenerating then re-parsing yields a structurally
  equal model, and the RSS model survives a full RSS → Atom → model conversion.

## Install

With [`smlpkg`](https://github.com/diku-dk/smlpkg):

```
smlpkg add github.com/sjqtentacles/sml-feed
smlpkg sync
```

The library MLB (`src/feed.mlb`) pulls in the vendored `sml-xml` (+ `sml-unicode`)
and `sml-datetime`, and brings `structure Feed` (alongside `Xml` and `DateTime`)
into scope.

## Quick start

```sml
(* parse either format; auto-detect by root element <rss> vs <feed> *)
val f = Feed.parse rssOrAtomString

val title = #title f
val n     = List.length (#items f)

(* convert between formats *)
val atomText = Feed.toAtom (Feed.parseRss rssText)
val rssText' = Feed.toRss  (Feed.parseAtom atomText)

(* RFC date helpers *)
val s = Feed.formatRfc822  someDatetime  (* "Mon, 06 Sep 2021 16:45:00 GMT" *)
val d = Feed.parseRfc3339  "2021-09-06T16:45:00Z"
```

## Demo

`make example` runs [`examples/demo.sml`](examples/demo.sml), parsing a small RSS
2.0 feed, printing the unified model, then converting it to Atom 1.0:

```
sml-feed demo
=============
feed title   : SML Weekly
feed link    : http://example.org/
feed updated : 2021-09-06T16:45:00Z
items        : 2

- sml-feed released
    link      : http://example.org/feed
    guid/id   : http://example.org/feed
    summary   : A dual-compiler RSS + Atom toolkit
    updated   : 2021-09-06T16:45:00Z
    pubDate   : Mon, 06 Sep 2021 16:45:00 GMT
- sml-cose released
    link      : http://example.org/cose
    guid/id   : http://example.org/cose
    summary   : COSE structures over sml-cbor
    updated   : 2021-09-07T09:30:00Z
    pubDate   : Tue, 07 Sep 2021 09:30:00 GMT

Converted to Atom 1.0:
----------------------
<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns="http://www.w3.org/2005/Atom"><title>SML Weekly</title><id>http://example.org/</id><link href="http://example.org/"/><subtitle>News from the sjqtentacles ecosystem</subtitle><updated>2021-09-06T16:45:00Z</updated><entry><title>sml-feed released</title><link href="http://example.org/feed"/><id>http://example.org/feed</id><updated>2021-09-06T16:45:00Z</updated><summary>A dual-compiler RSS + Atom toolkit</summary></entry><entry><title>sml-cose released</title><link href="http://example.org/cose"/><id>http://example.org/cose</id><updated>2021-09-07T09:30:00Z</updated><summary>COSE structures over sml-cbor</summary></entry></feed>

round-trips (RSS->Atom->model = original): true
```

## API

```sml
type datetime = DateTime.datetime

type item =
  { title     : string
  , link      : string
  , id        : string option   (* RSS <guid> / Atom <id> *)
  , summary   : string option   (* RSS <description> / Atom <summary> *)
  , content   : string option   (* Atom <content> *)
  , published : datetime option (* Atom <published> *)
  , updated   : datetime option (* Atom <updated> / RSS <pubDate> *)
  , author    : string option }

type feed =
  { title       : string
  , link        : string
  , description : string
  , updated     : datetime option
  , items       : item list }

exception Feed of string

val parseRss  : string -> feed
val parseAtom : string -> feed
val parse     : string -> feed     (* auto-detect <rss> vs <feed> *)

val toRss  : feed -> string
val toAtom : feed -> string

val formatRfc822  : datetime -> string         (* RSS pubDate, GMT *)
val parseRfc822   : string -> datetime option
val formatRfc3339 : datetime -> string          (* Atom, trailing Z *)
val parseRfc3339  : string -> datetime option
```

| Function | Behavior |
| --- | --- |
| `parse s` | inspect the root element: `<rss>` → `parseRss`, `<feed>` → `parseAtom`; raises `Feed` otherwise |
| `parseRss s` / `parseAtom s` | map the channel/feed element tree onto the unified model; raises `Feed` on malformed XML or wrong root |
| `toRss f` / `toAtom f` | render the model as a well-formed document with a fixed XML declaration and stable element ordering |
| `formatRfc822 d` | RFC-822 date in GMT, derived from the datetime fields and `DateTime.dayOfWeek` |
| `parseRfc822 s` | parse an RFC-822 date (day-of-week optional, `GMT`/`UT`/`Z` or numeric `±HHMM` offsets), folding the offset into UTC; `NONE` on failure |

### Field mapping

| Unified model | RSS 2.0 | Atom 1.0 |
| --- | --- | --- |
| feed `title` | `channel/title` | `feed/title` |
| feed `link` | `channel/link` (text) | `feed/link/@href` |
| feed `description` | `channel/description` | `feed/subtitle` |
| feed `updated` | `channel/lastBuildDate` (RFC 822) | `feed/updated` (RFC 3339) |
| item `link` | `item/link` (text) | `entry/link/@href` |
| item `id` | `item/guid` | `entry/id` |
| item `summary` | `item/description` | `entry/summary` |
| item `updated` | `item/pubDate` (RFC 822) | `entry/updated` (RFC 3339) |
| item `author` | `item/author` | `entry/author/name` |

Because the RSS model uses only fields Atom can also express, `parseRss` followed
by `toAtom`/`parseAtom` is the identity on the model.

## Build & test

```
make test        # MLton
make test-poly   # Poly/ML
make all-tests   # both
make example     # build + run examples/demo.sml
make clean
```

## Layout

```
src/feed.{sig,sml,mlb}                         the Feed facade
lib/github.com/sjqtentacles/sml-xml/...        vendored XML (+ sml-unicode)
lib/github.com/sjqtentacles/sml-datetime/...   vendored datetime
test/                                          harness + canonical vectors
examples/                                      deterministic demo
```

## License

MIT — see [LICENSE](LICENSE).
