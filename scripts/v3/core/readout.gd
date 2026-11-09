extends RefCounted
## W1-SYSTEMS, module "readout" (plan 2.1 / 2.2; C2.4, C2.5, C2.6, C2.7):
## the single bottleneck source. Game delegates bottleneck_state(),
## bottleneck_rows(), bottleneck_fix(), road_line(), waiter_need() and
## station_help() here, and Game.signboard_offer() reads road_capped(); the
## NEXT chip, its ladder, the sheet banner and ribbons and the HUD meter all
## read the same numbers, so they never disagree.
##
## Rates are travellers (= whole orders) per minute. The four stages are
## "seats", "cooks", "waiters", "cashiers"; the road is the arrival cap.
## Live: from Game.live_caps() (the Sim's capacity_estimate(), the kitchen at
## traffic.ramp_station_k, the road at traffic.ramp_max_tpm + the signboard),
## else the model: Game.bottleneck_info()["rates"] (the road at
## travellers_per_min() + the signboard).
## W4-FIX-core: live SEATS = min(the seats' own rate, the arrival-room gate
## of C2.1, Game.room_rate_now()) when the room is clearly below the road
## (ROOM_MARGIN), so a seat-light dhaba reads SEATS / BUILD TABLE instead of
## the road; live_rates() hands the same numbers to Game's what-ifs (the
## signboard row, one more table).
## Labels, fix labels and the ribbon are English msgids (plan 5.1): the UI
## translates them (tr / UiKit.t). No class_name: Game loads this by path.
## Same-wave Game methods (W1-CORE) are reached by name only (plan rule 5).

## Seconds a computed state is reused (a purchase recomputes at once).
const CACHE_S := 0.5
## 5 Nov: the road's rate while it follows the dhaba (Game.road_follows): never the limit.
const FOLLOW_ROAD := 999.0
## = Game.BOTTLENECK_TIE: stages within 1 % of the minimum tie.
const TIE := 0.01
## Tie order of the four rows (= Game.BOTTLENECK_ORDER without "arrivals":
## waiters > seats > gallas > kitchen); the road loses every tie.
const ORDER := ["waiters", "seats", "cashiers", "cooks"]
## Row order of the readout (plan C2.6).
const STAGES := ["seats", "cooks", "waiters", "cashiers"]
const LABELS := {"seats": "SEATS", "cooks": "COOKS", "waiters": "WAITERS", "cashiers": "CASHIERS"}
const MAX_LABEL := "MAX"
const RIBBON := "Not the bottleneck now"
const FIX_LABELS := {
	"hire_waiters": "HIRE WAITER", "upgrade_waiters": "UPGRADE WAITER", "table": "BUILD TABLE",
	"hire_cashiers": "HIRE CASHIER", "upgrade_cashiers": "UPGRADE CASHIER", "cook": "HIRE COOK",
	"speed": "SPEED UP", "signboard": "SIGNBOARD", "level": "LEVEL UP",
}
## Fallbacks of traffic.ramp_max_tpm / traffic.ramp_station_k (economy_v3.json).
const ROAD_CAP_LIVE := 19.5
const STATION_K := 0.9
## W4-FIX-core: the room gate counts only when it is this share below the
## road: near the tie the road keeps the reading (no flicker; the arrivals
## realize ~0.92 of the road there anyway).
const ROOM_MARGIN := 0.03

var game: Node

var _rd: Dictionary = {}        # last rates: {rates, src, throughput, road_capped, limit, station}
var _rd_t: float = -INF
var _rd_ver: int = -1
var _state: Dictionary = {}     # last full state (bottleneck_state())
var _state_t: float = -INF
var _state_ver: int = -1
var _building: bool = false     # re-entrancy guard (Game what-ifs may call back)
var _building_t: float = 0.0
var _last_limit: String = "?"


# ================================================================ module interface (plan 2.2)
func setup(g: Node) -> void:
	game = g
	invalidate()


func save_dict() -> Dictionary:
	return {}


func load_dict(_d: Dictionary) -> void:
	invalidate()


func reset() -> void:
	invalidate()


func tick(_delta: float) -> void:
	pass


func on_launch() -> void:
	invalidate()


func on_resume(_away_s: float) -> void:
	invalidate()


func on_promoted(_kind: String) -> void:
	invalidate()


## Drops the cached rates and state (the next read recomputes).
func invalidate() -> void:
	_rd = {}
	_rd_t = -INF
	_state = {}
	_state_t = -INF


