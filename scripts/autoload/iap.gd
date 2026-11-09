extends Node
## In-app purchase facade (autoload "Iap"). The game only uses this API:
##   buy(product_id, cb)            cb(ok: bool) runs exactly once
##   restore_purchases(cb)          cb(ok: bool): the store answered and a
##                                  non-consumable is owned afterwards
##   is_owned / is_busy / has_product / price_label / title
##   signal purchase_finished(product_id, ok)
##   signal purchase_result(product_id, result)   why, for the UI's message
## Entitlements are applied here (Game.set_vip, Game.set_remove_ads,
## Game.add_sikke + save, the starter pack through Game.grant_starter()),
## then `cb.call(ok)` runs. A purchase that turns
## pending (slow payment methods such as UPI) answers ok = false now and is
## granted later, whenever the store reports it complete (same session,
## next resume or next launch), with purchase_finished(id, true).
##
## Backends (scripts/v3/monetization/): Google Play Billing on Android
## (store_backend_play.gd), App Store InAppStore on iOS once that plugin is
## built (store_backend_appstore.gd), the v0.3 fake store on desktop and in
## debug builds without a store plugin (store_backend_stub.gd), "none"
## otherwise (purchases fail). Consumable grants are recorded by purchase
## token in user://iap_ledger.json, so a purchase the store re-delivers
## (crash before consume, resume race) is never granted twice.

signal purchase_finished(product_id: String, ok: bool)
## A purchase is waiting for payment (granted later automatically).
signal purchase_pending(product_id: String)
## Store prices arrived (UI can refresh price labels).
signal products_updated
signal restore_finished(ok: bool, restored: PackedStringArray)
## How a purchase ended, for the player-facing message (scripts/v3/ui/
## sdk_notice.gd turns it into a toast): "purchased", "granted" (an earlier
## pending payment went through), "restored" (found again by the silent
## restore at launch / resume, e.g. after a reinstall), "pending",
## "cancelled", "failed", "unavailable" (no store, billing off, item missing,
## or the store never answered) or "busy" (another purchase is running).
signal purchase_result(product_id: String, result: String)

const FAKE_SECONDS := 0.5
## Core and feel C7.4: the one-time starter pack (a fixed amount of dhaba cash,
## paid once after the tutorial by the offers module, scripts/v3/core/
## offers.gd). Every purchase, restore and old buyer is reported to
## Game.note_purchase() first, so no offer shows after any purchase.
const STARTER := "starter_pack"
## Placeholder store titles and prices from the theme pack (theme.json
## store.products); real ones come from the store at runtime (Play Console:
## owner task). The dhaba's Remove Ads is sold as "No forced ads, now or
## later" (it removes every interstitial; bonus videos stay).
static var PRODUCTS: Dictionary = _products()


static func _products() -> Dictionary:
	var st: Variant = ThemePack.config().get("store", {})
	var p: Variant = (st as Dictionary).get("products", {}) if st is Dictionary else {}
	return p if p is Dictionary else {}

const Config := preload("res://scripts/v3/monetization/monetization_config.gd")
const BaseBackend := preload("res://scripts/v3/monetization/store_backend_base.gd")
const StubBackend := preload("res://scripts/v3/monetization/store_backend_stub.gd")
const PLAY_BACKEND_PATH := "res://scripts/v3/monetization/store_backend_play.gd"
const APPSTORE_BACKEND_PATH := "res://scripts/v3/monetization/store_backend_appstore.gd"
const PLAY_CLIENT_PATH := "res://addons/GodotGooglePlayBilling/BillingClient.gd"
const PLAY_SINGLETON := "GodotGooglePlayBilling"
const APPSTORE_SINGLETON := "InAppStore"
const LEDGER_PATH := "user://iap_ledger.json"
const LEDGER_MAX := 200

