class_name SaveScreen
extends Control
## Modal "Ma sauvegarde" screen: the game version, a button that copies the save as text for a
## bug report, and a button that resets the save after a confirmation. The dark background
## stops every click and the keyboard focus stays inside, as on the talent tree. Pure
## presentation: a press is reported through a signal and the composition root acts on it.
##
## Usage:
## [codeblock]
## screen.copy_requested.connect(func() -> void: screen.show_copied(save_text))
## screen.reset_confirmed.connect(on_reset)
## screen.closed.connect(on_closed)
## screen.setup("0.1.0")
## screen.open()
## [/codeblock]

## The player asked to copy the save.
signal copy_requested
## The player confirmed the reset.
signal reset_confirmed
## The screen was hidden (close button, Escape or [method close]).
signal closed

@onready var _version_label: Label = %VersionLabel
@onready var _copy_button: Button = %CopyButton
@onready var _copy_status: Label = %CopyStatus
@onready var _save_text: TextEdit = %SaveText
@onready var _reset_button: Button = %ResetButton
@onready var _confirm_box: VBoxContainer = %ConfirmBox
@onready var _confirm_label: Label = %ConfirmLabel
@onready var _confirm_button: Button = %ConfirmButton
@onready var _cancel_button: Button = %CancelButton
@onready var _close_button: Button = %CloseButton


func _ready() -> void:
	_copy_button.pressed.connect(func() -> void: copy_requested.emit())
	_reset_button.pressed.connect(_ask_confirmation)
	_confirm_button.pressed.connect(func() -> void: reset_confirmed.emit())
	_cancel_button.pressed.connect(_cancel_confirmation)
	_close_button.pressed.connect(close)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


## Shows [param version] on the screen. Call once.
func setup(version: String) -> void:
	_version_label.text = tr("Version %s") % version


## Shows the screen in its first state and gives the focus to the close button. As with the talent
## tree, the caller first disables the focus of the main screen.
func open() -> void:
	_copy_status.visible = false
	_save_text.visible = false
	_save_text.text = ""
	_show_confirmation(false)
	visible = true
	_close_button.grab_focus()


## Hides the screen and emits [signal closed]. Does nothing when it is not open.
func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


## Tells the player the save was sent to the clipboard and shows [param text], which they can
## select by hand if the browser refused the copy.
func show_copied(text: String) -> void:
	_copy_status.text = tr("Sauvegarde copiée. Si rien ne se colle, sélectionne le texte ci-dessous.")
	_copy_status.visible = true
	_save_text.text = text
	_save_text.visible = true


## Tells the player the reset failed. The save may be partly written: they can try again.
func show_reset_failed() -> void:
	_confirm_label.text = tr("La réinitialisation a échoué. Tu peux réessayer.")


func _ask_confirmation() -> void:
	_confirm_label.text = tr("Tout effacer ? Étage, or, compagnons, talents et objets seront perdus. C'est définitif.")
	_show_confirmation(true)
	# The safe answer takes the focus: Enter must not erase by reflex.
	_cancel_button.grab_focus()


func _cancel_confirmation() -> void:
	_show_confirmation(false)
	_reset_button.grab_focus()


func _show_confirmation(shown: bool) -> void:
	_confirm_box.visible = shown
	_reset_button.visible = not shown
