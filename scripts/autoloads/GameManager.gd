extends Node

var current_scene: Node = null
var root_scene: Node = null

var score: int = 0
var survival_time: float = 0.0
var is_new_high_score: bool = false

func _ready() -> void:
	pass

func change_scene(scene_path: String) -> void:
	if root_scene == null:
		push_error("GameManager.root_scene is not set!")
		return
		
	if current_scene != null:
		current_scene.queue_free()
		
	var new_scene_resource := load(scene_path)
	if new_scene_resource:
		current_scene = new_scene_resource.instantiate()
		root_scene.add_child(current_scene)
	else:
		push_error("Failed to load scene: " + scene_path)

func start_game() -> void:
	score = 0
	survival_time = 0.0
	is_new_high_score = false
	challenge_config = {}
	last_challenge_result = {}
	change_scene("res://scenes/Gameplay.tscn")

var last_droplets_earned: int = 0

# --- Challenge mode ---
# When non-empty, Gameplay runs in challenge mode with this config
# (set by the Challenge screen; see ChallengeManager.CHALLENGES).
var challenge_config: Dictionary = {}
var last_challenge_result: Dictionary = {}
var challenge_ticket_spent: bool = false # set by the Challenge screen when it charges
var challenge_progress: float = 0.0      # 0..1, updated live by Gameplay for Second Wind

func start_challenge(stage: int, challenge: Dictionary) -> void:
	score = 0
	survival_time = 0.0
	is_new_high_score = false
	last_challenge_result = {}
	challenge_progress = 0.0
	challenge_config = {"stage": stage, "def": challenge}
	ChallengeManager.mark_attempted(stage, challenge.get("id", ""))
	ChallengeManager.flag_ticket_in_flight(challenge_ticket_spent)
	change_scene("res://scenes/Gameplay.tscn")

func challenge_won() -> void:
	var stage: int = challenge_config.get("stage", 0)
	var def: Dictionary = challenge_config.get("def", {})
	var rewards: Dictionary = def.get("rewards", {})
	var first_clear: bool = not ChallengeManager.is_completed(stage, def.get("id", ""))

	# First clear pays the full bounty; replays pay 25% droplets (no cores/prisms).
	var droplets: int = rewards.get("droplets", 0) if first_clear else int(rewards.get("droplets", 0) * 0.25)
	ChallengeManager.add_droplets(droplets)
	if first_clear:
		ChallengeManager.add_cores(rewards.get("cores", 0))
		ChallengeManager.add_prisms(rewards.get("prisms", 0))
		ChallengeManager.mark_completed(stage, def.get("id", ""))

	last_challenge_result = {"won": true, "first_clear": first_clear, "droplets": droplets,
		"cores": rewards.get("cores", 0) if first_clear else 0,
		"prisms": rewards.get("prisms", 0) if first_clear else 0,
		"stage": stage, "def": def}
	last_droplets_earned = droplets
	ChallengeManager.flag_ticket_in_flight(false)
	challenge_config = {}
	challenge_ticket_spent = false
	EventBus.game_over.emit()
	change_scene("res://scenes/GameOver.tscn")

func trigger_game_over() -> void:
	if not challenge_config.is_empty():
		# Challenge failed: consolation droplets only; never touches the main high score.
		var def: Dictionary = challenge_config.get("def", {})
		var cid: String = def.get("id", "")
		last_droplets_earned = floori(score * 0.15)
		ChallengeManager.add_droplets(last_droplets_earned)
		ChallengeManager.flag_ticket_in_flight(false)
		if def.get("is_boss", false):
			ChallengeManager.record_boss_fail(cid) # feeds honest boss pity

		var refunded := false
		if challenge_ticket_spent and survival_time < 10.0:
			ChallengeManager.refund_ticket() # fast-fail: a scuffed start shouldn't cost a try
			refunded = true
		var second_wind: bool = not refunded and ChallengeManager.can_second_wind(cid, challenge_progress)

		last_challenge_result = {"won": false, "stage": challenge_config.get("stage", 0),
			"def": def, "refunded": refunded, "second_wind": second_wind,
			"progress": challenge_progress}
		challenge_config = {}
		challenge_ticket_spent = false
		EventBus.game_over.emit()
		change_scene("res://scenes/GameOver.tscn")
		return

	var high_score: float = SaveManager.get_value("high_score", 0.0)
	is_new_high_score = float(score) > high_score
	if is_new_high_score:
		SaveManager.set_value("high_score", float(score))

	# Phase 6: Calculate Droplets
	var score_mult = ThemeManager.get_equipped_theme().get("score_mult", 1.0)
	last_droplets_earned = floori((score * 0.5 + survival_time * 2.0) * score_mult)
	if is_new_high_score:
		last_droplets_earned += int(100 * score_mult)

	var current_droplets: float = SaveManager.get_value("droplets", 0.0)
	SaveManager.set_value("droplets", current_droplets + float(last_droplets_earned))

	EventBus.game_over.emit()
	change_scene("res://scenes/GameOver.tscn")

func goto_main_menu() -> void:
	change_scene("res://scenes/MainMenu.tscn")
