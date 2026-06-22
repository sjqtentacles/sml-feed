(* examples/demo.sml

   A small tour of `sml-xml`. Built and run by `make example`. Parses a tiny
   namespaced document, queries it with the DOM helpers, and re-renders it. *)

fun line s = print (s ^ "\n")

val doc =
  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n\
  \<catalog xmlns=\"urn:store\" xmlns:m=\"urn:meta\">\n\
  \  <!-- two books -->\n\
  \  <book id=\"b1\"><title>SML &amp; You</title><m:tag>&#955;-calculus</m:tag></book>\n\
  \  <book id=\"b2\"><title>XML in &#x3bb;</title><note><![CDATA[raw <xml> ok]]></note></book>\n\
  \</catalog>"

val () = line "== sml-xml demo =="
val () = line ""

val dom = Xml.parse doc

(* ---- query ---- *)
val titles = List.map Xml.textContent (Xml.byName "title" dom)
val () = line ("titles      : " ^ String.concatWith " | " titles)

val books = Xml.byName "book" dom
val () = line ("book count  : " ^ Int.toString (List.length books))
val ids =
  List.mapPartial (fn b => Xml.getAttr b "id") books
val () = line ("book ids    : " ^ String.concatWith ", " ids)

val tags = Xml.byName "tag" dom
val () =
  List.app
    (fn t => line ("m:tag       : " ^ Xml.textContent t
                   ^ "  (ns=" ^ (case Xml.nsOf t of SOME u => u | NONE => "-") ^ ")"))
    tags

(* ---- round-trip ---- *)
val again = Xml.parse (Xml.render dom)
val () = line ("round-trips : " ^ Bool.toString (again = dom))

val () = line ""
val () = line "re-rendered:"
val () = line (Xml.render dom)
