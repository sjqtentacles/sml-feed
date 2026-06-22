(* test_roundtrip.sml -- parse/render/parse fixed point, basic DOM shape,
   parseOpt, and XML-declaration skipping. *)

structure RoundTripTests =
struct
  structure X = Xml
  open Support

  fun run () =
    let
      val _ = Harness.section "basic DOM shape"

      val () = checkNode "simple element with text"
                 ( X.Element { name = "a", ns = NONE, attrs = [],
                               children = [X.Text "hello"] }
                 , X.parse "<a>hello</a>" )

      val () = checkNode "nested elements + attributes"
                 ( X.Element
                     { name = "root", ns = NONE, attrs = [("id", "1")],
                       children =
                         [ X.Element { name = "a", ns = NONE, attrs = [],
                                       children = [X.Text "x"] }
                         , X.Element { name = "b", ns = NONE,
                                       attrs = [("k", "v")], children = [] } ] }
                 , X.parse "<root id=\"1\"><a>x</a><b k=\"v\"/></root>" )

      val () = Harness.check "single-quoted attributes parse"
                 (X.getAttr (X.parse "<a k='v'/>") "k" = SOME "v")

      val _ = Harness.section "round-trip fixed point"

      val docs =
        [ "<a/>"
        , "<a></a>"
        , "<root><a>1</a><b>2</b></root>"
        , "<p>mixed <b>bold</b> and <i>italic</i> text</p>"
        , "<r id=\"1\" class=\"big\"><c x=\"y\"/></r>"
        , "<doc><!-- a comment --><body>text</body></doc>"
        , "<doc><![CDATA[raw <xml> & stuff]]></doc>"
        , "<a xmlns:x=\"urn:foo\"><x:b><x:c/></x:b></a>"
        , "<a xmlns=\"urn:def\"><b><c/></b></a>"
        , "<t>less &lt; greater &gt; amp &amp; quote &quot; apos &apos;</t>"
        , "<t>unicode &#955; and &#x3bb; here</t>" ]

      val () =
        List.app
          (fn d => roundTrip ("round-trip: " ^ d) d)
          docs

      val _ = Harness.section "XML declaration / prologue is skipped"

      val () = checkNode "skips <?xml ...?>"
                 ( X.Element { name = "r", ns = NONE, attrs = [], children = [] }
                 , X.parse "<?xml version=\"1.0\" encoding=\"UTF-8\"?><r/>" )

      val () = checkNode "skips leading comment + whitespace"
                 ( X.Element { name = "r", ns = NONE, attrs = [], children = [] }
                 , X.parse "  <!-- hi -->\n<r/>" )

      val _ = Harness.section "parseOpt / malformed input"

      val () = Harness.check "parseOpt SOME on well-formed"
                 (case X.parseOpt "<a/>" of SOME _ => true | NONE => false)
      val () = Harness.check "parseOpt NONE on mismatched tags"
                 (case X.parseOpt "<a></b>" of NONE => true | SOME _ => false)
      val () = Harness.checkRaises "parse raises on unclosed tag"
                 (fn () => X.parse "<a><b></a>")
      val () = Harness.checkRaises "parse raises on no root"
                 (fn () => X.parse "   ")
      val () = Harness.checkRaises "parse raises on bad entity"
                 (fn () => X.parse "<a>&bogus;</a>")
    in
      ()
    end
end