var _busy: bool = false
var _active_id: String = ""
var _active_cb: Callable = Callable()
var _active_fg: float = 0.0
var _restoring: bool = false
var _restore_fg: float = 0.0
var _restore_cbs: Array[Callable] = []
var _restored_now: PackedStringArray = []
var _owned_before_restore: bool = false

var _cfg: Dictionary = {}
var _backend: BaseBackend
var _store_ids: Dictionary = {}     # game id -> store id
var _game_ids: Dictionary = {}      # store id -> game id
var _ledger: Dictionary = {}        # consumable purchase token -> unix time
var _reported: Dictionary = {}      # tokens already sent as revenue this run
var _last_now: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_last_now = _now()
	_cfg = Config.section("iap")
	_load_ledger()
	_map_ids()
	# Deferred: Game (a later autoload) has loaded the save before any grant.
	_install_backend.call_deferred(_make_backend())


# ================================================================ public API
func has_product(product_id: String) -> bool:
	return PRODUCTS.has(product_id)


## Store price when loaded (localized, e.g. "₹199.00"), else the placeholder.
func price_label(product_id: String) -> String:
	if not PRODUCTS.has(product_id):
		return ""
	if _backend != null:
		var live: String = _backend.price_label(str(_store_ids.get(product_id, product_id)))
		if live != "":
			return live
	var p: Dictionary = PRODUCTS[product_id]
	return str(p.get("price", ""))


func title(product_id: String) -> String:
	if not PRODUCTS.has(product_id):
		return product_id
	var p: Dictionary = PRODUCTS[product_id]
	return str(p.get("title", product_id))


## Non-consumables already bought (from Game's saved entitlements; the
## starter pack from the offers module).
func is_owned(product_id: String) -> bool:
	match product_id:
		"vip_x2":
			return Game.vip
		"remove_ads":
			return Game.remove_ads
		STARTER:
			return _starter_owned()
	return false


func is_busy() -> bool:
	return _busy


## Starts a purchase; `cb` (optional) receives `ok: bool` exactly once.
func buy(product_id: String, cb: Callable = Callable()) -> void:
	if _busy or not PRODUCTS.has(product_id) or _backend == null:
		var why: String = "busy" if _busy else ("failed" if not PRODUCTS.has(product_id) else "unavailable")
		_result.call_deferred(product_id, why)
		_finish.call_deferred(product_id, false, cb)
		return
	if is_owned(product_id):
		_result.call_deferred(product_id, "purchased")
		_finish.call_deferred(product_id, true, cb)
		return
	_busy = true
	_active_id = product_id
	_active_cb = cb
	_active_fg = 0.0
	Analytics.event("iap_started", {"id": product_id})
	_backend.purchase(str(_store_ids[product_id]))


## Re-reads the store's owned purchases and grants them. Needed on iOS (a
## Settings button); harmless on Android.
func restore_purchases(cb: Callable = Callable()) -> void:
	if cb.is_valid():
		_restore_cbs.append(cb)
	if _backend == null:
		_end_restore(false)
		return
	if _restoring:
		return
	_restoring = true
	_restore_fg = 0.0
	_restored_now = PackedStringArray()
	_owned_before_restore = _owns_any()
	Analytics.event("iap_restore_started", {})
	_backend.restore()


## True where the store requires a visible Restore button (iOS).
func restore_button_needed() -> bool:
	return _backend != null and _backend.needs_restore_button()


func backend_name() -> String:
	return _backend.backend_name() if _backend != null else "none"


func debug_status() -> Dictionary:
	var s: Dictionary = _backend.status() if _backend != null else {}
	s["busy"] = _busy
	s["active"] = _active_id
	s["restoring"] = _restoring
	s["ledger"] = _ledger.size()
	s["store_ids"] = _store_ids.duplicate()
	return s


# ================================================================ backend setup
func _map_ids() -> void:
	var sec: String = "iap_ios" if Config.platform() == "ios" else "iap_android"
	var map: Dictionary = Config.section(sec)
	_store_ids.clear()
	_game_ids.clear()
	for id: String in PRODUCTS.keys():
		var sid: String = str(map.get(id, id)).strip_edges()
		if sid == "":
			sid = id
		_store_ids[id] = sid
		_game_ids[sid] = id


