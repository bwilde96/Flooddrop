extends Node
## ChallengeManager — tickets, premium currency, challenge definitions/progress,
## and the ability tree. Everything is local-save based (no server).

# ------------------------------------------------------------------ TICKETS --
const DAILY_TICKETS := 3          # granted once per calendar day (device clock)
const TICKET_CAP := 9             # missed days still leave you something to bank
const TICKET_PRISM_PRICE := 10    # prisms for 1 ticket

# ------------------------------------------------------------------ REWARDS --
# Cores = ability-tree points, earned ONLY by completing challenges (skill-gated
# power). Prisms = premium currency: bought with money, or trickled from bosses
# and achievements so free players always progress.

signal tickets_changed
signal currencies_changed

func _ready() -> void:
	grant_daily_tickets()
	refund_stranded_ticket()

# --- Tickets ---
func get_tickets() -> int:
	return int(SaveManager.get_value("tickets", 3.0))

func grant_daily_tickets() -> void:
	var today := Time.get_date_string_from_system() # device clock; offline game
	var last: String = SaveManager.get_value("tickets_last_grant", "")
	# Monotonic: only grant when today is strictly LATER than the last grant
	# (YYYY-MM-DD compares lexicographically). A rolled-back clock never re-grants,
	# and never punishes — the stored date stays at the max ever seen.
	if last != "" and today <= last:
		return
	var t: int = min(TICKET_CAP, get_tickets() + DAILY_TICKETS)
	SaveManager.set_value("tickets", float(t))
	SaveManager.set_value("tickets_last_grant", today)
	tickets_changed.emit()

# --- Attempt cost & fairness rules ---
# Tickets meter REPETITION, never access:
#  - first-ever attempt of any challenge: FREE
#  - practising an already-cleared challenge: FREE (pays 25% droplets, no cores)
#  - otherwise (retrying an uncleared challenge): 1 ticket
func get_attempt_cost(stage: int, def: Dictionary) -> int:
	var id: String = def.get("id", "")
	if is_completed(stage, id): return 0
	if not was_attempted(stage, id): return 0
	return 1

func was_attempted(stage: int, challenge_id: String) -> bool:
	var att: Dictionary = SaveManager.get_value("challenge_attempted", {})
	return challenge_id in att.get(str(stage), [])

func mark_attempted(stage: int, challenge_id: String) -> void:
	var att: Dictionary = SaveManager.get_value("challenge_attempted", {})
	var arr: Array = att.get(str(stage), [])
	if not (challenge_id in arr):
		arr.append(challenge_id)
	att[str(stage)] = arr
	SaveManager.set_value("challenge_attempted", att)

# Interrupted-attempt protection: a ticket "in flight" that never resolved
# (process killed mid-attempt) is refunded on next launch.
func flag_ticket_in_flight(on: bool) -> void:
	SaveManager.set_value("ticket_in_flight", on)

func refund_stranded_ticket() -> void:
	if SaveManager.get_value("ticket_in_flight", false):
		SaveManager.set_value("ticket_in_flight", false)
		SaveManager.set_value("tickets", float(min(TICKET_CAP, get_tickets() + 1)))
		tickets_changed.emit()

func refund_ticket() -> void:
	SaveManager.set_value("tickets", float(min(TICKET_CAP, get_tickets() + 1)))
	tickets_changed.emit()

# Second Wind: fail at >=70% progress -> one free instant retry (per challenge,
# per session — deliberately generous and simple).
var _second_wind_used: Dictionary = {}

func can_second_wind(challenge_id: String, progress: float) -> bool:
	return progress >= 0.7 and not _second_wind_used.get(challenge_id, false)

func use_second_wind(challenge_id: String) -> void:
	_second_wind_used[challenge_id] = true

# Boss pity: -2 boss HP per 3 fails, capped at -6. Honest and visible.
func get_boss_fails(challenge_id: String) -> int:
	var f: Dictionary = SaveManager.get_value("boss_fails", {})
	return int(f.get(challenge_id, 0.0))