# ================================================================ public (Game delegates here)
## {limit ("seats"|"cooks"|"waiters"|"cashiers"|"", "" while the road is the
## limit), road_capped, rows (4, see bottleneck_rows), fix (bottleneck_fix),
## road (road_line), rates {seats, cooks, waiters, cashiers, road, throughput},
## src ("live"|"model"), throughput, station (the slowest counter)}.
## Computed at most once per CACHE_S (and again after any purchase).
func bottleneck_state() -> Dictionary:
	if game == null:
		return {}
	if _building:
		# A re-entrant call (a Game what-if reading the state while the fix
		# is built) gets the rates without a fix. A flag left over by a build
		# that died half-way (a script error) is dropped after a second.
		if _clock() - _building_t < 1.0 and _clock() >= _building_t:
			return _partial_state()
		_building = false
	if not _state.is_empty() and _fresh(_state_t, _state_ver):
		return _state.duplicate(true)
	_building = true
	_building_t = _clock()
	var rd: Dictionary = _rates_now()
	var rates: Dictionary = rd["rates"]
	var thr: float = float(rd["throughput"])
	var limit: String = str(rd["limit"])
	var station: String = str(rd["station"])
	var capped: bool = bool(rd["road_capped"])
	var rows: Array = []
	for s: String in STAGES:
		var rate: float = float(rates[s])
		rows.append({
			"stage": s, "label": str(LABELS[s]), "rate": rate,
			"use": clampf(thr / rate, 0.0, 1.0) if rate > 0.0 else 1.0,
			"limit": s == limit, "maxed": _maxed(s, station), "symptom": false,
			"fix": _fix_for(s, station),
		})
	var fix: Dictionary = _none("")
	if capped:
		fix = _road_fix(thr)
	elif limit != "":
		for rv in rows:
			var row: Dictionary = rv
			if str(row["stage"]) == limit:
				fix = (row["fix"] as Dictionary).duplicate()
				break
	var road: Dictionary = {
		"per_min": _arrivals_now(thr), "cap": float(rates["road"]), "capped": capped,
		"passed_last_min": int(_gcall("passed_last_min", [], 0)),
		"last_kind": str(_gcall("last_pass_kind", [], "")),
		"offer": (str(fix["kind"]) if str(fix["kind"]) in ["signboard", "level"] else "") if capped else "",
	}
	_state = {
		"limit": limit, "road_capped": capped, "rows": rows, "fix": fix, "road": road,
		"rates": rates.duplicate(), "src": str(rd["src"]), "throughput": thr, "station": station,
	}
	_state_t = _clock()
	_state_ver = _ver()
	_building = false
	var shown: String = "road" if capped else limit
	if shown != _last_limit:
		_last_limit = shown
		if OS.is_debug_build():
			print("[readout] limit %s src %s fix=%s" % [shown if shown != "" else "-", str(rd["src"]), str(fix["label"])])
	return _state.duplicate(true)


## The road (arrival cap) is the smallest rate: no stage within TIE of it.
## Cheap: reads the cached rates only, never builds the fix (Game's
## signboard_offer() calls this, and the fix calls signboard_offer()).
func road_capped() -> bool:
	if game == null:
		return false
	return bool(_rates_now().get("road_capped", false))


## 4 x {stage, label, use (0..1 = throughput / stage rate), limit (at most one,
## none while the road is the limit), maxed, symptom (false: the meter
## combines it with the NEXT chip's PROBLEM), fix (that stage's fix), rate}.
func bottleneck_rows() -> Array:
	return bottleneck_state().get("rows", [])


## The fix of the limit (or of the road): {kind "hire"|"upgrade"|"table"|
## "cook"|"speed"|"signboard"|"level"|"none", role ("waiters"|"cashiers"|""),
## station, index (waiter / cashier index; -1), cost, affordable, label
## (msgid, e.g. "HIRE WAITER"), stage ("waiters"|"seats"|"cashiers"|"cooks"|
## "road"|"")}.
func bottleneck_fix() -> Dictionary:
	var st: Dictionary = bottleneck_state()
	return st.get("fix", {"kind": "none"})


