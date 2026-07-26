extends PopupPanel

# Reusable yes/no confirm. Instantiate on demand, call setup(), and it frees
# itself after the user answers. Reports results via callbacks (not signals)
# because it's a one-shot, single-subscriber component.
#
# Safety property: the confirm callback fires ONLY on an explicit Confirm
# press. Cancel-button, tap-outside, and Esc all route to the cancel callback.
# This mirrors the dismissal handling fixed in merge_choice_popup.gd (C2).

var _on_confirm_cb: Callable
var _on_cancel_cb: Callable
# True once the user picked a side via a button, so a popup_hide triggered by
# that pick is not also treated as a cancel.
var _answered: bool = false

@onready var _message: Label = $Margin/VBox/MessageLabel
@onready var _confirm_btn: Button = $Margin/VBox/BtnBox/ConfirmBtn
@onready var _cancel_btn: Button = $Margin/VBox/BtnBox/CancelBtn


func _ready() -> void:
	popup_hide.connect(_on_popup_hide)
	_confirm_btn.pressed.connect(_on_confirm_pressed)
	_cancel_btn.pressed.connect(_on_cancel_pressed)


# `on_cancel` defaults to empty: most callers have nothing to do on cancel.
# Empty Callables are NOT safe to call in Godot 4 (they error "null::null"),
# so every invocation site must guard with .is_valid() before calling.
#
# Must be called after the dialog has been added to the scene tree — @onready
# node refs and popup_centered() both require the node to be in-tree. The
# intended usage is: instantiate -> add_child -> setup.
func setup(
	prompt: String,
	on_confirm: Callable,
	on_cancel: Callable = Callable(),
	confirm_text := "Confirm",
	cancel_text := "Cancel",
) -> void:
	_on_confirm_cb = on_confirm
	_on_cancel_cb = on_cancel
	_message.text = prompt
	_confirm_btn.text = confirm_text
	_cancel_btn.text = cancel_text
	popup_centered()


func _on_confirm_pressed() -> void:
	_answered = true
	hide()
	if _on_confirm_cb.is_valid():
		_on_confirm_cb.call()


func _on_cancel_pressed() -> void:
	_answered = true
	hide()
	if _on_cancel_cb.is_valid():
		_on_cancel_cb.call()


func _on_popup_hide() -> void:
	# A real answer hides the popup with _answered == true; only an external
	# dismissal (Esc / tap-outside) reaches here. Those count as cancel — never
	# confirm — so there's no path where the popup vanishes and the destructive
	# action runs without an explicit Confirm press.
	if _answered:
		queue_free()
		return
	if _on_cancel_cb.is_valid():
		_on_cancel_cb.call()
	queue_free()