func record_boss_fail(challenge_id: String) -> void:
	var f: Dictionary = SaveManager.get_value("boss_fails", {})
	f[challenge_id] = float(get_boss_fails(challenge_id) + 1)
	SaveManager.set_value("boss_fails", f)

func get_boss_hp(challenge_id: String, base_hp: int) -> int:
	return base_hp - 2 * mini(3, int(get_boss_fails(challenge_id) / 3.0))

func spend_ticket() -> bool:
	var t := get_tickets()
	if t <= 0:
		return false
	SaveManager.set_value("tickets", float(t - 1))
	tickets_changed.emit()
	return true

func buy_ticket_with_prisms() -> bool:
	if get_prisms() < TICKET_PRISM_PRICE: return false
	if get_tickets() >= TICKET_CAP: return false
	add_prisms(-TICKET_PRISM_PRICE)
	SaveManager.set_value("tickets", float(get_tickets() + 1))
	tickets_changed.emit()
	return true

# --- Currencies ---
func get_prisms() -> int:
	return int(SaveManager.get_value("prisms", 0.0))

func add_prisms(amount: int) -> void:
	SaveManager.set_value("prisms", maxf(0.0, float(get_prisms() + amount)))
	currencies_changed.emit()

func get_cores() -> int:
	return int(SaveManager.get_value("cores", 0.0))

func add_cores(amount: int) -> void:
	SaveManager.set_value("cores", maxf(0.0, float(get_cores() + amount)))
	currencies_changed.emit()

func get_droplets() -> int:
	return int(SaveManager.get_value("droplets", 0.0))

func add_droplets(amount: int) -> void:
	SaveManager.set_value("droplets", maxf(0.0, float(get_droplets() + amount)))
	currencies_changed.emit()

# IAP stub — real Google Play billing plugs in here later.
func purchase_prisms_pack(_pack_id: String) -> bool:
	return false # not wired to a store yet

# --- Stage / progress ---
func get_max_stage_reached() -> int:
	return int(SaveManager.get_value("max_stage_reached", 0.0))

func record_stage_reached(stage: int) -> void:
	if stage > get_max_stage_reached():
		SaveManager.set_value("max_stage_reached", float(stage))

func is_stage_unlocked(stage: int) -> bool:
	return stage <= get_max_stage_reached()

func is_completed(stage: int, challenge_id: String) -> bool:
	var done: Dictionary = SaveManager.get_value("challenge_completed", {})
	var arr: Array = done.get(str(stage), [])
	return challenge_id in arr

func mark_completed(stage: int, challenge_id: String) -> void:
	var done: Dictionary = SaveManager.get_value("challenge_completed", {})
	var arr: Array = done.get(str(stage), [])
	if not (challenge_id in arr):
		arr.append(challenge_id)
	done[str(stage)] = arr
	SaveManager.set_value("challenge_completed", done)

func is_challenge_unlocked(stage: int, index: int) -> bool:
	# Challenges within a stage unlock sequentially.
	if not is_stage_unlocked(stage): return false
	if index == 0: return true
	var defs: Array = get_stage_challenges(stage)
	if index >= defs.size(): return false
	return is_completed(stage, defs[index - 1].id)

func stage_fully_cleared(stage: int) -> bool:
	for c in get_stage_challenges(stage):
		if not is_completed(stage, c.id):
			return false
	return true

# ------------------------------------------------------ CHALLENGE DEFINITIONS --
# Modifier keys understood by Gameplay.gd (all built on existing mechanics):
#   spawn_mult / speed_mult / damage_mult : float multipliers
#   no_powerups : bool          disable power-up drops
#   force_event : String        run a scripted event loop ("eruption","overdrive","prismatic","toxic")
#   sudden_death : bool         one miss ends the run
#   tiny_drops : float          custom_scale_mult applied to normal drops
#   sway : float                horizontal wind on all drops (px/s)
#   frenzy_every : float        seconds between burst-waves of 4 extra drops
# Win keys:  {type: "survive"|"score"|"pops"|"combo", value: float, max_misses: int(optional)}
# Boss:      is_boss = true -> Gameplay runs the staged boss script on top.

