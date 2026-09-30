extends PopupPanel

const ROW := preload("res://shop/contract_row.tscn")
const BODY_FONT := preload("res://resources/fonts/RobotoCondensed-VariableFont_wght.ttf")
const HEADER_FONT_SIZE := 40
const SHEET_SIZE := Vector2i(984, 1400)
const SAFE_MARGIN := 48

var _session: Control

@onready var _rows: VBoxContainer = %Rows
@onready var _close_btn: Button = %CloseBtn


func _ready() -> void:
	_close_btn.pressed.connect(hide)
	get_parent().get_viewport().size_changed.connect(_on_viewport_resized)


func setup(session: Control) -> void:
	_session = session


func open() -> void:
	_rebuild()
	var rect := _popup_rect()
	popup(rect)
	# Embedded PopupPanel may keep its default 640x480 size after popup().
	position = rect.position
	size = rect.size


# The project-wide quit_on_go_back setting remains a separate screen-flow issue.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and visible:
		hide()


func calculate_popup_rect(safe_area: Rect2i, screen_transform: Transform2D, platform_name: String, viewport_size: Vector2i) -> Rect2i:
	var bounds := Rect2i(Vector2i.ZERO, viewport_size)
	if platform_name == "Android" and safe_area.has_area():
		var to_viewport := screen_transform.affine_inverse()
		var start := to_viewport * Vector2(safe_area.position)
		var end := to_viewport * Vector2(safe_area.end)
		bounds = bounds.intersection(Rect2i(Vector2i(start.round()), Vector2i((end - start).round())))
	var available := bounds.grow(-SAFE_MARGIN)
	var sheet_size := Vector2i(mini(SHEET_SIZE.x, available.size.x), mini(SHEET_SIZE.y, available.size.y))
	var position := available.position + (available.size - sheet_size) / 2
	return Rect2i(position, sheet_size)


func _popup_rect() -> Rect2i:
	# PopupPanel is a Window and therefore its own Viewport; use the shop's
	# viewport for the screen bounds and stretch transform.
	var viewport := get_parent().get_viewport()
	var screen_transform := viewport.get_screen_transform()
	var rect := calculate_popup_rect(DisplayServer.get_display_safe_area(), screen_transform, OS.get_name(), viewport.get_visible_rect().size)
	if is_embedded():
		return rect
	# Native Window popup rectangles use absolute screen pixels.
	var origin := screen_transform * Vector2(rect.position)
	var end := screen_transform * Vector2(rect.end)
	return Rect2i(Vector2i(origin.round()) + get_parent().get_window().position, Vector2i((end - origin).round()))


func _on_viewport_resized() -> void:
	if visible:
		var rect := _popup_rect()
		position = rect.position
		size = rect.size


func _rebuild() -> void:
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	for progress: RefCounted in _session.get_contracts():
		var contract: ContractDefinition = progress.definition
		_rows.add_child(_header("%s · %s" % [contract.name, ContractDefinition.sessions_left_text(progress.sessions_left)]))
		for requirement in contract.requirements:
			var row: HBoxContainer = ROW.instantiate()
			_rows.add_child(row)
			var have: int = _session.board.count_sellable(requirement.item.id, requirement.min_quality)
			row.setup(requirement, progress.delivered(requirement.item.id), have)
			row.give_requested.connect(_on_give_requested.bind(contract.id))


func _header(title: String) -> Label:
	var label := Label.new()
	label.text = title
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", BODY_FONT)
	label.add_theme_font_size_override("font_size", HEADER_FONT_SIZE)
	return label


func _on_give_requested(item_id: String, count: int, contract_id: String) -> void:
	_session.deliver_to_contract(contract_id, item_id, count)
	if _session.get_contracts().is_empty():
		hide()
	else:
		_rebuild()
