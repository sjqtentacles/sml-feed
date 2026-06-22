(* feed.sml

   Unified RSS 2.0 / Atom 1.0 feed model over the vendored sml-xml DOM and
   sml-datetime instants. Pure and deterministic: element/attribute ordering on
   output is fixed and no system clock is consulted (timestamps come from the
   input data). Byte-identical under MLton and Poly/ML. *)

structure Feed :> FEED =
struct
  type datetime = DateTime.datetime

  type item =
    { title     : string
    , link      : string
    , id        : string option
    , summary   : string option
    , content   : string option
    , published : datetime option
    , updated   : datetime option
    , author    : string option }

  type feed =
    { title       : string
    , link        : string
    , description : string
    , updated     : datetime option
    , items       : item list }

  exception Feed of string

  val atomNs  = "http://www.w3.org/2005/Atom"
  val xmlDecl = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"

  (* ---- RFC date helpers -------------------------------------------------- *)

  val dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
  val monNames =
    ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
     "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

  fun pad2 n =
    let val s = Int.toString n
    in if String.size s >= 2 then s else "0" ^ s end

  fun nth (xs, i) = List.nth (xs, i)

  fun formatRfc822 (d : datetime) : string =
    let
      val { date, time } = d
      val { year, month, day } = date
      val { hour, minute, second, ... } = time
      val dow = nth (dayNames, DateTime.dayOfWeek date)
      val mon = nth (monNames, month - 1)
    in
      dow ^ ", " ^ pad2 day ^ " " ^ mon ^ " " ^ Int.toString year ^ " "
      ^ pad2 hour ^ ":" ^ pad2 minute ^ ":" ^ pad2 second ^ " GMT"
    end

  (* 1-based month index from an English abbreviation; raises on a bad name. *)
  fun monthIndex name =
    let
      fun go (_, []) = raise Feed "bad month"
        | go (i, m :: ms) = if m = name then i else go (i + 1, ms)
    in go (1, monNames) end

  (* Minutes east of UTC for an RFC-822 zone token; raises on an unknown one. *)
  fun tzOffsetMinutes tz =
    if tz = "GMT" orelse tz = "UT" orelse tz = "UTC" orelse tz = "Z" then 0
    else if String.size tz = 5
            andalso (String.sub (tz, 0) = #"+" orelse String.sub (tz, 0) = #"-")
    then
      let
        val sign = if String.sub (tz, 0) = #"-" then ~1 else 1
        val hh = valOf (Int.fromString (String.substring (tz, 1, 2)))
        val mm = valOf (Int.fromString (String.substring (tz, 3, 2)))
      in sign * (hh * 60 + mm) end
    else raise Feed "bad timezone"

  fun parseRfc822 s =
    let
      val ws = fn c => c = #" " orelse c = #"\t" orelse c = #"\r" orelse c = #"\n"
      val toks0 = String.tokens ws s
      (* drop a leading day-of-week token ("Mon,") if present *)
      val toks =
        case toks0 of
          (t :: rest) =>
            if String.size t > 0 andalso String.sub (t, String.size t - 1) = #","
            then rest else toks0
        | [] => []
    in
      case toks of
        [dd, mon, yyyy, hms, tz] =>
          ((let
              val day   = valOf (Int.fromString dd)
              val month = monthIndex mon
              val year  = valOf (Int.fromString yyyy)
              val parts = String.tokens (fn c => c = #":") hms
              val (h, mi, sec) =
                case parts of
                  [a, b, c] => (valOf (Int.fromString a),
                                valOf (Int.fromString b),
                                valOf (Int.fromString c))
                | _ => raise Feed "bad time"
              val off = tzOffsetMinutes tz
              val base : datetime =
                { date = { year = year, month = month, day = day }
                , time = { hour = h, minute = mi, second = sec, nano = 0 } }
            in
              if off = 0 then SOME base
              else SOME (DateTime.fromEpochSecond
                           (DateTime.toEpochSecond base
                            - LargeInt.fromInt (off * 60)))
            end) handle _ => NONE)
      | _ => NONE
    end

  fun formatRfc3339 (d : datetime) = DateTime.formatDateTimeISO d
  fun parseRfc3339 s = DateTime.parseDateTimeISO s

  (* ---- XML DOM helpers --------------------------------------------------- *)

  fun childElement name node =
    List.find
      (fn Xml.Element { name = n, ... } => n = name | _ => false)
      (Xml.children node)

  fun childElements name node =
    List.filter
      (fn Xml.Element { name = n, ... } => n = name | _ => false)
      (Xml.children node)

  fun childTextOpt name node =
    case childElement name node of
      SOME e => SOME (Xml.textContent e)
    | NONE => NONE

  fun getText name node =
    case childTextOpt name node of SOME t => t | NONE => ""

  fun hrefOf node =
    case childElement "link" node of
      SOME e => (case Xml.getAttr e "href" of SOME h => h | NONE => "")
    | NONE => ""

  fun parseDoc s =
    Xml.parse s handle Xml.Xml m => raise Feed ("malformed XML: " ^ m)

  fun rootName root =
    case Xml.localName root of
      SOME n => n
    | NONE => raise Feed "no root element"

  (* ---- RSS 2.0 ----------------------------------------------------------- *)

  fun parseRssItem node : item =
    { title     = getText "title" node
    , link      = getText "link" node
    , id        = childTextOpt "guid" node
    , summary   = childTextOpt "description" node
    , content   = NONE
    , published = NONE
    , updated   = (case childTextOpt "pubDate" node of
                     SOME t => parseRfc822 t | NONE => NONE)
    , author    = childTextOpt "author" node }

  fun parseRss s : feed =
    let
      val root = parseDoc s
      val () = if rootName root = "rss" then ()
               else raise Feed "not an RSS 2.0 document (root is not <rss>)"
      val channel =
        case childElement "channel" root of
          SOME c => c | NONE => raise Feed "RSS document has no <channel>"
      val chUpdated =
        case childTextOpt "lastBuildDate" channel of
          SOME t => parseRfc822 t
        | NONE => (case childTextOpt "pubDate" channel of
                     SOME t => parseRfc822 t | NONE => NONE)
    in
      { title       = getText "title" channel
      , link        = getText "link" channel
      , description = getText "description" channel
      , updated     = chUpdated
      , items       = List.map parseRssItem (childElements "item" channel) }
    end

  fun toRss (f : feed) : string =
    let
      fun textElem (name, s) =
        Xml.Element { name = name, ns = NONE, attrs = [], children = [Xml.Text s] }
      fun elem (name, attrs, children) =
        Xml.Element { name = name, ns = NONE, attrs = attrs, children = children }
      fun optText name vopt =
        case vopt of SOME v => [textElem (name, v)] | NONE => []
      fun optDate name dopt =
        case dopt of SOME d => [textElem (name, formatRfc822 d)] | NONE => []
      fun itemNode (it : item) =
        elem ("item", [],
          [ textElem ("title", #title it)
          , textElem ("link", #link it) ]
          @ optText "description" (#summary it)
          @ optDate "pubDate" (#updated it)
          @ optText "guid" (#id it)
          @ optText "author" (#author it))
      val channelChildren =
        [ textElem ("title", #title f)
        , textElem ("link", #link f)
        , textElem ("description", #description f) ]
        @ optDate "lastBuildDate" (#updated f)
        @ List.map itemNode (#items f)
      val rss =
        elem ("rss", [("version", "2.0")],
          [elem ("channel", [], channelChildren)])
    in
      xmlDecl ^ Xml.render rss ^ "\n"
    end

  (* ---- Atom 1.0 ---------------------------------------------------------- *)

  fun parseAtomEntry node : item =
    { title     = getText "title" node
    , link      = hrefOf node
    , id        = childTextOpt "id" node
    , summary   = childTextOpt "summary" node
    , content   = childTextOpt "content" node
    , published = (case childTextOpt "published" node of
                     SOME t => parseRfc3339 t | NONE => NONE)
    , updated   = (case childTextOpt "updated" node of
                     SOME t => parseRfc3339 t | NONE => NONE)
    , author    = (case childElement "author" node of
                     SOME a => childTextOpt "name" a | NONE => NONE) }

  fun parseAtom s : feed =
    let
      val root = parseDoc s
      val () = if rootName root = "feed" then ()
               else raise Feed "not an Atom 1.0 document (root is not <feed>)"
    in
      { title       = getText "title" root
      , link        = hrefOf root
      , description = getText "subtitle" root
      , updated     = (case childTextOpt "updated" root of
                         SOME t => parseRfc3339 t | NONE => NONE)
      , items       = List.map parseAtomEntry (childElements "entry" root) }
    end

  fun toAtom (f : feed) : string =
    let
      fun textElem (name, s) =
        Xml.Element { name = name, ns = NONE, attrs = [], children = [Xml.Text s] }
      fun elem (name, attrs, children) =
        Xml.Element { name = name, ns = NONE, attrs = attrs, children = children }
      fun optText name vopt =
        case vopt of SOME v => [textElem (name, v)] | NONE => []
      fun textElemNE (name, v) = if v = "" then [] else [textElem (name, v)]
      fun optDate name dopt =
        case dopt of SOME d => [textElem (name, formatRfc3339 d)] | NONE => []
      fun authorNode aopt =
        case aopt of
          SOME a => [elem ("author", [], [textElem ("name", a)])]
        | NONE => []
      fun linkNode href = elem ("link", [("href", href)], [])
      fun entryNode (it : item) =
        elem ("entry", [],
          [ textElem ("title", #title it)
          , linkNode (#link it) ]
          @ optText "id" (#id it)
          @ optDate "published" (#published it)
          @ optDate "updated" (#updated it)
          @ optText "summary" (#summary it)
          @ optText "content" (#content it)
          @ authorNode (#author it))
      val feedChildren =
        [ textElem ("title", #title f)
        , textElem ("id", #link f)   (* feed-level id synthesized from link *)
        , linkNode (#link f) ]
        @ textElemNE ("subtitle", #description f)
        @ optDate "updated" (#updated f)
        @ List.map entryNode (#items f)
      val feedEl =
        Xml.Element
          { name = "feed", ns = NONE
          , attrs = [("xmlns", atomNs)], children = feedChildren }
    in
      xmlDecl ^ Xml.render feedEl ^ "\n"
    end

  (* ---- auto-detect ------------------------------------------------------- *)

  fun parse s =
    let val root = parseDoc s
    in
      case rootName root of
        "rss"  => parseRss s
      | "feed" => parseAtom s
      | other  => raise Feed ("unrecognized feed root element <" ^ other ^ ">")
    end
end
