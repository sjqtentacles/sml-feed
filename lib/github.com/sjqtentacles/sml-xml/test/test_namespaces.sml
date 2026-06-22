(* test_namespaces.sml -- xmlns / xmlns:prefix declarations and resolution. *)

structure NamespaceTests =
struct
  structure X = Xml
  open Support

  fun run () =
    let
      val _ = Harness.section "prefixed namespace resolution"

      val dom = X.parse "<a xmlns:x=\"urn:foo\"><x:b/></a>"
      (* root <a> has no prefix and no default ns *)
      val () = Harness.check "root <a> has no namespace" (X.nsOf dom = NONE)
      val () = Harness.check "root local name is a" (X.localName dom = SOME "a")
      val () = Harness.check "xmlns:x declaration kept in attrs"
                 (X.getAttr dom "xmlns:x" = SOME "urn:foo")

      val bs = X.byName "b" dom
      val () = Harness.checkInt "found one <b>" (1, List.length bs)
      val () = Harness.check "b's local name is b (prefix stripped)"
                 (X.localName (hd bs) = SOME "b")
      val () = Harness.check "b's namespace resolves to urn:foo"
                 (X.nsOf (hd bs) = SOME "urn:foo")

      val _ = Harness.section "default namespace resolution"

      val dom2 = X.parse "<a xmlns=\"urn:def\"><b><c/></b></a>"
      val () = Harness.check "root inherits default ns"
                 (X.nsOf dom2 = SOME "urn:def")
      val () = Harness.check "child b inherits default ns"
                 (X.nsOf (hd (X.byName "b" dom2)) = SOME "urn:def")
      val () = Harness.check "grandchild c inherits default ns"
                 (X.nsOf (hd (X.byName "c" dom2)) = SOME "urn:def")

      val _ = Harness.section "nested / overriding declarations"

      val dom3 = X.parse
        "<r xmlns:p=\"urn:one\"><p:a><q:b xmlns:q=\"urn:two\"/></p:a></r>"
      val () = Harness.check "p:a resolves to urn:one"
                 (X.nsOf (hd (X.byName "a" dom3)) = SOME "urn:one")
      val () = Harness.check "q:b resolves to urn:two (declared inline)"
                 (X.nsOf (hd (X.byName "b" dom3)) = SOME "urn:two")

      val _ = Harness.section "unbound prefix is malformed"

      val () = Harness.checkRaises "unbound prefix raises"
                 (fn () => X.parse "<a><z:b/></a>")

      val _ = Harness.section "namespaces survive a round trip"

      val () = roundTrip "round-trip: prefixed ns"
                 "<a xmlns:x=\"urn:foo\"><x:b><x:c/></x:b></a>"
      val () = roundTrip "round-trip: default ns"
                 "<a xmlns=\"urn:def\"><b><c/></b></a>"
      val () = roundTrip "round-trip: nested overriding ns"
                 "<r xmlns:p=\"urn:one\"><p:a><q:b xmlns:q=\"urn:two\"/></p:a></r>"
    in
      ()
    end
end
