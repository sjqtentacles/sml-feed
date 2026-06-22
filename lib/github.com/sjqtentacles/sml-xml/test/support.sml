(* support.sml -- shared helpers for the XML test suites. *)

structure Support =
struct
  structure X = Xml

  (* A debug rendering of the DOM, used only for failure messages. *)
  fun show node =
    case node of
        X.Text s => "Text " ^ quote s
      | X.Comment s => "Comment " ^ quote s
      | X.CData s => "CData " ^ quote s
      | X.Element { name, ns, attrs, children } =>
          "Element{name=" ^ quote name
          ^ ", ns=" ^ (case ns of NONE => "-" | SOME u => quote u)
          ^ ", attrs=[" ^ String.concatWith ", "
              (List.map (fn (k, v) => k ^ "=" ^ quote v) attrs) ^ "]"
          ^ ", children=[" ^ String.concatWith ", " (List.map show children) ^ "]}"

  and quote s = "\"" ^ s ^ "\""

  (* Compare two DOM nodes for structural equality (the datatype admits
     equality), printing both sides on failure. *)
  fun checkNode name (expected, actual) =
    if expected = actual then Harness.check name true
    else
      ( Harness.check name false
      ; print ("       expected: " ^ show expected ^ "\n")
      ; print ("       actual:   " ^ show actual ^ "\n") )

  (* parse |> render |> parse should be a fixed point on the DOM. *)
  fun roundTrip name src =
    let
      val dom1 = X.parse src
      val dom2 = X.parse (X.render dom1)
    in
      checkNode name (dom1, dom2)
    end
end