func get_stage_challenges(stage: int) -> Array:
	return CHALLENGES.get(stage, [])

const CHALLENGES := {
	0: [ # WATER — purity & rhythm
		{"id": "w1", "name": "First Rain", "desc": "Survive 45s. No power-ups — just you and the rain.",
			"mods": {"no_powerups": true}, "win": {"type": "survive", "value": 45.0},
			"rewards": {"droplets": 150, "cores": 1}},
		{"id": "w2", "name": "Cloudburst", "desc": "Armoured rain: crack the shield, then pop the drop. Reach 800.",
			"mods": {"no_powerups": true, "special_rain": "shielded", "frenzy_every": 7.0},
			"win": {"type": "score", "value": 800.0}, "rewards": {"droplets": 250, "cores": 1}},
		{"id": "w3", "name": "Still Waters", "desc": "Sudden death: ONE miss ends it. Pop 40 drops.",
			"mods": {"sudden_death": true}, "win": {"type": "pops", "value": 40.0},
			"rewards": {"droplets": 400, "cores": 1}},
		{"id": "wboss", "name": "⚔ The Deluge", "desc": "BOSS: survive the three-wave storm and burst its heart.",
			"mods": {"spawn_mult": 1.15}, "win": {"type": "boss", "value": 0.0}, "is_boss": true,
			"rewards": {"droplets": 800, "cores": 3, "prisms": 15}},
	],
	1: [ # SLIME — chaos & bounce
		{"id": "s1", "name": "Bounce House", "desc": "Everything bounces. Survive 50s.",
			"mods": {"spawn_mult": 1.1}, "win": {"type": "survive", "value": 50.0},
			"rewards": {"droplets": 200, "cores": 1}},
		{"id": "s2", "name": "Split Ends", "desc": "Meteor slimes keep splitting. Pop 60 drops.",
			"mods": {"force_event": "meteor_rain"}, "win": {"type": "pops", "value": 60.0},
			"rewards": {"droplets": 300, "cores": 1}},
		{"id": "s3", "name": "Hyper Gel", "desc": "Fast, tiny, everywhere. Reach a 3x combo.",
			"mods": {"tiny_drops": 0.7, "speed_mult": 1.25, "spawn_mult": 1.3},
			"win": {"type": "combo", "value": 3.0}, "rewards": {"droplets": 450, "cores": 1}},
		{"id": "sboss", "name": "⚔ The Slime Serpent", "desc": "BOSS: sever the serpent tail-first — and tap its head twice to break its dives.",
			"mods": {"spawn_mult": 1.1}, "win": {"type": "boss", "value": 0.0}, "is_boss": true, "boss_type": "serpent",
			"rewards": {"droplets": 900, "cores": 3, "prisms": 15}},
	],
	2: [ # LAVA — barrage & heat
		{"id": "l1", "name": "Firewalk", "desc": "Heavy damage: every miss burns double. Survive 45s.",
			"mods": {"damage_mult": 2.0}, "win": {"type": "survive", "value": 45.0},
			"rewards": {"droplets": 250, "cores": 1}},
		{"id": "l2", "name": "Eruption Drill", "desc": "Constant eruptions from below. Reach 1200 points.",
			"mods": {"force_event": "eruption"}, "win": {"type": "score", "value": 1200.0},
			"rewards": {"droplets": 350, "cores": 1}},
		{"id": "l3", "name": "Magma Rush", "desc": "Fast lava, no power-ups, 3 misses max. Pop 50.",
			"mods": {"speed_mult": 1.3, "no_powerups": true}, "win": {"type": "pops", "value": 50.0, "max_misses": 3},
			"rewards": {"droplets": 500, "cores": 1}},
		{"id": "lboss", "name": "⚔ The Caldera", "desc": "BOSS: survive the eruption storm, then crack the core.",
			"mods": {"damage_mult": 1.5}, "win": {"type": "boss", "value": 0.0}, "is_boss": true,
			"rewards": {"droplets": 1000, "cores": 3, "prisms": 15}},
	],
	3: [ # ACID — corrosion & restraint
		{"id": "a1", "name": "Toxic Discipline", "desc": "Acid drops rain — popping them HURTS. Survive 45s.",
			"mods": {"force_event": "toxic"}, "win": {"type": "survive", "value": 45.0},
			"rewards": {"droplets": 300, "cores": 1}},
		{"id": "a2", "name": "Neutralise", "desc": "The flood rises on its own. Pop 45 drops before it wins.",
			"mods": {"force_event": "toxic", "spawn_mult": 1.15}, "win": {"type": "pops", "value": 45.0},
			"rewards": {"droplets": 400, "cores": 1}},
		{"id": "a3", "name": "Caustic Sprint", "desc": "Fast acid, sudden death. Reach 700 points.",
			"mods": {"speed_mult": 1.25, "sudden_death": true}, "win": {"type": "score", "value": 700.0},
			"rewards": {"droplets": 550, "cores": 1}},
		{"id": "aboss", "name": "⚔ The Reactor", "desc": "BOSS: keep the meltdown down and shatter the containment heart.",
			"mods": {"force_event": "toxic"}, "win": {"type": "boss", "value": 0.0}, "is_boss": true,
			"rewards": {"droplets": 1100, "cores": 3, "prisms": 15}},
	],
	4: [ # GOLD — greed
		{"id": "g1", "name": "Gold Fever", "desc": "Gold accelerates as it falls. Survive 50s.",
			"mods": {"speed_mult": 1.1}, "win": {"type": "survive", "value": 50.0},
			"rewards": {"droplets": 400, "cores": 1}},
		{"id": "g2", "name": "The Golden Beat", "desc": "Clockwork drops: tap ON the shrinking ring or be deflected. Reach a 4x combo.",
			"mods": {"special_rain": "clockwork"}, "win": {"type": "combo", "value": 4.0},
			"rewards": {"droplets": 500, "cores": 1}},
		{"id": "g3", "name": "Midas Gauntlet", "desc": "Tiny fast coins, 3 misses max. Reach 1500 points.",
			"mods": {"tiny_drops": 0.75, "speed_mult": 1.2}, "win": {"type": "score", "value": 1500.0, "max_misses": 3},
			"rewards": {"droplets": 650, "cores": 1}},
		{"id": "gboss", "name": "⚔ The Vault", "desc": "BOSS: the piñata of piñatas. Beat the greed out of it.",
			"mods": {"spawn_mult": 1.15}, "win": {"type": "boss", "value": 0.0}, "is_boss": true,
			"rewards": {"droplets": 1400, "cores": 3, "prisms": 20}},
	],
	5: [ # RAINBOW — light & dark
		{"id": "r1", "name": "Prism Break", "desc": "Blackout! Only rainbow drops light the way. Survive 40s.",
			"mods": {"force_event": "prismatic"}, "win": {"type": "survive", "value": 40.0},
			"rewards": {"droplets": 450, "cores": 1}},
		{"id": "r2", "name": "Chasing Ghosts", "desc": "Phantom drops flicker in and out — strike while they're real. Pop 40.",
			"mods": {"special_rain": "phantom", "sway": 100.0}, "win": {"type": "pops", "value": 40.0},
			"rewards": {"droplets": 550, "cores": 1}},
		{"id": "r3", "name": "Spectrum Sprint", "desc": "Blackout, sudden death. Reach 600 points in the dark.",
			"mods": {"force_event": "prismatic", "sudden_death": true}, "win": {"type": "score", "value": 600.0},
			"rewards": {"droplets": 700, "cores": 1}},
		{"id": "rboss", "name": "⚔ The Eclipse", "desc": "BOSS: fight in and out of darkness. Shatter the black heart.",
			"mods": {"force_event": "prismatic"}, "win": {"type": "boss", "value": 0.0}, "is_boss": true,
			"rewards": {"droplets": 1600, "cores": 3, "prisms": 20}},
	],
	6: [ # NEON — glitch
		{"id": "n1", "name": "Ghost Packets", "desc": "Phantom drops phase through your taps. Survive 45s.",
			"mods": {"special_rain": "phantom", "spawn_mult": 1.1}, "win": {"type": "survive", "value": 45.0},
			"rewards": {"droplets": 500, "cores": 1}},
		{"id": "n2", "name": "Packet Storm", "desc": "Glitch bursts every 5s. Reach 1500 points.",
			"mods": {"force_event": "overdrive", "frenzy_every": 5.0}, "win": {"type": "score", "value": 1500.0},
			"rewards": {"droplets": 600, "cores": 1}},
		{"id": "n3", "name": "Zero Day", "desc": "Glitched, tiny, sudden death. Pop 35 drops.",
			"mods": {"force_event": "overdrive", "tiny_drops": 0.75, "sudden_death": true},
			"win": {"type": "pops", "value": 35.0}, "rewards": {"droplets": 800, "cores": 1}},
		{"id": "nboss", "name": "⚔ The Data Wyrm", "desc": "BOSS: a serpent of corrupted code. Purge it segment by segment, tail-first.",
			"mods": {"force_event": "overdrive"}, "win": {"type": "boss", "value": 0.0}, "is_boss": true, "boss_type": "serpent",
			"rewards": {"droplets": 1800, "cores": 3, "prisms": 20}},
	],
	7: [ # GALAXY — chaos incarnate
		{"id": "x1", "name": "Event Horizon", "desc": "Shielded meteors, heavy damage — everything takes two taps. Survive 45s.",
			"mods": {"damage_mult": 1.5, "special_rain": "shielded"}, "win": {"type": "survive", "value": 45.0},
			"rewards": {"droplets": 600, "cores": 1}},
		{"id": "x2", "name": "Meteor Shower", "desc": "Endless splitting meteors + wind. Pop 70.",
			"mods": {"force_event": "meteor_rain", "sway": 100.0}, "win": {"type": "pops", "value": 70.0},
			"rewards": {"droplets": 750, "cores": 1}},
		{"id": "x3", "name": "Singularity", "desc": "Everything at once. Reach a 5x combo.",
			"mods": {"frenzy_every": 6.0, "speed_mult": 1.2, "spawn_mult": 1.2},
			"win": {"type": "combo", "value": 5.0}, "rewards": {"droplets": 900, "cores": 2}},
		{"id": "xboss", "name": "⚔ The Cosmic Warden", "desc": "BOSS: the final gauntlet. Everything you have learned.",
			"mods": {"spawn_mult": 1.25, "speed_mult": 1.1}, "win": {"type": "boss", "value": 0.0}, "is_boss": true,
			"rewards": {"droplets": 2500, "cores": 4, "prisms": 30}},
	],
}

