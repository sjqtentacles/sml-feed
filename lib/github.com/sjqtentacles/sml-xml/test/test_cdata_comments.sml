(* test_cdata_comments.sml -- comments, CDATA, and self-closing equivalence. *)

structure CDataCommentTests =
struct
  structure X = Xml
  open Support

  fun run () =
    let
      val _ = Harness.section "comments are preserved verbatim"

      val () = checkNode "comment node"
                 ( X.Element { name = "a", ns = NONE, attrs = [],
                               children = [X.Comment " a comment " ] }
                 , X.parse "<a><!-- a comment --></a>" )
      val () = Harness.check "comment text not entity-decoded"
                 (case X.parse "<a><!-- raw & < > --></a>" of
                      X.Element { children = [X.Comment c], ... } => c = " raw & < > "
                    | _ => false)

      val _ = Harness.section "CDATA is preserved verbatim"

      val () = checkNode "cdata node"
                 ( X.Element { name = "a", ns = NONE, attrs = [],
                               children = [X.CData "x < y & z > w"] }
                 , X.parse "<a><![CDATA[x < y & z > w]]></a>" )
      val () = Harness.check "cdata keeps markup-looking content"
                 (case X.parse "<a><![CDATA[<b>not a tag</b>]]></a>" of
                      X.Element { children = [X.CData c], ... } =>
                        c = "<b>not a tag</b>"
                    | _ => false)

      val _ = Harness.section "self-closing == open/close empty"

      val () = checkNode "<a/> equals <a></a>"
                 (X.parse "<a/>", X.parse "<a></a>")
      val () = checkNode "<a x=\"1\"/> equals <a x=\"1\"></a>"
                 (X.parse "<a x=\"1\"/>", X.parse "<a x=\"1\"></a>")
      val () = Harness.checkString "render of empty element is self-closing"
                 ( "<a/>"
                 , X.render (X.Element { name = "a", ns = NONE, attrs = [],
                                         children = [] }) )

      val _ = Harness.section "comments / CDATA survive a round trip"

      val () = roundTrip "round-trip: comment" "<a><!-- hi --></a>"
      val () = roundTrip "round-trip: cdata" "<a><![CDATA[a < b && c]]></a>"
      val () = roundTrip "round-trip: comment + cdata + text mix"
                 "<doc><!-- c -->text<![CDATA[<raw>]]>more</doc>"
    in
      ()
    end
end
