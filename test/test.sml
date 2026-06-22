(* Tests for sml-feed: RSS 2.0 + Atom 1.0 parsing, generation, RFC date
   handling, cross-format conversion, and round-trips. Vectors are real RSS /
   Atom documents with RFC-822 (RSS) and RFC-3339 (Atom) dates. *)

structure Tests =
struct
  open Harness
  structure F = Feed

  (* ---- canonical vectors ------------------------------------------------- *)

  val rssDoc =
    "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n\
    \<rss version=\"2.0\">\n\
    \  <channel>\n\
    \    <title>Example Feed</title>\n\
    \    <link>http://example.org/</link>\n\
    \    <description>A sample feed</description>\n\
    \    <lastBuildDate>Mon, 06 Sep 2021 16:45:00 GMT</lastBuildDate>\n\
    \    <item>\n\
    \      <title>First post</title>\n\
    \      <link>http://example.org/1</link>\n\
    \      <description>The first item</description>\n\
    \      <pubDate>Mon, 06 Sep 2021 16:45:00 GMT</pubDate>\n\
    \      <guid>http://example.org/1</guid>\n\
    \    </item>\n\
    \    <item>\n\
    \      <title>Second post</title>\n\
    \      <link>http://example.org/2</link>\n\
    \      <description>The second item</description>\n\
    \      <pubDate>Tue, 07 Sep 2021 09:30:00 GMT</pubDate>\n\
    \      <guid>http://example.org/2</guid>\n\
    \    </item>\n\
    \  </channel>\n\
    \</rss>\n"

  val atomDoc =
    "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n\
    \<feed xmlns=\"http://www.w3.org/2005/Atom\">\n\
    \  <title>Example Feed</title>\n\
    \  <id>urn:example:feed</id>\n\
    \  <updated>2021-09-06T16:45:00Z</updated>\n\
    \  <link href=\"http://example.org/\"/>\n\
    \  <entry>\n\
    \    <title>First post</title>\n\
    \    <id>urn:example:1</id>\n\
    \    <updated>2021-09-06T16:45:00Z</updated>\n\
    \    <summary>The first item</summary>\n\
    \  </entry>\n\
    \  <entry>\n\
    \    <title>Second post</title>\n\
    \    <id>urn:example:2</id>\n\
    \    <updated>2021-09-07T09:30:00Z</updated>\n\
    \    <summary>The second item</summary>\n\
    \  </entry>\n\
    \</feed>\n"

  fun dt (y, mo, d, h, mi, s) : F.datetime =
    { date = { year = y, month = mo, day = d }
    , time = { hour = h, minute = mi, second = s, nano = 0 } }

  val d1 = dt (2021, 9, 6, 16, 45, 0)
  val d2 = dt (2021, 9, 7, 9, 30, 0)

  fun runAll () =
    let
      (* ---- RFC date helpers -------------------------------------------- *)
      val () = section "RFC-822 dates (RSS pubDate)"
      val () = checkString "format RFC-822"
                 ("Mon, 06 Sep 2021 16:45:00 GMT", F.formatRfc822 d1)
      val () = checkString "format RFC-822 (Tue)"
                 ("Tue, 07 Sep 2021 09:30:00 GMT", F.formatRfc822 d2)
      val () = checkBool "parse RFC-822 round-trips"
                 (true, F.parseRfc822 "Mon, 06 Sep 2021 16:45:00 GMT" = SOME d1)
      val () = checkBool "parse RFC-822 without day name"
                 (true, F.parseRfc822 "06 Sep 2021 16:45:00 GMT" = SOME d1)
      val () = checkBool "parse RFC-822 numeric offset +0000"
                 (true, F.parseRfc822 "Mon, 06 Sep 2021 16:45:00 +0000" = SOME d1)
      val () = checkBool "parse RFC-822 garbage -> NONE"
                 (true, F.parseRfc822 "not a date" = NONE)

      val () = section "RFC-3339 dates (Atom)"
      val () = checkString "format RFC-3339"
                 ("2021-09-06T16:45:00Z", F.formatRfc3339 d1)
      val () = checkBool "parse RFC-3339 round-trips"
                 (true, F.parseRfc3339 "2021-09-06T16:45:00Z" = SOME d1)

      (* ---- RSS parsing ------------------------------------------------- *)
      val rss = F.parseRss rssDoc
      val () = section "parseRss: channel fields"
      val () = checkString "title" ("Example Feed", #title rss)
      val () = checkString "link" ("http://example.org/", #link rss)
      val () = checkString "description" ("A sample feed", #description rss)
      val () = checkBool "channel updated (lastBuildDate)"
                 (true, #updated rss = SOME d1)
      val () = checkInt "item count" (2, List.length (#items rss))

      val it1 = List.nth (#items rss, 0)
      val it2 = List.nth (#items rss, 1)
      val () = section "parseRss: item fields"
      val () = checkString "item1 title" ("First post", #title it1)
      val () = checkString "item1 link" ("http://example.org/1", #link it1)
      val () = checkBool "item1 guid" (true, #id it1 = SOME "http://example.org/1")
      val () = checkBool "item1 summary"
                 (true, #summary it1 = SOME "The first item")
      val () = checkBool "item1 updated (pubDate)" (true, #updated it1 = SOME d1)
      val () = checkBool "item1 published none" (true, #published it1 = NONE)
      val () = checkString "item2 title" ("Second post", #title it2)
      val () = checkBool "item2 updated (pubDate)" (true, #updated it2 = SOME d2)

      (* ---- Atom parsing ------------------------------------------------ *)
      val atom = F.parseAtom atomDoc
      val () = section "parseAtom: feed fields"
      val () = checkString "title" ("Example Feed", #title atom)
      val () = checkString "link" ("http://example.org/", #link atom)
      val () = checkBool "feed updated" (true, #updated atom = SOME d1)
      val () = checkInt "entry count" (2, List.length (#items atom))

      val at1 = List.nth (#items atom, 0)
      val at2 = List.nth (#items atom, 1)
      val () = section "parseAtom: entry fields"
      val () = checkString "entry1 title" ("First post", #title at1)
      val () = checkBool "entry1 id" (true, #id at1 = SOME "urn:example:1")
      val () = checkBool "entry1 summary"
                 (true, #summary at1 = SOME "The first item")
      val () = checkBool "entry1 updated" (true, #updated at1 = SOME d1)
      val () = checkBool "entry2 updated" (true, #updated at2 = SOME d2)

      (* ---- auto-detect ------------------------------------------------- *)
      val () = section "parse: auto-detect root"
      val () = checkBool "detects <rss>" (true, F.parse rssDoc = rss)
      val () = checkBool "detects <feed>" (true, F.parse atomDoc = atom)

      (* ---- round-trips ------------------------------------------------- *)
      val () = section "round-trip: RSS -> toRss -> RSS"
      val () = checkBool "structurally equal"
                 (true, F.parseRss (F.toRss rss) = rss)

      val () = section "round-trip: Atom -> toAtom -> Atom"
      val () = checkBool "structurally equal"
                 (true, F.parseAtom (F.toAtom atom) = atom)

      (* ---- cross-format conversion ------------------------------------- *)
      (* The RSS model uses only fields Atom can also express, so RSS -> model
         -> Atom -> model is the identity on the model. *)
      val () = section "cross-format: RSS -> toAtom -> parseAtom"
      val () = checkBool "RSS model survives Atom round-trip"
                 (true, F.parseAtom (F.toAtom rss) = rss)

      (* ---- error handling ---------------------------------------------- *)
      val () = section "errors"
      val () = checkRaises "parseRss on Atom doc"
                 (fn () => F.parseRss atomDoc)
      val () = checkRaises "parse on non-XML"
                 (fn () => F.parse "this is not xml")
    in
      Harness.run ()
    end

  val run = runAll
end
