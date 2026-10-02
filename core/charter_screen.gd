extends Control

# The Guild Hall: found a Guild Charter in a town, pick perks with charter
# points, and browse the codex. Founding is a hard reset, so the Found button
# only opens a confirm that says what is lost; only its Confirm founds.

const CONFIRM_DIALOG := preload("res://ui/confirm_dialog.tscn")
const TOUCH_LAYOUT := preload("res://ui/touch_layout.gd")
const PERK_ROW := preload("res://core/perk_row.tscn")
const SAFE_MARGIN := 48.0
const TAB_PADDING_VERTICAL := 42.0
const TOUCH_HEIGHT := 120.0

@onready var _layout: VBoxContainer = %VBox
@onready var _tabs: TabContainer = %Tabs
@onready var _status: Label = %StatusLabel
@onready var _points: Label = %PointsLabel
@onready var _breakdown: Label = %BreakdownLabel
@onready var _towns: VBoxContainer = %Towns
@onready var _town_desc: Label = %TownDescLabel
@onready var _perks: VBoxContainer = %Perks
@onready var _clear_btn: Button = %ClearPicksBtn
@onready var _back_btn: Button = %BackBtn
@onready var _found_btn: Button = %FoundBtn
@onready var _codex: VBoxContainer = %CodexPanel

var _town_id: String = ""
# One perk id per level picked, in pick order. Bought only when founding.
var _picks: Array[String] = []
var _dialog: PopupPanel


func _ready() -> void:
	TOUCH_LAYOUT.size_tabs_for_touch(_tabs, 32, TAB_PADDING_VERTICAL)
	_apply_display_safe_area()
	get_viewport().size_changed.connect(_apply_display_safe_area)
	_town_id = GameManager.current_town
	_back_btn.pressed.connect(EventBus.charter_closed.emit)
	_found_btn.pressed.connect(ask_to_found)
	_clear_btn.pressed.connect(clear_picks)
	_codex.setup()
	_refresh()


# Android back closes the confirm when it's open, else returns to prep.
func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST:
		return
	if _is_dialog_open():
		_dialog.hide()
	else:
		EventBus.charter_closed.emit()


func apply_safe_area(safe_area: Rect2i, screen_transform: Transform2D, platform_name: String) -> void:
	TOUCH_LAYOUT.inset_to_safe_area(_layout, get_viewport_rect().size, safe_area, screen_transform, platform_name, SAFE_MARGIN)


func select_town(town_id: String) -> void:
	var town := DefinitionLibrary.get_town(town_id)
	if town == null or not GameManager.is_town_open(town):
		return
	_town_id = town_id
	_refresh()


# Adds one level of `perk_id` when the points cover it and it isn't maxed.
func pick_perk(perk_id: String) -> bool:
	if not _can_pick(perk_id):
		return false
	_picks.append(perk_id)
	_refresh()
	return true


func clear_picks() -> void:
	_picks.clear()
	_refresh()


# Step one of two: only the dialog's Confirm founds.
func ask_to_found() -> void:
	if not _can_found() or _is_dialog_open():
		return
	_dialog = CONFIRM_DIALOG.instantiate()
	add_child(_dialog)
	_dialog.setup(_confirm_text(), confirm_found, Callable(), "Found", "Cancel")


func confirm_found() -> bool:
	var town_id := _town_id
	if not GameManager.found_charter(town_id, _picks):
		return false
	EventBus.save_requested.emit()
	EventBus.charter_founded.emit(town_id)
	return true


func _apply_display_safe_area() -> void:
	apply_safe_area(DisplayServer.get_display_safe_area(), get_viewport().get_screen_transform(), OS.get_name())


func _refresh() -> void:
	_status.text = _status_text()
	_points.text = "Charter points: %d banked + %d from this charter. %d left after your picks." % [
		GameManager.charter_points, GameManager.get_charter_points_earned(), _budget() - GameManager.perk_purchase_cost(_picks)]
	_breakdown.text = _breakdown_text()
	_breakdown.visible = GameManager.can_found_charter()
	_refresh_towns()
	_refresh_perks()
	_clear_btn.disabled = _picks.is_empty()
	_found_btn.disabled = not _can_found()
	_found_btn.text = "Found in %s" % DefinitionLibrary.get_town(_town_id).name


func _status_text() -> String:
	if not GameManager.can_found_charter():
		return "Reach shop level %d to found a charter (you are level %d)." % [
			DefinitionLibrary.get_shop_rules().charter_level, GameManager.get_shop_level()]
	return "Charters founded: %d. A charter starts a new shop from scratch; you keep your perks, codex and charter points." % GameManager.charters


func _breakdown_text() -> String:
	var rules := DefinitionLibrary.get_shop_rules()
	return "Base %d · Levels past %d: +%d · New codex stars: +%d · Families completed: %d x %d" % [
		rules.charter_base_points, rules.charter_level, rules.charter_level_points(GameManager.get_shop_level()),
		GameManager.get_new_codex_stars(), GameManager.get_new_codex_families().size(), rules.codex_family_points]


func _refresh_towns() -> void:
	_clear(_towns)
	for town in DefinitionLibrary.get_all_towns():
		var open := GameManager.is_town_open(town)
		var button := Button.new()
		button.toggle_mode = true
		button.button_pressed = town.id == _town_id
		button.disabled = not open
		button.text = town.name if open else "%s (opens at charter %d)" % [town.name, town.charters_required]
		button.custom_minimum_size = Vector2(0, TOUCH_HEIGHT)
		button.add_theme_font_size_override("font_size", 32)
		button.pressed.connect(select_town.bind(town.id))
		_towns.add_child(button)
	_town_desc.text = DefinitionLibrary.get_town(_town_id).description


func _refresh_perks() -> void:
	_clear(_perks)
	for perk in DefinitionLibrary.get_all_perks():
		var row: PanelContainer = PERK_ROW.instantiate()
		_perks.add_child(row)
		row.show_perk(perk, GameManager.get_perk_level(perk.id), _picks.count(perk.id), _can_pick(perk.id))
		row.pick_pressed.connect(pick_perk)


func _can_pick(perk_id: String) -> bool:
	var picks: Array[String] = _picks.duplicate()
	picks.append(perk_id)
	var cost := GameManager.perk_purchase_cost(picks)
	return cost >= 0 and cost <= _budget()


func _budget() -> int:
	return GameManager.charter_points + GameManager.get_charter_points_earned()


func _can_found() -> bool:
	var town := DefinitionLibrary.get_town(_town_id)
	return GameManager.can_found_charter() and town != null and GameManager.is_town_open(town)


func _is_dialog_open() -> bool:
	return _dialog != null and is_instance_valid(_dialog) and _dialog.visible


func _confirm_text() -> String:
	return "Found a charter in %s?\nYou lose your gold, shop level, blueprints, upgrades, board, shelf, reagents, contracts and loyalty.\nYou keep your charter points, perks and codex." % DefinitionLibrary.get_town(_town_id).name


# Removed at once so a rebuild never sees the old children.
func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
