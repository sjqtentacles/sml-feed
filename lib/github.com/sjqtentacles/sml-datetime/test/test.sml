(* Dependency-free test runner for the DateTime structure.
 * Prints one line per assertion and exits non-zero if any assertion fails. *)

val passed = ref 0
val failed = ref 0

fun check (name : string) (cond : bool) : unit =
    if cond
    then (passed := !passed + 1; print ("ok   - " ^ name ^ "\n"))
    else (failed := !failed + 1; print ("FAIL - " ^ name ^ "\n"))

fun raisesInvalid (thunk : unit -> 'a) : bool =
    (ignore (thunk ()); false)
    handle DateTime.Invalid _ => true | _ => false

structure D = DateTime

fun d (y, m, dd) = {year = y, month = m, day = dd}
fun tm (h, mi, s, n) = {hour = h, minute = mi, second = s, nano = n}
fun dt (y, mo, da, h, mi, s, n) = {date = d (y, mo, da), time = tm (h, mi, s, n)}

fun run () =
  let
    (* ---- leap years ---- *)
    val () = check "2000 is leap" (D.isLeapYear 2000)
    val () = check "1900 not leap" (not (D.isLeapYear 1900))
    val () = check "2024 is leap" (D.isLeapYear 2024)
    val () = check "2023 not leap" (not (D.isLeapYear 2023))
    val () = check "2100 not leap" (not (D.isLeapYear 2100))
    val () = check "1600 is leap" (D.isLeapYear 1600)

    (* ---- daysInMonth ---- *)
    val () = check "Jan 31" (D.daysInMonth (2023, 1) = 31)
    val () = check "Feb 28 non-leap" (D.daysInMonth (2023, 2) = 28)
    val () = check "Feb 29 leap" (D.daysInMonth (2024, 2) = 29)
    val () = check "Feb 28 century non-leap" (D.daysInMonth (1900, 2) = 28)
    val () = check "Apr 30" (D.daysInMonth (2023, 4) = 30)
    val () = check "Dec 31" (D.daysInMonth (2023, 12) = 31)
    val () = check "bad month raises" (raisesInvalid (fn () => D.daysInMonth (2023, 13)))

    (* ---- isValid ---- *)
    val () = check "valid date" (D.isValid (d (2024, 2, 29)))
    val () = check "invalid Feb 29 non-leap" (not (D.isValid (d (2023, 2, 29))))
    val () = check "invalid month 0" (not (D.isValid (d (2023, 0, 1))))
    val () = check "invalid month 13" (not (D.isValid (d (2023, 13, 1))))
    val () = check "invalid day 0" (not (D.isValid (d (2023, 1, 0))))
    val () = check "invalid day 32" (not (D.isValid (d (2023, 1, 32))))
    val () = check "invalid Apr 31" (not (D.isValid (d (2023, 4, 31))))

    (* ---- epoch day known values ---- *)
    val () = check "epoch day 1970-01-01 = 0" (D.toEpochDay (d (1970, 1, 1)) = 0)
    val () = check "epoch day 1970-01-02 = 1" (D.toEpochDay (d (1970, 1, 2)) = 1)
    val () = check "epoch day 1969-12-31 = ~1" (D.toEpochDay (d (1969, 12, 31)) = ~1)
    val () = check "epoch day 2000-01-01 = 10957" (D.toEpochDay (d (2000, 1, 1)) = 10957)
    val () = check "epoch day 2024-02-29" (D.toEpochDay (d (2024, 2, 29)) = 19782)
    val () = check "toEpochDay invalid raises"
                   (raisesInvalid (fn () => D.toEpochDay (d (2023, 2, 29))))

    (* ---- fromEpochDay round-trip over a wide range ---- *)
    val () = check "fromEpochDay 0" (D.fromEpochDay 0 = d (1970, 1, 1))
    val () = check "fromEpochDay ~1" (D.fromEpochDay ~1 = d (1969, 12, 31))
    val roundtripOk =
        let
          (* check every ~37 days from 1800-01-01 to ~2200 *)
          val start = D.toEpochDay (d (1800, 1, 1))
          val stop  = D.toEpochDay (d (2200, 12, 31))
          fun loop e =
              if e > stop then true
              else D.toEpochDay (D.fromEpochDay e) = e andalso loop (e + 37)
        in loop start end
    val () = check "epochDay round-trip 1800..2200 (step 37)" roundtripOk

    (* ---- addDays / diffDays ---- *)
    val () = check "addDays simple" (D.addDays (d (2023, 1, 1)) 31 = d (2023, 2, 1))
    val () = check "addDays across year" (D.addDays (d (2023, 12, 31)) 1 = d (2024, 1, 1))
    val () = check "addDays across leap day"
                   (D.addDays (d (2024, 2, 28)) 1 = d (2024, 2, 29))
    val () = check "addDays skips non-leap Feb 29"
                   (D.addDays (d (2023, 2, 28)) 1 = d (2023, 3, 1))
    val () = check "addDays negative" (D.addDays (d (2024, 1, 1)) ~1 = d (2023, 12, 31))
    val () = check "addDays 365 non-leap" (D.addDays (d (2023, 1, 1)) 365 = d (2024, 1, 1))
    val () = check "addDays 366 over leap" (D.addDays (d (2024, 1, 1)) 366 = d (2025, 1, 1))
    val () = check "addDays zero is identity" (D.addDays (d (2023, 6, 15)) 0 = d (2023, 6, 15))

    val () = check "diffDays one day" (D.diffDays (d (2023, 1, 2), d (2023, 1, 1)) = 1)
    val () = check "diffDays negative" (D.diffDays (d (2023, 1, 1), d (2023, 1, 2)) = ~1)
    val () = check "diffDays leap year span"
                   (D.diffDays (d (2025, 1, 1), d (2024, 1, 1)) = 366)
    val () = check "diffDays non-leap span"
                   (D.diffDays (d (2024, 1, 1), d (2023, 1, 1)) = 365)
    val () = check "diffDays self is 0" (D.diffDays (d (2023, 5, 5), d (2023, 5, 5)) = 0)

    (* ---- dayOfWeek (0 = Sunday) ---- *)
    val () = check "1970-01-01 is Thursday (4)" (D.dayOfWeek (d (1970, 1, 1)) = 4)
    val () = check "2000-01-01 is Saturday (6)" (D.dayOfWeek (d (2000, 1, 1)) = 6)
    val () = check "2024-02-29 is Thursday (4)" (D.dayOfWeek (d (2024, 2, 29)) = 4)
    val () = check "2023-12-25 is Monday (1)" (D.dayOfWeek (d (2023, 12, 25)) = 1)
    val () = check "1969-12-31 is Wednesday (3)" (D.dayOfWeek (d (1969, 12, 31)) = 3)

    (* ---- ISO format ---- *)
    val () = check "formatISO basic" (D.formatISO (d (2024, 2, 29)) = "2024-02-29")
    val () = check "formatISO pads" (D.formatISO (d (1, 1, 1)) = "0001-01-01")
    val () = check "formatISO zero-pad month/day" (D.formatISO (d (2023, 7, 4)) = "2023-07-04")

    (* ---- ISO parse ---- *)
    val () = check "parseISO basic" (D.parseISO "2024-02-29" = SOME (d (2024, 2, 29)))
    val () = check "parseISO round-trip"
                   (D.parseISO (D.formatISO (d (2023, 7, 4))) = SOME (d (2023, 7, 4)))
    val () = check "parseISO rejects invalid date" (D.parseISO "2023-02-29" = NONE)
    val () = check "parseISO rejects bad month" (D.parseISO "2023-13-01" = NONE)
    val () = check "parseISO rejects wrong separators" (D.parseISO "2023/01/01" = NONE)
    val () = check "parseISO rejects short month" (D.parseISO "2023-1-01" = NONE)
    val () = check "parseISO rejects non-numeric" (D.parseISO "20xx-01-01" = NONE)
    val () = check "parseISO rejects empty" (D.parseISO "" = NONE)
    val () = check "parseISO rejects garbage" (D.parseISO "hello" = NONE)
    val () = check "parseISO rejects extra field" (D.parseISO "2023-01-01-01" = NONE)

    (* format/parse round-trip across many dates *)
    val fmtRoundtripOk =
        let
          val start = D.toEpochDay (d (1950, 1, 1))
          val stop  = D.toEpochDay (d (2050, 12, 31))
          fun loop e =
              if e > stop then true
              else
                let val dt = D.fromEpochDay e
                in (D.parseISO (D.formatISO dt) = SOME dt) andalso loop (e + 53) end
        in loop start end
    val () = check "format/parse ISO round-trip 1950..2050 (step 53)" fmtRoundtripOk

    (* ====================================================================== *)
    (* Time of day                                                            *)
    (* ====================================================================== *)

    val () = check "midnight is 00:00:00.0" (D.midnight = tm (0, 0, 0, 0))
    val () = check "isValidTime midnight" (D.isValidTime (tm (0, 0, 0, 0)))
    val () = check "isValidTime end of day"
                   (D.isValidTime (tm (23, 59, 59, 999999999)))
    val () = check "isValidTime mid" (D.isValidTime (tm (12, 34, 56, 0)))
    val () = check "isValidTime rejects hour 24" (not (D.isValidTime (tm (24, 0, 0, 0))))
    val () = check "isValidTime rejects minute 60" (not (D.isValidTime (tm (0, 60, 0, 0))))
    val () = check "isValidTime rejects second 60" (not (D.isValidTime (tm (0, 0, 60, 0))))
    val () = check "isValidTime rejects nano 1e9" (not (D.isValidTime (tm (0, 0, 0, 1000000000))))
    val () = check "isValidTime rejects negative hour" (not (D.isValidTime (tm (~1, 0, 0, 0))))
    val () = check "isValidTime rejects negative nano" (not (D.isValidTime (tm (0, 0, 0, ~1))))

    val () = check "secondOfDay 00:00:00 = 0" (D.secondOfDay (tm (0, 0, 0, 0)) = 0)
    val () = check "secondOfDay 01:02:03 = 3723" (D.secondOfDay (tm (1, 2, 3, 0)) = 3723)
    val () = check "secondOfDay end of day = 86399"
                   (D.secondOfDay (tm (23, 59, 59, 0)) = 86399)
    val () = check "nanoOfDay 00:00:00.0 = 0" (D.nanoOfDay (tm (0, 0, 0, 0)) = 0)
    val () = check "nanoOfDay 01:02:03.000000004"
                   (D.nanoOfDay (tm (1, 2, 3, 4)) = 3723 * 1000000000 + 4)
    val () = check "nanoOfDay raises on invalid time"
                   (raisesInvalid (fn () => D.nanoOfDay (tm (25, 0, 0, 0))))

    val () = check "timeFromNanoOfDay 0 = midnight"
                   (D.timeFromNanoOfDay 0 = tm (0, 0, 0, 0))
    val () = check "timeFromNanoOfDay round-trips"
                   (D.timeFromNanoOfDay (D.nanoOfDay (tm (23, 59, 59, 123456789)))
                      = tm (23, 59, 59, 123456789))
    val () = check "timeFromNanoOfDay second boundary"
                   (D.timeFromNanoOfDay (3723 * 1000000000 + 4) = tm (1, 2, 3, 4))

    (* ====================================================================== *)
    (* Datetime <-> epoch second                                              *)
    (* ====================================================================== *)

    val () = check "isValidDateTime ok" (D.isValidDateTime (dt (2020, 2, 29, 12, 34, 56, 0)))
    val () = check "isValidDateTime bad date"
                   (not (D.isValidDateTime (dt (2023, 2, 29, 0, 0, 0, 0))))
    val () = check "isValidDateTime bad time"
                   (not (D.isValidDateTime (dt (2020, 1, 1, 24, 0, 0, 0))))

    val () = check "toEpochSecond 1970-01-01T00:00:00Z = 0"
                   (D.toEpochSecond (dt (1970, 1, 1, 0, 0, 0, 0)) = 0)
    val () = check "fromEpochSecond 0 = 1970-01-01T00:00:00"
                   (D.fromEpochSecond 0 = dt (1970, 1, 1, 0, 0, 0, 0))
    val () = check "toEpochSecond 2000-01-01T00:00:00Z = 946684800"
                   (D.toEpochSecond (dt (2000, 1, 1, 0, 0, 0, 0)) = 946684800)
    val () = check "fromEpochSecond 946684800 = 2000-01-01"
                   (D.fromEpochSecond 946684800 = dt (2000, 1, 1, 0, 0, 0, 0))
    val () = check "toEpochSecond drops sub-second"
                   (D.toEpochSecond (dt (1970, 1, 1, 0, 0, 0, 500000000)) = 0)
    val () = check "toEpochSecond 1969-12-31T23:59:59Z = ~1"
                   (D.toEpochSecond (dt (1969, 12, 31, 23, 59, 59, 0)) = ~1)
    val () = check "fromEpochSecond ~1 = 1969-12-31T23:59:59"
                   (D.fromEpochSecond ~1 = dt (1969, 12, 31, 23, 59, 59, 0))
    val () = check "epoch second of leap-day datetime 2020-02-29T12:34:56Z"
                   (D.toEpochSecond (dt (2020, 2, 29, 12, 34, 56, 0)) = 1582979696)
    val () = check "epoch-second round-trip leap day"
                   (D.fromEpochSecond (D.toEpochSecond (dt (2020, 2, 29, 12, 34, 56, 0)))
                      = dt (2020, 2, 29, 12, 34, 56, 0))
    val () = check "toEpochSecond raises on invalid"
                   (raisesInvalid (fn () => D.toEpochSecond (dt (2023, 2, 29, 0, 0, 0, 0))))

    val epochSecRoundtripOk =
        let
          fun loop s =
              if s > 2000000000 then true
              else D.toEpochSecond (D.fromEpochSecond s) = s andalso loop (s + 98765)
        in loop ~2000000000 end
    val () = check "epoch-second round-trip wide range" epochSecRoundtripOk

    (* ====================================================================== *)
    (* Durations                                                              *)
    (* ====================================================================== *)

    val () = check "durationFromSeconds" (D.durationFromSeconds 90 = {seconds = 90, nanos = 0})
    val () = check "durationToSeconds" (D.durationToSeconds {seconds = 90, nanos = 0} = 90)
    val () = check "normalizeDuration carries nanos"
                   (D.normalizeDuration (0, 1500000000) = {seconds = 1, nanos = 500000000})
    val () = check "normalizeDuration negative nanos floors"
                   (D.normalizeDuration (0, ~500000000) = {seconds = ~1, nanos = 500000000})
    val () = check "normalizeDuration already-normal identity"
                   (D.normalizeDuration (5, 250000000) = {seconds = 5, nanos = 250000000})

    val () = check "negateDuration whole" (D.negateDuration {seconds = 90, nanos = 0} = {seconds = ~90, nanos = 0})
    val () = check "negateDuration fractional"
                   (D.negateDuration {seconds = 0, nanos = 500000000} = {seconds = ~1, nanos = 500000000})
    val () = check "addDurations whole"
                   (D.addDurations ({seconds = 30, nanos = 0}, {seconds = 60, nanos = 0})
                      = {seconds = 90, nanos = 0})
    val () = check "addDurations carries"
                   (D.addDurations ({seconds = 0, nanos = 700000000}, {seconds = 0, nanos = 500000000})
                      = {seconds = 1, nanos = 200000000})
    val () = check "subDurations"
                   (D.subDurations ({seconds = 90, nanos = 0}, {seconds = 30, nanos = 0})
                      = {seconds = 60, nanos = 0})
    val () = check "subDurations borrows"
                   (D.subDurations ({seconds = 1, nanos = 0}, {seconds = 0, nanos = 500000000})
                      = {seconds = 0, nanos = 500000000})
    val () = check "scaleDuration whole"
                   (D.scaleDuration ({seconds = 90, nanos = 0}, 3) = {seconds = 270, nanos = 0})
    val () = check "scaleDuration fractional carries"
                   (D.scaleDuration ({seconds = 0, nanos = 500000000}, 3)
                      = {seconds = 1, nanos = 500000000})
    val () = check "scaleDuration by zero"
                   (D.scaleDuration ({seconds = 90, nanos = 5}, 0) = {seconds = 0, nanos = 0})

    (* addDuration / diff across boundaries *)
    val () = check "addDuration 90min across hour"
                   (D.addDuration (dt (2020, 1, 1, 0, 30, 0, 0), D.durationFromSeconds (90 * 60))
                      = dt (2020, 1, 1, 2, 0, 0, 0))
    val () = check "addDuration 90min across day"
                   (D.addDuration (dt (2020, 1, 1, 23, 30, 0, 0), D.durationFromSeconds (90 * 60))
                      = dt (2020, 1, 2, 1, 0, 0, 0))
    val () = check "addDuration negative across day"
                   (D.addDuration (dt (2020, 1, 2, 1, 0, 0, 0), D.durationFromSeconds (~(90 * 60)))
                      = dt (2020, 1, 1, 23, 30, 0, 0))
    val () = check "subDuration across day"
                   (D.subDuration (dt (2020, 1, 2, 1, 0, 0, 0), D.durationFromSeconds (90 * 60))
                      = dt (2020, 1, 1, 23, 30, 0, 0))
    val () = check "addDuration preserves and carries nanos"
                   (D.addDuration (dt (2020, 1, 1, 0, 0, 0, 700000000),
                                   {seconds = 0, nanos = 500000000})
                      = dt (2020, 1, 1, 0, 0, 1, 200000000))
    val () = check "addDuration across leap day"
                   (D.addDuration (dt (2020, 2, 28, 12, 0, 0, 0), D.durationFromSeconds 86400)
                      = dt (2020, 2, 29, 12, 0, 0, 0))

    val () = check "diff same-day seconds"
                   (D.diff (dt (2020, 1, 1, 0, 30, 0, 0), dt (2020, 1, 1, 0, 0, 0, 0))
                      = {seconds = 1800, nanos = 0})
    val () = check "diff across day = 5400s"
                   (D.diff (dt (2020, 1, 2, 1, 0, 0, 0), dt (2020, 1, 1, 23, 30, 0, 0))
                      = {seconds = 5400, nanos = 0})
    val () = check "diff negative"
                   (D.diff (dt (2020, 1, 1, 0, 0, 0, 0), dt (2020, 1, 1, 0, 30, 0, 0))
                      = {seconds = ~1800, nanos = 0})
    val () = check "diff self is zero"
                   (D.diff (dt (2020, 1, 1, 12, 0, 0, 0), dt (2020, 1, 1, 12, 0, 0, 0))
                      = {seconds = 0, nanos = 0})
    val () = check "diff sub-second"
                   (D.diff (dt (2020, 1, 1, 0, 0, 1, 0), dt (2020, 1, 1, 0, 0, 0, 500000000))
                      = {seconds = 0, nanos = 500000000})
    val () = check "addDuration inverts diff"
                   (let val a = dt (2021, 7, 4, 9, 15, 30, 0)
                        val b = dt (2019, 3, 1, 23, 45, 0, 0)
                    in D.addDuration (b, D.diff (a, b)) = a end)

    (* ====================================================================== *)
    (* ISO-8601 datetime parse / format                                       *)
    (* ====================================================================== *)

    val () = check "parseDateTimeISO epoch Z"
                   (D.parseDateTimeISO "1970-01-01T00:00:00Z" = SOME (dt (1970, 1, 1, 0, 0, 0, 0)))
    val () = check "parseDateTimeISO 2000 Z"
                   (D.parseDateTimeISO "2000-01-01T00:00:00Z" = SOME (dt (2000, 1, 1, 0, 0, 0, 0)))
    val () = check "parseDateTimeISO leap-day Z"
                   (D.parseDateTimeISO "2020-02-29T12:34:56Z" = SOME (dt (2020, 2, 29, 12, 34, 56, 0)))
    val () = check "formatDateTimeISO epoch"
                   (D.formatDateTimeISO (dt (1970, 1, 1, 0, 0, 0, 0)) = "1970-01-01T00:00:00Z")
    val () = check "formatDateTimeISO leap day"
                   (D.formatDateTimeISO (dt (2020, 2, 29, 12, 34, 56, 0)) = "2020-02-29T12:34:56Z")
    val () = check "formatDateTimeISO with fraction"
                   (D.formatDateTimeISO (dt (2020, 2, 29, 12, 34, 56, 500000000))
                      = "2020-02-29T12:34:56.5Z")
    val () = check "formatDateTimeISO trims fraction zeros"
                   (D.formatDateTimeISO (dt (2020, 1, 1, 0, 0, 0, 123000000))
                      = "2020-01-01T00:00:00.123Z")

    val () = check "parseDateTimeISO fractional .5"
                   (D.parseDateTimeISO "2020-02-29T12:34:56.5Z"
                      = SOME (dt (2020, 2, 29, 12, 34, 56, 500000000)))
    val () = check "parseDateTimeISO fractional 9 digits"
                   (D.parseDateTimeISO "2020-01-01T00:00:00.123456789Z"
                      = SOME (dt (2020, 1, 1, 0, 0, 0, 123456789)))
    val () = check "parseDateTimeISO +05:30 normalizes to UTC"
                   (D.parseDateTimeISO "2020-01-01T05:30:00+05:30"
                      = SOME (dt (2020, 1, 1, 0, 0, 0, 0)))
    val () = check "parseDateTimeISO -08:00 normalizes to UTC"
                   (D.parseDateTimeISO "1999-12-31T16:00:00-08:00"
                      = SOME (dt (2000, 1, 1, 0, 0, 0, 0)))
    val () = check "parseDateTimeISO offset with fraction"
                   (D.parseDateTimeISO "2020-01-01T05:30:00.250+05:30"
                      = SOME (dt (2020, 1, 1, 0, 0, 0, 250000000)))
    val () = check "parseDateTimeISO missing offset assumes UTC"
                   (D.parseDateTimeISO "2020-06-15T08:00:00" = SOME (dt (2020, 6, 15, 8, 0, 0, 0)))

    val () = check "parseDateTimeISO rejects bad date"
                   (D.parseDateTimeISO "2023-02-29T00:00:00Z" = NONE)
    val () = check "parseDateTimeISO rejects bad time"
                   (D.parseDateTimeISO "2020-01-01T24:00:00Z" = NONE)
    val () = check "parseDateTimeISO rejects missing T"
                   (D.parseDateTimeISO "2020-01-01 00:00:00Z" = NONE)
    val () = check "parseDateTimeISO rejects garbage"
                   (D.parseDateTimeISO "hello" = NONE)
    val () = check "parseDateTimeISO rejects empty" (D.parseDateTimeISO "" = NONE)
    val () = check "parseDateTimeISO rejects short fields"
                   (D.parseDateTimeISO "2020-1-01T00:00:00Z" = NONE)
    val () = check "parseDateTimeISO rejects bad offset"
                   (D.parseDateTimeISO "2020-01-01T00:00:00+5:30" = NONE)

    val dtFmtRoundtripOk =
        let
          fun loop s =
              if s > 1700000000 then true
              else
                let val x = D.fromEpochSecond s
                in (D.parseDateTimeISO (D.formatDateTimeISO x) = SOME x)
                   andalso loop (s + 987654) end
        in loop 0 end
    val () = check "datetime ISO format/parse round-trip" dtFmtRoundtripOk

    val dtFracRoundtripOk =
        let
          val samples =
              [ dt (1970, 1, 1, 0, 0, 0, 0)
              , dt (2020, 2, 29, 23, 59, 59, 999999999)
              , dt (1999, 12, 31, 16, 0, 0, 250000000)
              , dt (2000, 1, 1, 0, 0, 0, 1) ]
          fun ok x = D.parseDateTimeISO (D.formatDateTimeISO x) = SOME x
        in List.all ok samples end
    val () = check "datetime ISO round-trip with fractions" dtFracRoundtripOk
  in
    print ("\n" ^ Int.toString (!passed) ^ " passed, "
           ^ Int.toString (!failed) ^ " failed\n");
    OS.Process.exit (if !failed = 0 then OS.Process.success else OS.Process.failure)
  end

val () = run ()