func _make_backend() -> BaseBackend:
	var plat: String = Config.platform()
	var debug: bool = OS.is_debug_build()
	if debug and bool(_cfg.get("use_stub_store", false)):
		print("[iap] fake store (use_stub_store)")
		return StubBackend.new()
	if plat == "desktop":
		return StubBackend.new()
	var path: String = ""
	if plat == "android" and Engine.has_singleton(PLAY_SINGLETON) and ResourceLoader.exists(PLAY_CLIENT_PATH):
		path = PLAY_BACKEND_PATH
	elif plat == "ios" and Engine.has_singleton(APPSTORE_SINGLETON):
		path = APPSTORE_BACKEND_PATH
	if path != "":
		var script: Script = load(path)
		if script != null and script.can_instantiate():
			return script.new()
		push_error("[iap] %s failed to load" % path)
	else:
		push_warning("[iap] no store plugin in this build (%s)" % plat)
	if debug:
		print("[iap] debug build: falling back to the fake store")
		return StubBackend.new()
	return BaseBackend.new()


func _install_backend(b: BaseBackend) -> void:
	if _backend != null:
		_backend.queue_free()
	_backend = b
	_backend.name = "StoreBackend"
	add_child(_backend)
	_backend.products_updated.connect(func() -> void: products_updated.emit())
	_backend.purchase_update.connect(_on_purchase_update)
	_backend.restore_done.connect(_on_restore_done)
	_backend.finalize_done.connect(_on_finalize_done)
	var ids := PackedStringArray()
	var consumables := PackedStringArray()
	for id: String in PRODUCTS.keys():
		ids.append(str(_store_ids[id]))
		if _is_consumable(id):
			consumables.append(str(_store_ids[id]))
	print("[iap] backend: %s, products: %s" % [_backend.backend_name(), ids])
	_backend.start(_cfg, ids, consumables)
	# Restore on start: owned non-consumables (reinstall, other device) and
	# purchases that completed while the game was closed.
	if _backend.silent_restore_allowed():
		_backend.restore()


# ================================================================ store events
func _on_purchase_update(p: Dictionary) -> void:
	var sid: String = str(p.get("store_id", ""))
	var id: String = str(_game_ids.get(sid, ""))
	var state: String = str(p.get("state", ""))
	if id == "":
		push_warning("[iap] ignoring unknown store product '%s' (%s)" % [sid, state])
		return
	var active: bool = _busy and id == _active_id
	match state:
		BaseBackend.PURCHASED:
			var newly: bool = _grant(id, p)
			if _is_consumable(id) or not bool(p.get("acknowledged", false)):
				_backend.finalize(p, _is_consumable(id))
			if newly and _restoring:
				_restored_now.append(id)
			var token: String = str(p.get("token", ""))
			var src: String = str(p.get("source", ""))
			# Revenue once per new sale: not for restored, already
			# acknowledged items (reinstall, "already owned").
			var real_sale: bool = src == "purchase" or src == "update" \
					or (active and not bool(p.get("acknowledged", false)))
			if real_sale and newly and not _reported.has(token):
				_reported[token] = true
				_report_revenue(id, sid)
			if active:
				_result(id, "purchased")
				_end_active(true)
			elif newly:
				print("[iap] %s granted (%s)" % [id, str(p.get("source", ""))])
				# A restore the player asked for (Settings) answers through its
				# own callback; this one is the silent restore or a late grant.
				if not (_restoring and src == "restore"):
					_result(id, "restored" if src == "restore" else "granted")
				purchase_finished.emit(id, true)
		BaseBackend.PENDING:
			if active:
				Analytics.event("iap_pending", {"id": id})
				purchase_pending.emit(id)
				_result(id, "pending")
				_end_active(false)
		BaseBackend.CANCELLED:
			if active:
				Analytics.event("iap_cancelled", {"id": id})
				_result(id, "cancelled")
				_end_active(false)
		BaseBackend.ALREADY_OWNED:
			if active:
				# The store says it is ours: restore grants it, then answer.
				Analytics.event("iap_already_owned", {"id": id})
				_restore_then_answer()
		_:
			if active:
				Analytics.event("iap_failed", {"id": id, "code": int(p.get("code", 0)),
						"error": str(p.get("error", "")).left(80)})
				_result(id, "unavailable" if str(p.get("reason", "")) == "unavailable" else "failed")
				_end_active(false)


