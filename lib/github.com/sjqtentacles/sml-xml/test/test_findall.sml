(* test_findall.sml -- findAll / byName traversal and DOM helpers. *)

structure FindAllTests =
struct
  structure X = Xml
  open Support

  fun isElemNamed nm node =
    case node of X.Element { name, ... } => name = nm | _ => false

  fun run () =
    let
      val doc = X.parse
        ("<library>"
         ^ "<shelf id=\"1\"><book>A</book><book>B</book></shelf>"
         ^ "<shelf id=\"2\"><book>C</book><note>n</note>"
         ^ "<sub><book>D</book></sub></shelf>"
         ^ "</library>")

      val _ = Harness.section "findAll by predicate, at depth"

      val books = X.findAll (isElemNamed "book") doc
      val () = Harness.checkInt "finds all 4 <book> across depths" (4, List.length books)

      val titles = List.map X.textContent books
      val () = Harness.checkStringList "book text in document order"
                 (["A", "B", "C", "D"], titles)

      val shelves = X.findAll (isElemNamed "shelf") doc
      val () = Harness.checkInt "finds 2 <shelf>" (2, List.length shelves)

      val () = Harness.checkInt "findAll includes the matching root"
                 (1, List.length (X.findAll (isElemNamed "library") doc))

      val _ = Harness.section "findAll with attribute predicate"

      val withId =
        X.findAll (fn n => Option.isSome (X.getAttr n "id")) doc
      val () = Harness.checkInt "two elements carry an id attr" (2, List.length withId)

      val _ = Harness.section "byName convenience + helpers"

      val () = Harness.checkInt "byName book == 4" (4, List.length (X.byName "book" doc))
      val () = Harness.checkStringList "byName note text" (["n"],
                 List.map X.textContent (X.byName "note" doc))
      val () = Harness.checkInt "no <missing> elements" (0, List.length (X.byName "missing" doc))

      val () = Harness.check "children of a shelf"
                 (List.length (X.children (hd (X.byName "shelf" doc))) = 2)
      val () = Harness.checkStringList "children of non-element is empty"
                 ([], List.map X.textContent (X.children (X.Text "x")))

      val _ = Harness.section "textContent gathers nested text + cdata"

      val () = Harness.checkString "textContent across nesting"
                 ( "one two three"
                 , X.textContent
                     (X.parse "<p>one <b>two</b><![CDATA[ three]]></p>") )
    in
      ()
    end
end