## {per_min (arrivals walking in now), cap (the road cap), capped,
## passed_last_min, last_kind ("lorry"|"car"|"auto"|"bus"|"baraat"|""),
## offer ("signboard"|"level"|"" : the road fix while the road is the limit)}.
## The UI composes the caption (plan 5.1).
func road_line() -> Dictionary:
	var st: Dictionary = bottleneck_state()
	var road: Dictionary = st.get("road", {})
	if road.is_empty():
		return {}
	# The drive-past fields move faster than the cache: read them live.
	road["passed_last_min"] = int(_gcall("passed_last_min", [], 0))
	road["last_kind"] = str(_gcall("last_pass_kind", [], ""))
	return road


## C2.4: {per (orders a minute one waiter carries = waiter rate / waiters),
## need (what the rest of the dhaba serves: the slowest of seats, kitchen,
## cashiers and the road), cap (the waiters' rate), waiters, needed
## (ceil(need / per)), enough (cap >= need)}.
func waiter_need() -> Dictionary:
	if game == null:
		return {}
	var rates: Dictionary = _rates_now()["rates"]
	var n: int = int(game.waiter_count())
	var cap: float = float(rates["waiters"])
	var per: float = cap / float(maxi(1, n))
	var need: float = minf(minf(float(rates["seats"]), float(rates["cooks"])), minf(float(rates["cashiers"]), float(rates["road"])))
	var needed: int = ceili(need / per) if per > 0.0 else 0
	return {"per": per, "need": need, "cap": cap, "waiters": n, "needed": needed, "enough": cap >= need}


## W4-FIX-core: the cached rates for Game's what-ifs (the BUILD signboard
## row, HISAAB's ONE MORE TABLE): {rates (a copy: seats, cooks, waiters,
## cashiers, road, throughput), src ("live"|"model"), road_capped, limit,
## seats_cap (the seats' own rate), room (the room gate's rate while it
## limits SEATS, else INF)}. Cheap: never builds the fix.
func live_rates() -> Dictionary:
	if game == null:
		return {}
	var rd: Dictionary = _rates_now()
	return {"rates": (rd["rates"] as Dictionary).duplicate(), "src": str(rd["src"]), "road_capped": bool(rd["road_capped"]),
			"limit": str(rd["limit"]), "seats_cap": float(rd.get("seats_cap", 0.0)), "room": float(rd.get("room", INF))}


## C2.5: kind "level" always helps (a price rise always raises takings: no
## ribbon); "speed" and "cook" (alias "hire") help only while the cooks are
## the limit and `id` is the slowest counter; otherwise {helps: false,
## ribbon: "Not the bottleneck now"}.
func station_help(id: String, kind: String) -> Dictionary:
	match kind:
		"speed", "cook", "cooks", "hire":
			if game == null:
				return {"helps": true, "ribbon": ""}
			var rd: Dictionary = _rates_now()
			if str(rd.get("limit", "")) == "cooks" and str(rd.get("station", "")) == id:
				return {"helps": true, "ribbon": ""}
			return {"helps": false, "ribbon": RIBBON}
	return {"helps": true, "ribbon": ""}


