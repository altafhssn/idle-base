class_name Fmt
extends RefCounted
## Number formats for Dhaba Rush v0.3 (spec section 3.6; UX fix D6,
## docs/ux_audit/build-contract.md §3.2, 2026-10-22).
## Money is stored in REFERENCE units everywhere (first chai = 1.00) and shown
## multiplied by MONEY_DISPLAY_SCALE (first chai = Rs 10). Only the money
## helpers (money, price, sale, income, per_min, rupee, progress with money)
## apply the scale; time and per-minute counts do not.
##
## Two modes (static `indian`, set by Game from its saved "num_format": the
## device locale en_IN / hi_IN by default, a Settings toggle overrides):
## intl groups 1,234,567 and abbreviates with K / M / B / T / Qa / Qi;
## indian groups 12,34,567 and abbreviates with L (lakh) and Cr (crore) up
## to 999 Cr, then falls back to the intl suffixes on the rupee value. Never
## "K Cr", "L Cr" or "Cr Cr".
##
## Rules (applied to the DISPLAYED value d):
##   money/price/sale/rupee:
##     d < 1,000             2 decimals unless whole ("766.10", "500", "5")
##     1,000 <= d < 100,000  rounded whole, grouped ("1,500", "99,999")
##     d >= 100,000          3 significant digits + suffix: intl "100K",
##                           "1.23M", "999B" (no space); indian "1.00 L",
##                           "12.3 L", "999 Cr", from 1e10 "10.0B". A mantissa
##                           rounding to the next unit moves up ("1.00M");
##                           beyond 999Qi "1.00e21".
##   income:   < 1,000 always 2 decimals ("544.28"); >= 1,000 whole, grouped
##             ("1,500"); >= 100,000 suffix.
##   per_min:  rounded whole, grouped ("1,072"); >= 100,000 suffix.
##   secs:     "2 s", "1.95 s".  level: "Lv 25".  rate1: "12.0/min".
##   Negative values keep the leading "-".
##
## Hindi (launch blockers track B; Loc sets `hindi`): the same rules with the
## unit words in Hindi: lakh / crore "लाख" / "करोड़" ("2.50 लाख"), seconds
## "से॰", minutes "मिनट" ("12.0/मिनट"), level "लेवल 25". Digits stay 0-9 and
## the intl suffixes (K, M, B ...) stay Latin.

## Idle Business Kit: the scale is the pack economy's money_display_scale and
## the sign the pack's money.symbol (the dhaba: x10, "₹").
static var MONEY_DISPLAY_SCALE: float = ThemePack.money_display_scale()
static var CURRENCY: String = str(ThemePack.money().get("symbol", "$"))
const INT_FROM := 1000.0        # displayed values at/above this drop their decimals
const BIG_FROM := 100000.0      # 1 lakh / 100K: switch to suffixes
## intl suffixes from 1e3 up (only used from BIG_FROM); beyond Qi: "1.23e21".
const INTL_SUFFIX := ["K", "M", "B", "T", "Qa", "Qi"]
## Indian mode: lakh up to 1 crore, crore up to INDIAN_TOP, then intl.
const LAKH := 1.0e5
const CRORE := 1.0e7
const INDIAN_TOP := 1.0e10

## true: lakh / crore suffixes and 12,34,567 grouping (Game sets it).
static var indian: bool = false
## true: unit words in Hindi (Loc sets it with the language).
static var hindi: bool = false


static func set_indian(on: bool) -> void:
	indian = on


static func set_hindi(on: bool) -> void:
	hindi = on


## Unit words of the current language.
static func unit_s() -> String:
	return " से॰" if hindi else " s"


static func unit_min() -> String:
	return "/मिनट" if hindi else "/min"


## Reference units -> displayed rupees (float).
static func display(v: float) -> float:
	return v * MONEY_DISPLAY_SCALE