func _restore_then_answer() -> void:
	restore_finished.connect(func(ok: bool, _restored: PackedStringArray) -> void:
		if _busy and _active_id != "":
			var got: bool = ok and (is_owned(_active_id) or _is_consumable(_active_id))
			_result(_active_id, "purchased" if got else ("failed" if ok else "unavailable"))
			_end_active(got),
			CONNECT_ONE_SHOT)
	restore_purchases()


func _on_restore_done(ok: bool) -> void:
	if not _restoring:
		return   # the silent restore at start / resume
	_end_restore(ok)


func _end_restore(ok: bool) -> void:
	_restoring = false
	var restored: PackedStringArray = _restored_now
	_restored_now = PackedStringArray()
	var result: bool = ok and (_owns_any() or not restored.is_empty())
	Analytics.event("iap_restore_finished", {"ok": ok, "restored": restored.size()})
	restore_finished.emit(ok, restored)
	purchase_finished.emit("restore", result)
	var cbs: Array[Callable] = _restore_cbs
	_restore_cbs = []
	for cb: Callable in cbs:
		if cb.is_valid():
			cb.call(result)


func _on_finalize_done(token: String, ok: bool) -> void:
	if OS.is_debug_build():
		print("[iap] finalize %s: %s" % [token.left(12), ok])


func _end_active(ok: bool) -> void:
	var id: String = _active_id
	var cb: Callable = _active_cb
	_busy = false
	_active_id = ""
	_active_cb = Callable()
	Analytics.event("iap_finished", {"id": id, "ok": ok})
	_finish(id, ok, cb)


# ================================================================ granting
## Applies the entitlement. Returns true when something new was granted.
func _grant(product_id: String, p: Dictionary) -> bool:
	var had: bool = is_owned(product_id)
	# C7.4: every purchase counts, before the early returns below (restores and
	# old buyers too): the offers module shows no offer after any purchase.
	if Game.has_method("note_purchase"):
		Game.call("note_purchase", product_id)
	match product_id:
		"vip_x2":
			if Game.vip:
				return false
			Game.set_vip(true)
			return true
		"remove_ads":
			if Game.remove_ads:
				return false
			Game.set_remove_ads(true)
			return true
		"sikke_small":
			var token: String = str(p.get("token", ""))
			if token != "" and _ledger.has(token):
				return false
			var info: Dictionary = PRODUCTS[product_id]
			var qty: int = maxi(1, int(p.get("quantity", 1)))
			Game.add_sikke(int(info.get("sikke", 0)) * qty)
			Game.save_game()
			if token != "":
				_ledger[token] = int(Time.get_unix_time_from_system())
				_save_ledger()
			return true
		STARTER:
			# Paid once per save and only after the tutorial (the offers
			# module); a silent restore of an owned pack pays nothing again.
			if Game.has_method("grant_starter"):
				Game.call("grant_starter")
			# On disk before the store transaction is finalized (iOS does no
			# silent restore at launch), as for the other products.
			Game.save_game()
			return not had
	return false


## The starter pack is owned (offers module state; false without it).
func _starter_owned() -> bool:
	if not Game.has_method("system"):
		return false
	var o: Variant = Game.call("system", "offers")
	if not (o is Object) or not ("starter_owned" in (o as Object)):
		return false
	return bool((o as Object).get("starter_owned"))


