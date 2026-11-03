class_name SaveScreen
extends Control
## Modal "Réglages" screen: the game version, the "Effets visuels", "Défi auto" and "Plein écran"
## toggles, a button that copies the save as text for a bug report, and a button that resets the
## save after a confirmation. The dark background stops every click and the keyboard focus stays
## inside. Pure presentation: a press is reported through a signal and the composition root acts on
## it. The effects toggle goes to [DisplaySettings], never to the save. "Défi auto" and the version
## left the main screen for this one (story 019b); "Plein écran" only shows where the browser allows
## it, and the root tells it the real state again when the player leaves full screen by other means.
##
## Usage:
## [codeblock]
## screen.copy_requested.connect(func() -> void: screen.show_copied(save_text))
## screen.reset_confirmed.connect(on_reset)
## screen.effects_toggled.connect(on_effects)
## screen.auto_challenge_toggled.connect(on_auto)
## screen.fullscreen_toggled.connect(on_fullscreen)
## screen.closed.connect(on_closed)
## screen.setup("0.1.0")
## screen.set_effects(true)
## screen.set_auto_challenge(false)
## screen.set_fullscreen(OS.has_feature("web"), false)
## screen.open()
## [/codeblock]

## Top and bottom margins and borders of the panel style of the theme, ModalPanel.
const PANEL_VERTICAL_MARGINS: float = 38.0

## The player asked to copy the save.
signal copy_requested
## The player confirmed the reset.
signal reset_confirmed
## The player switched the visual effects to [param enabled].
signal effects_toggled(enabled: bool)
## The player switched the automatic boss challenge to [param enabled].
signal auto_challenge_toggled(enabled: bool)
## The player asked for full screen ([param enabled]) or to leave it.
signal fullscreen_toggled(enabled: bool)
## The screen was hidden (close button, Escape or [method close]).
signal closed

@onready var _panel: PanelContainer = %Panel
@onready var _content: VBoxContainer = %Content
@onready var _version_label: Label = %VersionLabel
@onready var _effects_toggle: Button = %EffectsToggle
@onready var _auto_toggle: Button = %AutoChallengeToggle
@onready var _fullscreen_toggle: Button = %FullscreenToggle
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
	_effects_toggle.toggled.connect(_on_effects_toggled)
	_auto_toggle.toggled.connect(_on_auto_toggled)
	_fullscreen_toggle.toggled.connect(_on_fullscreen_toggled)
	resized.connect(_fit_panel)
	_content.minimum_size_changed.connect(_fit_panel)
	_fit_panel()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


## Shows [param version] on the screen. Call once.
func setup(version: String) -> void:
	_version_label.text = tr("Catitans, version %s") % version


## Shows the state of the visual effects, without reporting it back.
func set_effects(enabled: bool) -> void:
	_effects_toggle.set_pressed_no_signal(enabled)
	_effects_toggle.text = tr("Effets visuels : OUI") if enabled else tr("Effets visuels : NON")


## Shows the state of the automatic boss challenge, without reporting it back.
func set_auto_challenge(enabled: bool) -> void:
	_auto_toggle.set_pressed_no_signal(enabled)
	_auto_toggle.text = tr("Défi auto : OUI") if enabled else tr("Défi auto : NON")


## Shows the full screen toggle when [param available], in the state [param enabled], without
## reporting it back. Called again whenever the window changes: leaving full screen with the back
## gesture or Escape never goes through the toggle.
func set_fullscreen(available: bool, enabled: bool) -> void:
	_fullscreen_toggle.visible = available
	_fullscreen_toggle.set_pressed_no_signal(enabled)
	_fullscreen_toggle.text = tr("Plein écran : OUI") if enabled else tr("Plein écran : NON")


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


func _on_effects_toggled(enabled: bool) -> void:
	set_effects(enabled)
	effects_toggled.emit(enabled)


func _on_auto_toggled(enabled: bool) -> void:
	set_auto_challenge(enabled)
	auto_challenge_toggled.emit(enabled)


# The label waits for the root: the browser may refuse full screen, and the window then says so.
func _on_fullscreen_toggled(enabled: bool) -> void:
	fullscreen_toggled.emit(enabled)


# As tall as its content, so that no hole opens in it; the content scrolls in a short window.
func _fit_panel() -> void:
	var wanted: float = _content.get_combined_minimum_size().y + PANEL_VERTICAL_MARGINS
	var rect: Rect2 = AdaptiveLayout.modal_rect(size, wanted)
	_panel.position = rect.position
	_panel.size = rect.size


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