# ------------------------------------------------------------- ABILITY TREE --
# Buff keys read by Gameplay: duration_add, power_mult, cooldown_add (negative = faster)
const ABILITY_TREE := {
	"time_warp": [
		{"id": "tw1", "name": "Deep Freeze", "desc": "Slow lasts +2s", "cost_cores": 1, "cost_droplets": 200, "key": "duration_add", "value": 2.0},
		{"id": "tw2", "name": "Absolute Zero", "desc": "Time slows 30% further", "cost_cores": 2, "cost_droplets": 400, "key": "power_mult", "value": 0.75},
		{"id": "tw3", "name": "Chrono Loop", "desc": "Cooldown -6s", "cost_cores": 3, "cost_droplets": 800, "key": "cooldown_add", "value": -6.0},
	],
	"evaporation": [
		{"id": "ev1", "name": "Heat Haze", "desc": "Drains +10% more flood", "cost_cores": 1, "cost_droplets": 200, "key": "power_mult", "value": 1.33},
		{"id": "ev2", "name": "Scorch", "desc": "Drains +20% more flood", "cost_cores": 2, "cost_droplets": 400, "key": "power_mult", "value": 1.2},
		{"id": "ev3", "name": "Solar Flare", "desc": "Cooldown -6s", "cost_cores": 3, "cost_droplets": 800, "key": "cooldown_add", "value": -6.0},
	],
	"tidal_wave": [
		{"id": "td1", "name": "Undertow", "desc": "Cooldown -8s", "cost_cores": 1, "cost_droplets": 250, "key": "cooldown_add", "value": -8.0},
		{"id": "td2", "name": "Riptide", "desc": "Cooldown -8s more", "cost_cores": 2, "cost_droplets": 500, "key": "cooldown_add", "value": -8.0},
		{"id": "td3", "name": "Tsunami", "desc": "Wave also drains 15 flood", "cost_cores": 3, "cost_droplets": 900, "key": "wave_drain", "value": 15.0},
	],
	"midas_touch": [
		{"id": "md1", "name": "Golden Hour", "desc": "Lasts +3s", "cost_cores": 1, "cost_droplets": 250, "key": "duration_add", "value": 3.0},
		{"id": "md2", "name": "Alchemy", "desc": "Lasts +3s more", "cost_cores": 2, "cost_droplets": 500, "key": "duration_add", "value": 3.0},
		{"id": "md3", "name": "Philosopher's Stone", "desc": "Cooldown -8s", "cost_cores": 3, "cost_droplets": 900, "key": "cooldown_add", "value": -8.0},
	],
	"auto_turret": [
		{"id": "at1", "name": "Overclock", "desc": "Active laser lasts +2s", "cost_cores": 1, "cost_droplets": 250, "key": "duration_add", "value": 2.0},
		{"id": "at2", "name": "Twin Coils", "desc": "Active laser lasts +2s more", "cost_cores": 2, "cost_droplets": 500, "key": "duration_add", "value": 2.0},
		{"id": "at3", "name": "War Machine", "desc": "Cooldown -8s", "cost_cores": 3, "cost_droplets": 900, "key": "cooldown_add", "value": -8.0},
	],
}