# ================================================================ rates
func _rates_now() -> Dictionary:
	if not _rd.is_empty() and _fresh(_rd_t, _rd_ver):
		return _rd
	var info: Dictionary = game.bottleneck_info()
	var station: String = str(info.get("station", ""))
	var live_v: Variant = _gcall("live_caps", [], {})
	var lc: Dictionary = live_v if live_v is Dictionary else {}
	var bonus: float = float(_gcall("signboard_bonus_tpm", [], 0.0))
	var r: Dictionary = {}
	var src: String = "model"
	var seats_cap: float = 0.0
	var room: float = INF
	# 5 Nov (owner): while the road follows the dhaba it is never the limit.
	var follows: bool = bool(_gcall("road_follows", [], false))
	if not lc.is_empty() and lc.has("waiters") and lc.has("stations"):
		src = "live"
		var k: float = clampf(float(game.traffic_value("ramp_station_k", STATION_K)), 0.1, 1.0)
		var road: float = FOLLOW_ROAD if follows else float(game.traffic_value("ramp_max_tpm", ROAD_CAP_LIVE)) + bonus
		seats_cap = _num(lc.get("seats", 0.0))
		# W4-FIX-core (C2.1): the arrival-room gate, when clearly below the road.
		var room_now: float = float(_gcall("room_rate_now", [], INF))
		if room_now > 0.0 and room_now < road * (1.0 - ROOM_MARGIN):
			room = room_now
		r = {
			"seats": minf(seats_cap, room), "cooks": _num(lc.get("stations", 0.0)) * k,
			"waiters": _num(lc.get("waiters", 0.0)), "cashiers": _num(lc.get("gallas", 0.0)),
			"road": road,
		}
	else:
		var br: Dictionary = info.get("rates", {})
		r = {
			"seats": _num(br.get("seats", 0.0)), "cooks": _num(br.get("kitchen", 0.0)),
			"waiters": _num(br.get("waiters", 0.0)), "cashiers": _num(br.get("gallas", 0.0)),
			"road": FOLLOW_ROAD if follows else float(game.travellers_per_min()) + bonus,
		}
		seats_cap = float(r["seats"])
	var lo_stage: float = INF
	for s: String in STAGES:
		lo_stage = minf(lo_stage, float(r[s]))
	var thr: float = minf(lo_stage, float(r["road"]))
	# The road is the limit only when no stage ties with it (the road loses
	# every tie, like "arrivals" in Game.BOTTLENECK_ORDER).
	var capped: bool = true
	for s: String in STAGES:
		if float(r[s]) <= thr * (1.0 + TIE) + 0.000001:
			capped = false
			break
	var limit: String = ""
	if not capped:
		for s: String in ORDER:
			if float(r[s]) <= lo_stage * (1.0 + TIE) + 0.000001:
				limit = s
				break
	r["throughput"] = thr
	_rd = {"rates": r, "src": src, "throughput": thr, "road_capped": capped, "limit": limit, "station": station,
			"seats_cap": seats_cap, "room": room}
	_rd_t = _clock()
	_rd_ver = _ver()
	return _rd


## A state built from the rates alone (no fix): what a re-entrant call gets
## while the full state is being built.
func _partial_state() -> Dictionary:
	if not _state.is_empty():
		return _state.duplicate(true)
	var rd: Dictionary = _rd if not _rd.is_empty() else _rates_now()
	return {
		"limit": str(rd["limit"]), "road_capped": bool(rd["road_capped"]), "rows": [], "fix": _none(""),
		"road": {}, "rates": (rd["rates"] as Dictionary).duplicate(), "src": str(rd["src"]),
		"throughput": float(rd["throughput"]), "station": str(rd["station"]),
	}


# ================================================================ fixes
func _fix(kind: String, role: String, station: String, index: int, cost: float, label: String, stage: String) -> Dictionary:
	return {
		"kind": kind, "role": role, "station": station, "index": index, "cost": cost,
		"affordable": kind != "none" and bool(game.can_afford(cost)), "label": label, "stage": stage,
	}


func _none(stage: String) -> Dictionary:
	return {"kind": "none", "role": "", "station": "", "index": -1, "cost": 0.0, "affordable": false, "label": "", "stage": stage}


## The fix of one stage ("none" when it is maxed). `station` = the slowest counter.
func _fix_for(stage: String, station: String) -> Dictionary:
	match stage:
		"waiters":
			if game.can_hire_waiter():
				return _fix("hire", "waiters", "", int(game.waiter_count()), float(game.waiter_hire_cost()),
						str(FIX_LABELS["hire_waiters"]), stage)
			var wi: int = _lowest_waiter()
			if wi >= 0:
				return _fix("upgrade", "waiters", "", wi, float(game.waiter_upgrade_cost(wi)),
						str(FIX_LABELS["upgrade_waiters"]), stage)
		"seats":
			if game.can_buy_table():
				return _fix("table", "", "", int(game.table_count()), float(game.table_cost()), str(FIX_LABELS["table"]), stage)
		"cashiers":
			if game.can_hire_galla():
				return _fix("hire", "cashiers", "", int(game.galla_count()), float(game.galla_hire_cost()),
						str(FIX_LABELS["hire_cashiers"]), stage)
			var gi: int = _lowest_galla()
			if gi >= 0:
				return _fix("upgrade", "cashiers", "", gi, float(game.galla_upgrade_cost(gi)),
						str(FIX_LABELS["upgrade_cashiers"]), stage)
		"cooks":
			if station != "" and game.is_built(station):
				if not game.hire_maxed(station):
					return _fix("cook", "", station, -1, float(game.hire_cost(station)), str(FIX_LABELS["cook"]), stage)
				if not game.proc_maxed(station):
					return _fix("speed", "", station, -1, float(game.proc_cost(station)), str(FIX_LABELS["speed"]), stage)
	return _none(stage)