func _is_consumable(product_id: String) -> bool:
	return bool((PRODUCTS.get(product_id, {}) as Dictionary).get("consumable", false))


func _owns_any() -> bool:
	return Game.vip or Game.remove_ads or _starter_owned()


func _report_revenue(id: String, sid: String) -> void:
	var info: Dictionary = _backend.price_info(sid)
	var micros: int = int(info.get("micros", 0))
	var currency: String = str(info.get("currency", ""))
	if micros > 0 and currency != "":
		# GameAnalytics wants the amount in cents (paise): micros / 10 000.
		Analytics.business_event(id, currency, int(round(micros / 10000.0)), "store")


func _result(product_id: String, result: String) -> void:
	if OS.is_debug_build():
		print("[iap] result %s: %s" % [product_id, result])
	purchase_result.emit(product_id, result)


func _finish(product_id: String, ok: bool, cb: Callable) -> void:
	purchase_finished.emit(product_id, ok)
	if cb.is_valid():
		cb.call(ok)


# ================================================================ watchdogs
func _process(_delta: float) -> void:
	var now: float = _now()
	var fg_dt: float = clampf(now - _last_now, 0.0, 0.5)
	_last_now = now
	if _busy:
		_active_fg += fg_dt
		if _active_fg > float(_cfg.get("purchase_timeout_s", 600.0)):
			push_warning("[iap] %s: no answer from the store, giving up" % _active_id)
			Analytics.event("iap_timeout", {"id": _active_id})
			_result(_active_id, "unavailable")
			_end_active(false)
	if _restoring:
		_restore_fg += fg_dt
		if _restore_fg > float(_cfg.get("restore_timeout_s", 30.0)):
			push_warning("[iap] restore: no answer from the store")
			_end_restore(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED and _backend != null:
		_backend.on_app_resumed()


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


# ================================================================ ledger
func _load_ledger() -> void:
	_ledger = {}
	if not FileAccess.file_exists(LEDGER_PATH):
		return
	var f: FileAccess = FileAccess.open(LEDGER_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary and (parsed as Dictionary).get("granted") is Dictionary:
		_ledger = (parsed as Dictionary)["granted"]


func _save_ledger() -> void:
	if Game.save_locked():
		return
	if _ledger.size() > LEDGER_MAX:
		var keys: Array = _ledger.keys()
		keys.sort_custom(func(a: Variant, b: Variant) -> bool: return int(_ledger[a]) < int(_ledger[b]))
		for i: int in keys.size() - LEDGER_MAX:
			_ledger.erase(keys[i])
	var f: FileAccess = FileAccess.open(LEDGER_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("[iap] ledger save failed (%s)" % FileAccess.get_open_error())
		return
	f.store_string(JSON.stringify({"v": 1, "granted": _ledger}))
	f.close()


# ================================================================ sdk test hooks
## --sdk-test only: replace the backend (no restore at start) and reset state.
func _test_install_backend(b: BaseBackend) -> void:
	_busy = false
	_active_id = ""
	_active_cb = Callable()
	_restoring = false
	_restore_cbs = []
	_reported = {}
	if _backend != null:
		_backend.queue_free()
	_backend = b
	_backend.name = "StoreBackendTest"
	add_child(_backend)
	_backend.products_updated.connect(func() -> void: products_updated.emit())
	_backend.purchase_update.connect(_on_purchase_update)
	_backend.restore_done.connect(_on_restore_done)
	_backend.finalize_done.connect(_on_finalize_done)
	var ids := PackedStringArray()
	var consumables := PackedStringArray()
	for id: String in PRODUCTS.keys():
		ids.append(str(_store_ids[id]))
		if _is_consumable(id):
			consumables.append(str(_store_ids[id]))
	_backend.start(_cfg, ids, consumables)


func _test_ledger_has(token: String) -> bool:
	return _ledger.has(token)