# Per-ability base cooldowns (replaces the old one-size-fits-all 30s).
const BASE_COOLDOWNS := {
	"time_warp": 25.0, "evaporation": 30.0, "tidal_wave": 45.0,
	"midas_touch": 40.0, "auto_turret": 35.0,
}

func get_owned_nodes(ability: String) -> Array:
	var tree: Dictionary = SaveManager.get_value("ability_tree", {})
	return tree.get(ability, [])

func is_node_owned(ability: String, node_id: String) -> bool:
	return node_id in get_owned_nodes(ability)

func is_node_unlockable(ability: String, index: int) -> bool:
	# Nodes unlock sequentially within an ability's tree.
	if index == 0: return true
	var nodes: Array = ABILITY_TREE.get(ability, [])
	if index >= nodes.size(): return false
	return is_node_owned(ability, nodes[index - 1].id)

func buy_node(ability: String, node_id: String) -> bool:
	var nodes: Array = ABILITY_TREE.get(ability, [])
	for n in nodes:
		if n.id == node_id:
			if is_node_owned(ability, node_id): return false
			if get_cores() < n.cost_cores or get_droplets() < n.cost_droplets: return false
			add_cores(-n.cost_cores)
			add_droplets(-n.cost_droplets)
			var tree: Dictionary = SaveManager.get_value("ability_tree", {})
			var arr: Array = tree.get(ability, [])
			arr.append(node_id)
			tree[ability] = arr
			SaveManager.set_value("ability_tree", tree)
			return true
	return false

func get_buff_sum(ability: String, key: String) -> float:
	# Additive keys: duration_add, cooldown_add. (power_mult handled by get_buff_product.)
	var total := 0.0
	for n in ABILITY_TREE.get(ability, []):
		if n.key == key and is_node_owned(ability, n.id):
			total += n.value
	return total

func get_buff_product(ability: String, key: String) -> float:
	var total := 1.0
	for n in ABILITY_TREE.get(ability, []):
		if n.key == key and is_node_owned(ability, n.id):
			total *= n.value
	return total

func get_ability_cooldown(ability: String) -> float:
	var base: float = BASE_COOLDOWNS.get(ability, 30.0)
	return maxf(8.0, base + get_buff_sum(ability, "cooldown_add"))
