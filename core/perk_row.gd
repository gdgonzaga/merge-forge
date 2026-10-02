extends PanelContainer

# One Guild perk on the charter screen: its level counting this charter's
# picks, what the next level gives, and what it costs.

signal pick_pressed(perk_id: String)

var perk_id: String = ""

@onready var _name: Label = %NameLabel
@onready var _desc: Label = %DescLabel
@onready var _next: Label = %NextLabel
@onready var _pick_btn: Button = %PickBtn


func _ready() -> void:
	_pick_btn.pressed.connect(_on_pick_pressed)


func show_perk(perk: PerkDefinition, owned: int, picked: int, can_pick: bool) -> void:
	perk_id = perk.id
	var level := owned + picked
	_name.text = "%s (%d/%d)" % [perk.name, level, perk.max_level()]
	_desc.text = perk.description if picked == 0 else "%s\nPicked: +%d" % [perk.description, picked]
	var next := perk.next_level(level)
	_next.text = "Max level" if next == null else "Next: %s" % describe_value(perk.effect, next.value)
	_pick_btn.text = "Max" if next == null else "Pick (%d pts)" % next.cost_points
	_pick_btn.disabled = next == null or not can_pick


static func describe_value(effect: String, value: float) -> String:
	match effect:
		"starting_gold":
			return "start with %d gold" % int(value)
		"xp_multiplier":
			return "shop XP x%d%%" % roundi(value * 100.0)
		"crate_discount":
			return "crates x%d%%" % roundi(value * 100.0)
		"starting_blueprint":
			var count := int(value)
			return "start with the town's %d cheapest blueprint%s" % [count, "" if count == 1 else "s"]
		"shelf_bonus":
			var slots := int(value)
			return "+%d shelf slot%s" % [slots, "" if slots == 1 else "s"]
		"loyalty_multiplier":
			return "loyalty x%d%%" % roundi(value * 100.0)
	return effect


func _on_pick_pressed() -> void:
	pick_pressed.emit(perk_id)
