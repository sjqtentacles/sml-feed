(* feed.sig

   A unified RSS 2.0 + Atom 1.0 feed model with parsers and generators for both
   formats, built on the vendored sml-xml DOM and sml-datetime instants.

   One `feed` value reads from (and writes to) either syndication format. Parsing
   maps the format-specific element trees onto the common model; generating walks
   the model back out to a well-formed XML document via `Xml.render`. Element and
   attribute ordering on output is fixed, so serialization is deterministic and
   byte-identical across MLton and Poly/ML.

   Dates are `DateTime.datetime` instants in UTC. RSS carries RFC-822 dates
   (`pubDate`, e.g. "Mon, 06 Sep 2021 16:45:00 GMT"); Atom carries RFC-3339 dates
   (`updated`/`published`, e.g. "2021-09-06T16:45:00Z"). Timestamps are part of
   the input data; nothing here reads the system clock. *)

signature FEED =
sig
  type datetime = DateTime.datetime

  (* A single feed entry. RSS <item> and Atom <entry> both map here. Fields are
     kept in this order on output; optional fields are emitted only when SOME. *)
  type item =
    { title     : string
    , link      : string
    , id        : string option   (* RSS <guid> / Atom <id> *)
    , summary   : string option   (* RSS <description> / Atom <summary> *)
    , content   : string option   (* Atom <content> *)
    , published : datetime option  (* Atom <published> *)
    , updated   : datetime option  (* Atom <updated> / RSS <pubDate> *)
    , author    : string option }

  (* The whole feed. RSS <channel> and the Atom <feed> root both map here. *)
  type feed =
    { title       : string
    , link        : string
    , description : string
    , updated     : datetime option
    , items       : item list }

  (* Raised on malformed input (bad XML, wrong root element, missing required
     channel/feed children). *)
  exception Feed of string

  (* Parse an RSS 2.0 document (root <rss>). *)
  val parseRss  : string -> feed
  (* Parse an Atom 1.0 document (root <feed>). *)
  val parseAtom : string -> feed
  (* Auto-detect by root element: <rss> -> parseRss, <feed> -> parseAtom. *)
  val parse     : string -> feed

  (* Serialize the model as an RSS 2.0 document (stable element ordering). *)
  val toRss  : feed -> string
  (* Serialize the model as an Atom 1.0 document (stable element ordering). *)
  val toAtom : feed -> string

  (* RFC-822 date used by RSS <pubDate>/<lastBuildDate>, always in GMT, e.g.
     "Mon, 06 Sep 2021 16:45:00 GMT". Formatted deterministically from the
     datetime fields (sml-datetime has no RFC-822 helper). *)
  val formatRfc822 : datetime -> string
  val parseRfc822  : string -> datetime option

  (* RFC-3339 date used by Atom, e.g. "2021-09-06T16:45:00Z". *)
  val formatRfc3339 : datetime -> string
  val parseRfc3339  : string -> datetime option
end
