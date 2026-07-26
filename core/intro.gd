extends Control

# U1 — first-play explainer. Shown by main._on_new_game() only when
# GameManager.seen_intro is false. Sets seen_intro the moment it opens so a
# Skip still counts as "seen" (no re-show loop). Emits intro_finished on Begin
# or Skip; main.gd routes that to prep_phase.

const PANELS: Array[Dictionary] = [
	{
		"title": "Welcome to the Forge",
		"body": "You are a smith of a struggling workshop. Travellers come seeking gear — swords, trinkets, remedies — and pay gold for what you can craft.\n\nYour task: keep the orders flowing, and the coin coming in.",
	},
	{
		"title": "Merge. Make. Explore.",
		"body": "Tap a crate to draw raw materials onto your board.\n\nDrag matching items into touching squares — three or more of the same, edge to edge, will merge into something finer. Iron ore becomes ingots; leafy herbs become bundles.\n\nMerged goods fulfill the orders your customers bring.",
	},
	{
		"title": "Grow Your Renown",
		"body": "Every order fulfilled earns gold and reputation.\n\nSpend gold on rarer crates, blueprints, and upgrades. Earn enough reputation and a new path opens — the dungeons, where the rarest reagents hide.\n\nNow — to the forge.",
	},
]

var _current: int = 0

@onready var _title: Label = $VBox/Title
@onready var _body: Label = $VBox/Body
@onready var _next_btn: Button = $VBox/BtnBox/NextBtn
@onready var _begin_btn: Button = $VBox/BtnBox/BeginBtn
@onready var _skip_btn: Button = $VBox/BtnBox/SkipBtn


func _ready() -> void:
	# Mark as seen the moment the intro opens — a Skip is still "seen."
	GameManager.seen_intro = true
	_next_btn.pressed.connect(_next)
	_begin_btn.pressed.connect(_finish)
	_skip_btn.pressed.connect(_finish)
	_show_panel(0)


func _show_panel(index: int) -> void:
	_current = index
	var panel: Dictionary = PANELS[index]
	_title.text = panel["title"]
	_body.text = panel["body"]
	# Next on panels 0..N-2; Begin only on the last panel; Skip on all.
	var is_last: bool = index == PANELS.size() - 1
	_next_btn.visible = not is_last
	_begin_btn.visible = is_last


func _next() -> void:
	if _current < PANELS.size() - 1:
		_show_panel(_current + 1)


func _finish() -> void:
	EventBus.intro_finished.emit()
