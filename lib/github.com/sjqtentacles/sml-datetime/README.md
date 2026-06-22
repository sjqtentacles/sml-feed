# sml-datetime

[![CI](https://github.com/sjqtentacles/sml-datetime/actions/workflows/ci.yml/badge.svg)](https://github.com/sjqtentacles/sml-datetime/actions/workflows/ci.yml)

Civil (proleptic Gregorian) date and time arithmetic for Standard ML: leap
years, day counting, epoch-day/epoch-second conversion, day-of-week, times of
day, UTC datetimes/instants, durations, and ISO-8601 parsing/formatting (dates
and datetimes).

`sml-datetime` is timezone-free, I/O-free, and deterministic -- it never reads
the wall clock. A `date` is a plain `{ year, month, day }` record, a `time` is
`{ hour, minute, second, nano }`, and a `datetime` pairs the two as an instant
in UTC. Conversions use Howard Hinnant's branch-free days-from-civil algorithm,
so there is no runtime dependency on the host's `Date`/`Time` structures, and
the arithmetic is exact for any year (including pre-1970 instants, which have
negative epoch days/seconds).

Sub-day totals (`nanoOfDay`), epoch seconds, and durations use `LargeInt.int`
so they stay exact even where the default `int` is 32-bit (e.g. MLton); the
small record fields (`hour`, `nano`, ...) remain plain `int`.

## Portability

Pure Standard ML using only the Basis library -- no FFI, no threads. Verified
on **MLton** and **Poly/ML**.

## Building and testing

```sh
make test        # build + run the suite under MLton (default)
make test-poly   # run the suite under Poly/ML
make all-tests   # run under both
make clean
```

## Installing with smlpkg

```sh
smlpkg add github.com/sjqtentacles/sml-datetime
smlpkg sync
```

Then reference the library basis from your own `.mlb`:

```
lib/github.com/sjqtentacles/sml-datetime/datetime.mlb
```

For Poly/ML, `use` the `datetime.sig` and `datetime.sml` sources in order.

## Usage

```sml
val leap = DateTime.isLeapYear 2024            (* true  *)
val dim  = DateTime.daysInMonth (2024, 2)      (* 29    *)

val day  = DateTime.toEpochDay {year=2000, month=1, day=1}   (* 10957 *)
val back = DateTime.fromEpochDay 0             (* {year=1970,month=1,day=1} *)

val nye  = DateTime.addDays {year=2023, month=12, day=31} 1  (* 2024-01-01 *)
val span = DateTime.diffDays ({year=2025,month=1,day=1},
                              {year=2024,month=1,day=1})     (* 366 *)

val dow  = DateTime.dayOfWeek {year=1970, month=1, day=1}    (* 4 = Thursday *)

val iso  = DateTime.formatISO {year=2024, month=2, day=29}   (* "2024-02-29" *)
val SOME dd = DateTime.parseISO "2024-02-29"
val NONE    = DateTime.parseISO "2023-02-29"   (* not a real date *)
```

`dayOfWeek` returns `0 = Sunday .. 6 = Saturday`. Invalid dates raise
`DateTime.Invalid` from `toEpochDay`/`daysInMonth` and yield `NONE`/`false`
from `parseISO`/`isValid`.

### Times, datetimes, and durations

```sml
(* A time is { hour, minute, second, nano }; a datetime pairs a date + time. *)
val t   = {hour=12, minute=34, second=56, nano=0}
val ok  = DateTime.isValidTime t                       (* true *)
val sod = DateTime.secondOfDay t                       (* 45296 *)

(* Datetimes are instants in UTC; convert to/from seconds since the epoch. *)
val noon = {date={year=2020,month=2,day=29}, time=t}
val secs = DateTime.toEpochSecond noon                 (* 1582979696 : LargeInt.int *)
val back = DateTime.fromEpochSecond 0
           (* {date={year=1970,month=1,day=1}, time=midnight} *)

(* Durations are signed { seconds, nanos } pairs, normalized to 0 <= nanos < 1e9. *)
val later = DateTime.addDuration (noon, DateTime.durationFromSeconds (90*60))
            (* 2020-02-29T14:04:56Z *)
val gap   = DateTime.diff (later, noon)                (* {seconds=5400, nanos=0} *)
val sum   = DateTime.addDurations (gap, DateTime.durationFromSeconds 600)
val tripled = DateTime.scaleDuration (gap, 3)

(* ISO-8601 datetimes: YYYY-MM-DDThh:mm:ss[.fff][Z|±hh:mm]. *)
val SOME a = DateTime.parseDateTimeISO "1970-01-01T00:00:00Z"   (* epoch 0 *)
val SOME b = DateTime.parseDateTimeISO "2020-01-01T05:30:00+05:30"
             (* normalized to 2020-01-01T00:00:00Z *)
val s      = DateTime.formatDateTimeISO noon           (* "2020-02-29T12:34:56Z" *)
```

`parseDateTimeISO` folds any trailing offset into UTC (a missing offset is
treated as UTC), and accepts 1-9 fractional-second digits.
`formatDateTimeISO` always emits UTC with a trailing `Z`, printing a fractional
part only when `nano <> 0` (trailing zeros trimmed). Both `toEpochSecond` and
`parseDateTimeISO` raise `DateTime.Invalid` / yield `NONE` on invalid inputs.

## API summary

### Dates

| Function | Description |
| --- | --- |
| `isLeapYear : int -> bool` | Gregorian leap-year test. |
| `daysInMonth : int * int -> int` | Days in `(year, month)`. |
| `isValid : date -> bool` | Whether a date is well-formed. |
| `toEpochDay : date -> int` | Days since 1970-01-01. |
| `fromEpochDay : int -> date` | Inverse of `toEpochDay`. |
| `addDays : date -> int -> date` | Shift by N days (may be negative). |
| `diffDays : date * date -> int` | Difference `a - b` in days. |
| `dayOfWeek : date -> int` | `0 = Sunday .. 6 = Saturday`. |
| `parseISO : string -> date option` | Strict `YYYY-MM-DD`. |
| `formatISO : date -> string` | Zero-padded `YYYY-MM-DD`. |

### Times, datetimes, durations

| Function | Description |
| --- | --- |
| `midnight : time` | `00:00:00.000000000`. |
| `isValidTime : time -> bool` | Whether a time is well-formed (`h 0-23`, `m/s 0-59`, `nano 0-999999999`). |
| `secondOfDay : time -> int` | Whole seconds since midnight. |
| `nanoOfDay : time -> LargeInt.int` | Nanoseconds since midnight. |
| `timeFromNanoOfDay : LargeInt.int -> time` | Inverse of `nanoOfDay`. |
| `isValidDateTime : datetime -> bool` | Date and time both well-formed. |
| `toEpochSecond : datetime -> LargeInt.int` | Seconds since 1970-01-01T00:00:00Z (drops sub-second). |
| `fromEpochSecond : LargeInt.int -> datetime` | Inverse (yields `nano = 0`). |
| `durationFromSeconds : LargeInt.int -> duration` | Whole-second duration. |
| `durationToSeconds : duration -> LargeInt.int` | Whole seconds, floored. |
| `normalizeDuration : LargeInt.int * LargeInt.int -> duration` | Normalize `(seconds, nanos)`. |
| `negateDuration : duration -> duration` | Negate. |
| `addDurations / subDurations : duration * duration -> duration` | Sum / difference. |
| `scaleDuration : duration * int -> duration` | Multiply by an integer factor. |
| `addDuration / subDuration : datetime * duration -> datetime` | Shift an instant. |
| `diff : datetime * datetime -> duration` | Difference `a - b`. |
| `parseDateTimeISO : string -> datetime option` | `YYYY-MM-DDThh:mm:ss[.fff][Z\|±hh:mm]`, normalized to UTC. |
| `formatDateTimeISO : datetime -> string` | UTC `YYYY-MM-DDThh:mm:ss[.fff]Z`. |

## License

MIT. See [LICENSE](LICENSE).
