(* sml-feed demo: parse a small RSS 2.0 feed into the unified model, print the
   parsed fields, then convert it to Atom 1.0 and back. All inputs (including
   timestamps) are fixed, so the output is fully deterministic and byte-identical
   across MLton and Poly/ML. *)

fun line s = print (s ^ "\n")

val rss =
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n\
  \<rss version=\"2.0\">\n\
  \  <channel>\n\
  \    <title>SML Weekly</title>\n\
  \    <link>http://example.org/</link>\n\
  \    <description>News from the sjqtentacles ecosystem</description>\n\
  \    <lastBuildDate>Mon, 06 Sep 2021 16:45:00 GMT</lastBuildDate>\n\
  \    <item>\n\
  \      <title>sml-feed released</title>\n\
  \      <link>http://example.org/feed</link>\n\
  \      <description>A dual-compiler RSS + Atom toolkit</description>\n\
  \      <pubDate>Mon, 06 Sep 2021 16:45:00 GMT</pubDate>\n\
  \      <guid>http://example.org/feed</guid>\n\
  \    </item>\n\
  \    <item>\n\
  \      <title>sml-cose released</title>\n\
  \      <link>http://example.org/cose</link>\n\
  \      <description>COSE structures over sml-cbor</description>\n\
  \      <pubDate>Tue, 07 Sep 2021 09:30:00 GMT</pubDate>\n\
  \      <guid>http://example.org/cose</guid>\n\
  \    </item>\n\
  \  </channel>\n\
  \</rss>\n"

fun showOpt NONE = "(none)"
  | showOpt (SOME s) = s

fun showDate NONE = "(none)"
  | showDate (SOME d) = Feed.formatRfc3339 d

val () = line "sml-feed demo"
val () = line "============="

val f = Feed.parse rss

val () = line ("feed title   : " ^ #title f)
val () = line ("feed link    : " ^ #link f)
val () = line ("feed updated : " ^ showDate (#updated f))
val () = line ("items        : " ^ Int.toString (List.length (#items f)))
val () = line ""

fun showItem (it : Feed.item) =
  ( line ("- " ^ #title it)
  ; line ("    link      : " ^ #link it)
  ; line ("    guid/id   : " ^ showOpt (#id it))
  ; line ("    summary   : " ^ showOpt (#summary it))
  ; line ("    updated   : " ^ showDate (#updated it))
  ; line ("    pubDate   : " ^ (case #updated it of
                                  SOME d => Feed.formatRfc822 d
                                | NONE => "(none)")) )

val () = List.app showItem (#items f)

val () = line ""
val () = line "Converted to Atom 1.0:"
val () = line "----------------------"
val () = print (Feed.toAtom f)

val () = line ""
val () = line ("round-trips (RSS->Atom->model = original): "
               ^ Bool.toString (Feed.parseAtom (Feed.toAtom f) = f))
