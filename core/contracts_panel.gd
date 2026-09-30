extends VBoxContainer

# Prep shows next session's offers and contracts already in progress.

const CARD := preload("res://core/contract_card.tscn")

var _plan: SessionPlan

@onready var _slots_label: Label = %SlotsLabel
@onready var _offers: VBoxContainer = %Offers
@onready var _active_title: Label = %ActiveTitle
@onready var _active: VBoxContainer = %Active
@onready var _empty_label: Label = %EmptyLabel


func setup(plan: SessionPlan) -> void:
	_plan = plan
	_refresh()


func accept(contract_id: String) -> bool:
	var contract := DefinitionLibrary.get_contract(contract_id)
	if contract == null or _plan == null or not contract in _plan.contract_offers:
		return false
	if not _can_accept(contract, GameManager.get_contract_slots()):
		return false
	GameManager.active_contracts.append({"id": contract_id, "delivered": {}, "sessions_left": contract.sessions_allowed})
	EventBus.save_requested.emit()
	_refresh()
	return true


func _refresh() -> void:
	_clear(_offers)
	_clear(_active)
	var slots := GameManager.get_contract_slots()
	_slots_label.text = "Contract slots: %d/%d" % [GameManager.active_contracts.size(), slots]
	_slots_label.visible = slots > 0
	for contract in _plan.contract_offers:
		var card: PanelContainer = CARD.instantiate()
		_offers.add_child(card)
		card.show_offer(contract, _button_text(contract, slots), _can_accept(contract, slots))
		card.accept_pressed.connect(accept)
	for entry: Dictionary in GameManager.active_contracts:
		var contract := DefinitionLibrary.get_contract(entry["id"])
		if contract == null or contract in _plan.contract_offers:
			continue
		var card: PanelContainer = CARD.instantiate()
		_active.add_child(card)
		card.show_active(contract, entry)
	_active_title.visible = _active.get_child_count() > 0
	_empty_label.visible = _plan.contract_offers.is_empty()


func _can_accept(contract: ContractDefinition, slots: int) -> bool:
	return not _is_active(contract.id) and GameManager.active_contracts.size() < slots


func _button_text(contract: ContractDefinition, slots: int) -> String:
	if _is_active(contract.id):
		return "Accepted"
	if slots <= 0:
		return _upgrade_hint()
	if GameManager.active_contracts.size() >= slots:
		return "All slots in use"
	return "Accept"


func _upgrade_hint() -> String:
	for upgrade in DefinitionLibrary.get_all_upgrades():
		if upgrade.effect == "contract_slots":
			return "Needs %s" % upgrade.name
	return "No contract slots"


func _is_active(contract_id: String) -> bool:
	for entry: Dictionary in GameManager.active_contracts:
		if entry["id"] == contract_id:
			return true
	return false


func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