## The road's fix: SIGNBOARD when Game's offer rule holds (never before the
## signboard is unlocked, i.e. the kadai), else LEVEL UP on the counter with
## the best payback.
func _road_fix(thr: float) -> Dictionary:
	var offer_v: Variant = _gcall("signboard_offer", [], {"offer": false})
	var offer: Dictionary = offer_v if offer_v is Dictionary else {}
	var open: bool = bool(_gcall("signboard_unlocked", [], false))
	if bool(offer.get("offer", false)) and open:
		var cost: float = float(offer.get("cost", _gcall("signboard_cost", [], 0.0)))
		return _fix("signboard", "", "", -1, cost, str(FIX_LABELS["signboard"]), "road")
	var lv: String = _best_level_station(thr)
	if lv != "":
		return _fix("level", "", lv, -1, float(game.level_cost(lv)), str(FIX_LABELS["level"]), "road")
	return _none("road")


## The built counter (not maxed) with the smallest Game.level_payback_min()
## (by name; [INF]); ties (e.g. every INF while W1-CORE's method is missing)
## go to the smallest local payback: level cost / (price gain x throughput x
## order share x income mult), the formula of W1-CORE's level_payback_min.
func _best_level_station(thr: float) -> String:
	var best: String = ""
	var best_p: float = INF
	var best_local: float = INF
	for id: String in game.built_station_ids():
		if game.level_maxed(id):
			continue
		var p: float = float(_gcall("level_payback_min", [id], INF))
		var gain: float = float(game.level_up_price_gain(id)) * thr * float(game.order_share(id)) * float(game.income_mult())
		var lp: float = float(game.level_cost(id)) / gain if gain > 0.0 else INF
		if best == "" or p < best_p or (p == best_p and lp < best_local):
			best = id
			best_p = p
			best_local = lp
	return best


# ================================================================ maxed
func _maxed(stage: String, station: String) -> bool:
	match stage:
		"waiters":
			return not game.can_hire_waiter() and _lowest_waiter() < 0
		"seats":
			return bool(game.table_maxed())
		"cashiers":
			return not game.can_hire_galla() and _lowest_galla() < 0
		"cooks":
			return station != "" and game.is_built(station) and game.hire_maxed(station) and game.proc_maxed(station)
	return false


## Index of the lowest-level waiter below the max level (-1 = all maxed).
func _lowest_waiter() -> int:
	var best: int = -1
	var mx: int = int(game.waiter_max_level())
	for i in int(game.waiter_count()):
		var lv: int = int(game.waiter_level(i))
		if lv < mx and (best < 0 or lv < int(game.waiter_level(best))):
			best = i
	return best


## Index of the lowest-level cashier below the max level (-1 = all maxed).
func _lowest_galla() -> int:
	var best: int = -1
	for i in int(game.galla_count()):
		if game.galla_level_maxed(i):
			continue
		if best < 0 or int(game.galla_level(i)) < int(game.galla_level(best)):
			best = i
	return best


# ================================================================ helpers
## Travellers a minute walking in now: the Sim's live arrival ramp (Game's
## sample), else the throughput.
func _arrivals_now(thr: float) -> float:
	var v: Variant = game.get("_live_arrivals")
	if v != null and float(v) > 0.0:
		return float(v)
	return thr


func _fresh(t: float, ver: int) -> bool:
	var c: float = _clock()
	return ver == _ver() and c >= t and c - t < CACHE_S


## Game's purchase counter (every buy, build, hire bumps it): a purchase
## shows in the readout at once.
func _ver() -> int:
	var v: Variant = game.get("_staff_ver") if game != null else null
	return int(v) if v != null else 0


## Game seconds since boot (Refs.clock), else the wall clock.
func _clock() -> float:
	if game != null and game.is_inside_tree():
		var refs: Node = game.get_node_or_null("/root/Refs")
		if refs != null:
			var c: Variant = refs.get("clock")
			if c != null:
				return float(c)
	return float(Time.get_ticks_msec()) / 1000.0


## A same-wave Game method by name (plan rule 5), or the fallback.
func _gcall(m: String, args: Array, fallback: Variant) -> Variant:
	if game != null and game.has_method(m):
		return game.callv(m, args)
	return fallback


static func _num(v: Variant) -> float:
	var f: float = float(v) if v != null else 0.0
	if is_nan(f):
		return 0.0
	return minf(f, 1.0e9)