## HUD cash pill value (no currency sign; the pill has a note icon).
static func money(v: float) -> String:
	return _money_rule(v * MONEY_DISPLAY_SCALE)


## Prices and costs on buttons ("BUILD 2,000", "UPGRADE 25.50").
static func price(v: float) -> String:
	return _money_rule(v * MONEY_DISPLAY_SCALE)


## Floating sale number: price format, no "+" and no currency sign.
static func sale(v: float) -> String:
	return _money_rule(v * MONEY_DISPLAY_SCALE)


## Price with the rupee sign, for sentences ("Earn ₹1,000 for the dhaba").
static func rupee(v: float) -> String:
	return CURRENCY + _money_rule(v * MONEY_DISPLAY_SCALE)


## Income stat (MAX INCOME): below 1,000 always 2 decimals ("544.28",
## "300.00"); from 1,000 a whole grouped number ("1,500"); from 100,000 the
## suffix rule.
static func income(v: float) -> String:
	var d: float = v * MONEY_DISPLAY_SCALE
	var a: float = absf(d)
	var s: String
	var cents: int = int(roundf(a * 100.0))
	if cents < int(INT_FROM) * 100:
		@warning_ignore("integer_division")
		var whole: int = cents / 100
		var frac: int = cents % 100
		s = "%d.%02d" % [whole, frac]
	else:
		s = _whole_rule(a)
	return ("-" + s) if d < -0.005 else s


## HUD "/min" row: the rounded money rate ("1,072"), suffix from 100,000.
static func per_min(v: float) -> String:
	var d: float = v * MONEY_DISPLAY_SCALE
	var a: float = absf(d)
	var s: String = _whole_rule(a)
	return ("-" + s) if d <= -0.5 else s


## A countdown: "3:00", "10:00", "1:05:00" (whole seconds, rounded up).
static func clock(sec: float) -> String:
	var s: int = int(ceilf(maxf(0.0, sec)))
	if s >= 3600:
		return "%d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60]
	return "%d:%02d" % [s / 60, s % 60]


## Processing time: "2 s", "1.95 s" (no scale).
static func secs(v: float) -> String:
	var c: float = snappedf(v, 0.01)
	if _whole(c):
		return "%d" % int(roundf(c)) + unit_s()
	return "%.2f" % c + unit_s()


## Station level: "Lv 25" ("लेवल 25").
static func level(n: int) -> String:
	return ("लेवल %d" if hindi else "Lv %d") % n


## Galla rate: one decimal ("12.0/min") (no scale).
static func rate1(v: float) -> String:
	return "%.1f" % v + unit_min()


## Floor to a whole number ("24" for the galla header "24/MIN") (no scale).
static func int_floor(v: float) -> String:
	return group(int(floorf(v + 0.0001)))


## Plain count with Indian grouping (no scale).
static func count(n: int) -> String:
	return group(n)


## Percentage from a 0..1 ratio ("67%").
static func pct(ratio: float) -> String:
	return "%d%%" % int(roundf(ratio * 100.0))


## "n/max" counts ("SEATS 8/20", "WAITERS 1/3") (no scale).
static func frac(n: int, m: int) -> String:
	return "%s/%s" % [group(n), group(m)]


## Multiplier ("×1.05", "×1.10") - waiter speed (no scale).
static func mult(v: float) -> String:
	return "×%.2f" % v


## Gain of a multiplier as a percentage ("+5%" for 1.05, "+10.3%" for
## 1.1025) (no scale).
static func pct_gain(m: float) -> String:
	var p: float = snappedf((m - 1.0) * 100.0, 0.1)
	if _whole(p):
		return "%+d%%" % int(roundf(p))
	return "%+.1f%%" % p


## Short wait in seconds with one decimal below 10 ("4.2 s", "12 s") -
## AVG FOOD WAIT (no scale).
static func wait_secs(v: float) -> String:
	var a: float = maxf(0.0, v)
	if a < 9.95:
		return "%.1f" % a + unit_s()
	return "%d" % int(roundf(a)) + unit_s()


