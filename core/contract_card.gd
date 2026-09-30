extends PanelContainer

# One prep contract, shown as an offer or with its delivery progress.

signal accept_pressed(contract_id: String)

var _contract_id: String = ""

@onready var _title: Label = %TitleLabel
@onready var _giver: Label = %GiverLabel
@onready var _requirements: Label = %RequirementsLabel
@onready var _reward: Label = %RewardLabel
@onready var _sessions: Label = %SessionsLabel
@onready var _accept_btn: Button = %AcceptBtn


func _ready() -> void:
	_accept_btn.pressed.connect(_on_accept_pressed)


func show_offer(contract: ContractDefinition, button_text: String, can_accept: bool) -> void:
	_show_common(contract)
	var lines: PackedStringArray = []
	for requirement in contract.requirements:
		lines.append("%dx %s" % [requirement.min_quantity, requirement.item.name_at_quality(requirement.min_quality)])
	_requirements.text = "\n".join(lines)
	var sessions := contract.sessions_allowed
	_sessions.text = "1 session to deliver" if sessions == 1 else "%d sessions to deliver" % sessions
	_accept_btn.visible = true
	_accept_btn.text = button_text
	_accept_btn.disabled = not can_accept


func show_active(contract: ContractDefinition, entry: Dictionary) -> void:
	_show_common(contract)
	var delivered: Dictionary = entry["delivered"]
	var lines: PackedStringArray = []
	for requirement in contract.requirements:
		var count := int(delivered.get(requirement.item.id, 0))
		lines.append("%d/%d %s" % [count, requirement.min_quantity, requirement.item.name_at_quality(requirement.min_quality)])
	_requirements.text = "\n".join(lines)
	_sessions.text = ContractDefinition.sessions_left_text(int(entry["sessions_left"]))
	_accept_btn.visible = false


func _show_common(contract: ContractDefinition) -> void:
	_contract_id = contract.id
	_title.text = contract.name
	_giver.text = "From %s" % contract.giver.name
	_reward.text = "Reward: %s" % ", ".join(_reward_parts(contract))


func _reward_parts(contract: ContractDefinition) -> PackedStringArray:
	var parts: PackedStringArray = []
	if contract.reward_gold > 0:
		parts.append("%d gold" % contract.reward_gold)
	if contract.reward_blueprint != null:
		parts.append(contract.reward_blueprint.name)
	if contract.reward_reagent != null and contract.reward_reagent_count > 0:
		parts.append("%d %s" % [contract.reward_reagent_count, contract.reward_reagent.name])
	if contract.loyalty_points > 0:
		parts.append("+%d loyalty" % contract.loyalty_points)
	return parts


func _on_accept_pressed() -> void:
	accept_pressed.emit(_contract_id)
