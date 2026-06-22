# sml-xml

A pure-Standard-ML **XML toolkit**: a recursive-descent parser, an in-memory
DOM, and a well-formed serializer, with XML-namespace support. No FFI, no C —
just the Basis Library plus one vendored pure-SML dependency. Deterministic and
byte-identical across [MLton](http://mlton.org/) and
[Poly/ML](https://www.polyml.org/).

Numeric character references are decoded to UTF-8 using the vendored
[`sml-unicode`](https://github.com/sjqtentacles/sml-unicode) codec, so `&#955;`
and `&#x3bb;` both round-trip as the bytes for U+03BB (λ).

## Features

- Elements, attributes (single- **or** double-quoted), and mixed text content
- Comments `<!-- ... -->` and CDATA sections `<![CDATA[ ... ]]>`, preserved verbatim
- The five predefined entities (`&lt; &gt; &amp; &quot; &apos;`) and numeric
  character references (`&#nn;`, `&#xhh;`) decoded to UTF-8
- Empty / self-closing tags (`<a/>` parses the same as `<a></a>`)
- `xmlns` / `xmlns:prefix` namespace declarations with prefix resolution: an
  element's `name` is its local name, `ns` is the resolved namespace URI
- A leading XML declaration `<?xml ... ?>`, processing instructions, and
  DOCTYPE markup are skipped
- Round-trip safe: `parse` → `render` → `parse` yields an equal DOM

## Installation

With [`smlpkg`](https://github.com/diku-dk/smlpkg):

```sh
smlpkg add github.com/sjqtentacles/sml-xml
smlpkg sync
```

Then reference `lib/github.com/sjqtentacles/sml-xml/...` from your `.mlb` (or
build directly from `src/xml.mlb`, which already pulls in the vendored
`sml-unicode`).

## The DOM type

```sml
datatype node =
    Element of { name     : string                 (* local element name *)
               , ns       : string option           (* resolved namespace URI *)
               , attrs    : (string * string) list  (* raw name, unescaped value *)
               , children : node list }
  | Text of string        (* character data, already unescaped *)
  | Comment of string     (* the text between <!-- and --> *)
  | CData of string        (* the text between <![CDATA[ and ]]> *)
```

## API

```sml
exception Xml of string

val parse    : string -> node          (* root element; raises Xml on malformed input *)
val parseOpt : string -> node option   (* NONE instead of raising *)
val render   : node -> string          (* well-formed, escaped, prefixes reconstructed *)

val findAll  : (node -> bool) -> node -> node list   (* pre-order, root included *)

(* DOM helpers *)
val byName      : string -> node -> node list  (* descendants with given local name *)
val children    : node -> node list
val getAttr     : node -> string -> string option
val localName   : node -> string option
val nsOf        : node -> string option
val textContent : node -> string               (* concatenated Text + CData *)

(* escaping primitives *)
val escapeText : string -> string   (* & < >        *)
val escapeAttr : string -> string   (* & < > "      *)
```

Malformed input (mismatched/unclosed tags, bad entities, unbound namespace
prefixes, unterminated comments/CDATA, a missing root, trailing junk) raises
`Xml msg`.

## Example

```sml
val dom = Xml.parse "<a xmlns:x=\"urn:foo\"><x:b>hi</x:b></a>"

val b = hd (Xml.byName "b" dom)
val () = print (Xml.textContent b)          (* "hi" *)
val () = print (valOf (Xml.nsOf b))         (* "urn:foo" *)

(* round-trips to an equal DOM *)
val same = (Xml.parse (Xml.render dom) = dom)   (* true *)
```

See [`examples/demo.sml`](examples/demo.sml) (`make example`) for a fuller tour
that parses a namespaced catalog, queries it, and re-renders it.

## Building & testing

```sh
make test        # build + run under MLton
make test-poly   # run under Poly/ML
make all-tests   # both compilers
make example     # build + run examples/demo.sml
```

Both compilers run the same strict-TDD suite under `test/`, covering: DOM shape
and the parse/render/parse fixed point; entity escaping/unescaping (named +
numeric, decimal and hex); namespace resolution (prefixed, default, nested
overrides, unbound-prefix errors); comments, CDATA, and self-closing
equivalence; and `findAll` / `byName` traversal at depth.

## License

[MIT](LICENSE).
