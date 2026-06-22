(* test_escaping.sml -- entity decoding on parse, escaping on render. *)

structure EscapingTests =
struct
  structure X = Xml
  open Support

  (* UTF-8 byte string for codepoint, via the vendored unicode codec, so the
     expected values match exactly what the parser emits. *)
  fun utf8 cp = Unicode.encodeUtf8 [cp]

  fun textOf src =
    case X.parse src of
        X.Element { children = [X.Text s], ... } => s
      | _ => "<<unexpected>>"

  fun run () =
    let
      val _ = Harness.section "named entity decoding (parse)"

      val () = Harness.checkString "&lt; -> <" ("<", textOf "<a>&lt;</a>")
      val () = Harness.checkString "&gt; -> >" (">", textOf "<a>&gt;</a>")
      val () = Harness.checkString "&amp; -> &" ("&", textOf "<a>&amp;</a>")
      val () = Harness.checkString "&quot; -> dquote" ("\"", textOf "<a>&quot;</a>")
      val () = Harness.checkString "&apos; -> squote" ("'", textOf "<a>&apos;</a>")
      val () = Harness.checkString "mixed entities"
                 ("a<b>c&d", textOf "<a>a&lt;b&gt;c&amp;d</a>")

      val _ = Harness.section "numeric character references (parse)"

      (* U+0041 'A' decimal and hex *)
      val () = Harness.checkString "&#65; -> A" ("A", textOf "<a>&#65;</a>")
      val () = Harness.checkString "&#x41; -> A" ("A", textOf "<a>&#x41;</a>")
      (* U+03BB GREEK SMALL LETTER LAMBDA -> 2-byte UTF-8 *)
      val () = Harness.checkString "&#955; -> lambda" (utf8 0x3BB, textOf "<a>&#955;</a>")
      val () = Harness.checkString "&#x3bb; -> lambda" (utf8 0x3BB, textOf "<a>&#x3bb;</a>")
      val () = Harness.checkString "&#x3BB; uppercase hex" (utf8 0x3BB, textOf "<a>&#x3BB;</a>")
      (* U+1F600 GRINNING FACE -> 4-byte UTF-8 (supplementary plane) *)
      val () = Harness.checkString "&#128512; -> emoji" (utf8 0x1F600, textOf "<a>&#128512;</a>")

      val _ = Harness.section "attribute value entity decoding (parse)"

      val () = Harness.check "attr &amp; / &lt; / &quot; decode"
                 (X.getAttr (X.parse "<a t=\"x &amp; y &lt; z &quot;q&quot;\"/>") "t"
                  = SOME "x & y < z \"q\"")
      val () = Harness.check "single-quoted attr can hold dquote"
                 (X.getAttr (X.parse "<a t='say \"hi\"'/>") "t" = SOME "say \"hi\"")

      val _ = Harness.section "escaping on render"

      val () = Harness.checkString "render escapes text specials"
                 ( "<a>&lt;&gt;&amp;</a>"
                 , X.render (X.Element { name = "a", ns = NONE, attrs = [],
                                         children = [X.Text "<>&"] }) )
      val () = Harness.checkString "render escapes attribute specials"
                 ( "<a t=\"&lt;&amp;&quot;&gt;\"/>"
                 , X.render (X.Element { name = "a", ns = NONE,
                                         attrs = [("t", "<&\">")], children = [] }) )

      val _ = Harness.section "escape primitives"

      val () = Harness.checkString "escapeText" ("a&amp;b&lt;c&gt;d", X.escapeText "a&b<c>d")
      val () = Harness.checkString "escapeAttr" ("&quot;&amp;&lt;&gt;", X.escapeAttr "\"&<>")

      val _ = Harness.section "escaping survives a round trip"

      val () = roundTrip "round-trip: text with all specials"
                 "<a>&lt;tag&gt; &amp; \"quote\" 'apos'</a>"
      val () = roundTrip "round-trip: attribute with specials"
                 "<a t=\"&lt;x&gt; &amp; &quot;q&quot;\"/>"
    in
      ()
    end
end