## Task bar "x/y". Money tasks show displayed rupees without decimals.
static func progress(p: float, target: float, is_money: bool = false) -> String:
	if is_money:
		var pd: float = minf(p, target) * MONEY_DISPLAY_SCALE
		return "%s/%s" % [int_floor(pd), _money_rule(target * MONEY_DISPLAY_SCALE)]
	return "%s/%s" % [int_floor(minf(p, target)), int_floor(target)]


## Digit grouping of the current mode: indian 1234567 -> "12,34,567",
## intl -> "1,234,567".
static func group(n: int) -> String:
	var s: String = str(absi(n))
	if s.length() > 3:
		var head: String = s.substr(0, s.length() - 3)
		var out: String = s.substr(s.length() - 3)
		var step: int = 2 if indian else 3
		while head.length() > step:
			out = head.substr(head.length() - step) + "," + out
			head = head.substr(0, head.length() - step)
		if head.length() > 0:
			out = head + "," + out
		s = out
	return ("-" + s) if n < 0 else s


## Suffix form of an already-DISPLAYED value (tests; the money rule's top
## band): below 100,000 a whole grouped number.
static func big(d: float) -> String:
	var s: String = _whole_rule(absf(d))
	return ("-" + s) if d <= -0.5 else s


# ---------------------------------------------------------------- internals
## Shared money/price rule on an already-scaled value.
static func _money_rule(d: float) -> String:
	var a: float = absf(d)
	var c: float = snappedf(a, 0.01)
	var s: String
	if c >= INT_FROM:
		s = _whole_rule(a)
	elif _whole(c):
		s = str(int(roundf(c)))
	else:
		s = "%.2f" % c
	return ("-" + s) if d < -0.005 else s


## Whole grouped number below BIG_FROM (after rounding), else the suffix rule.
static func _whole_rule(a: float) -> String:
	var r: float = roundf(a)
	if r < BIG_FROM:
		return group(int(r))
	return _big(a)


## Suffix rule for a >= BIG_FROM (displayed, non-negative).
static func _big(a: float) -> String:
	if indian and a < INDIAN_TOP:
		var t: String = _sig3(a, LAKH, CRORE, " लाख" if hindi else " L")
		if t != "":
			return t
		t = _sig3(a, CRORE, INDIAN_TOP, " करोड़" if hindi else " Cr")
		if t != "":
			return t
	var div: float = 1000.0
	for suf: String in INTL_SUFFIX:
		var u: String = _sig3(a, div, div * 1000.0, suf)
		if u != "":
			return u
		div *= 1000.0
	return _sci(a)


## Beyond the last suffix: "1.23e21" (GDScript's % has no %e).
static func _sci(a: float) -> String:
	var e: int = int(floorf(log(a) / log(10.0)))
	var m: float = roundf(a / pow(10.0, float(e)) * 100.0) / 100.0
	if m >= 10.0:
		m /= 10.0
		e += 1
	return "%.2fe%d" % [m, e]


## a / unit with 3 significant digits + suffix when a lies in [unit, next)
## after rounding ("" otherwise: the caller tries the next unit).
static func _sig3(a: float, unit: float, next: float, suffix: String) -> String:
	if a < unit * 0.9995:
		return ""
	var m: float = a / unit
	var r: float
	var fmt: String
	if m < 9.995:
		r = roundf(m * 100.0) / 100.0
		fmt = "%.2f"
	elif m < 99.95:
		r = roundf(m * 10.0) / 10.0
		fmt = "%.1f"
	else:
		r = roundf(m)
		fmt = "%.0f"
	if r * unit >= next * 0.99999:
		return ""
	return (fmt % r) + suffix


static func _whole(c: float) -> bool:
	return absf(c - roundf(c)) < 0.001
