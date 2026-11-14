## Opens the phone's on-screen keyboard for LineEdits on the Web. Registered as the Autoload
## "WebKeyboard".
##
## Godot's own web keyboard does not open on iOS: Safari only shows the keyboard when an
## <input> is focused synchronously inside the touch event, and Godot handles input a frame
## later. So on touch devices a real <input> is put over the tapped LineEdit by a script that
## runs in the touch handler, and what is typed is copied back into the LineEdit.
extends Node

const JS_SETUP := """
(function () {
	if (window.ctKeyboard) { return; }
	var canvas = document.getElementById('canvas') || document.querySelector('canvas');
	var input = document.createElement('input');
	input.type = 'text';
	input.autocomplete = 'off';
	input.autocapitalize = 'off';
	input.spellcheck = false;
	input.setAttribute('autocorrect', 'off');
	input.setAttribute('enterkeyhint', 'done');
	// 16px or more stops iOS from zooming into the field.
	input.style.cssText = 'position:fixed;left:0;top:0;width:10px;height:10px;opacity:0;' +
		'font-size:16px;border:0;padding:0;margin:0;z-index:-1;';
	document.body.appendChild(input);

	var kb = { fields: [], active: -1, onEvent: null };
	window.ctKeyboard = kb;

	function send(event) { if (kb.onEvent) { kb.onEvent(JSON.stringify(event)); } }

	kb.setFields = function (json) { kb.fields = JSON.parse(json); };

	function hit(touch) {
		var box = canvas.getBoundingClientRect();
		var sx = box.width / canvas.width, sy = box.height / canvas.height;
		for (var i = 0; i < kb.fields.length; i++) {
			var f = kb.fields[i];
			var l = box.left + f.x * sx, t = box.top + f.y * sy;
			var w = f.w * sx, h = f.h * sy;
			if (touch.clientX >= l && touch.clientX <= l + w &&
					touch.clientY >= t && touch.clientY <= t + h) {
				return { field: f, left: l, top: t, width: w, height: h };
			}
		}
		return null;
	}

	var lastHit = 0;
	['mousedown', 'mouseup', 'click'].forEach(function (name) {
		window.addEventListener(name, function (e) {
			if (Date.now() - lastHit < 800) { e.preventDefault(); e.stopImmediatePropagation(); }
		}, true);
	});

	canvas.addEventListener('touchend', function (e) {
		var touch = e.changedTouches[0];
		var found = touch ? hit(touch) : null;
		if (!found) {
			if (kb.active >= 0) { input.blur(); }
			return;
		}
		// The browser follows a touch with fake mouse events, and Godot answers those by
		// focusing the canvas, which closes the keyboard again. Cancel them.
		e.preventDefault();
		lastHit = Date.now();
		// Must happen here, inside the gesture, or iOS keeps the keyboard closed.
		input.style.left = found.left + 'px';
		input.style.top = found.top + 'px';
		input.style.width = found.width + 'px';
		input.style.height = found.height + 'px';
		input.maxLength = found.field.max > 0 ? found.field.max : 524288;
		input.value = found.field.text;
		kb.active = found.field.id;
		input.focus();
		send({ kind: 'focus', id: found.field.id });
	}, true);

	input.addEventListener('input', function () {
		send({ kind: 'text', id: kb.active, text: input.value });
	});
	input.addEventListener('keydown', function (e) {
		if (e.key === 'Enter') {
			send({ kind: 'submit', id: kb.active });
			input.blur();
		}
	});
	input.addEventListener('blur', function () {
		var id = kb.active;
		kb.active = -1;
		send({ kind: 'blur', id: id });
	});
})();
"""

var _active: bool = false
var _edits: Array[LineEdit] = []
var _callback: RefCounted = null
var _last_fields: String = ""

func _ready() -> void:
	_active = OS.has_feature("web") and DisplayServer.is_touchscreen_available()
	set_process(_active)
	if not _active:
		return

	JavaScriptBridge.eval(JS_SETUP, true)
	_callback = JavaScriptBridge.create_callback(_on_js_event)
	JavaScriptBridge.get_interface("ctKeyboard").onEvent = _callback

	get_tree().node_added.connect(_on_node_added)
	_scan(get_tree().root)

func _scan(node: Node) -> void:
	_on_node_added(node)
	for child: Node in node.get_children():
		_scan(child)

func _on_node_added(node: Node) -> void:
	if not node is LineEdit or _edits.has(node):
		return
	var edit: LineEdit = node
	# The <input> above does the typing, so Godot must not open a second keyboard.
	edit.virtual_keyboard_enabled = false
	_edits.append(edit)
	edit.tree_exited.connect(_edits.erase.bind(edit))

# Tells the page where the LineEdits are, in canvas pixels, whenever they move.
func _process(_delta: float) -> void:
	var fields: Array = []
	var to_canvas: Transform2D = get_viewport().get_screen_transform()
	for i in _edits.size():
		var edit: LineEdit = _edits[i]
		if not edit.is_visible_in_tree() or not edit.editable:
			continue
		var box: Rect2 = to_canvas * edit.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, edit.size)
		fields.append({
			"id": i, "x": box.position.x, "y": box.position.y,
			"w": box.size.x, "h": box.size.y,
			"text": edit.text, "max": edit.max_length,
		})

	var json: String = JSON.stringify(fields)
	if json == _last_fields:
		return
	_last_fields = json
	JavaScriptBridge.get_interface("ctKeyboard").setFields(json)

func _on_js_event(args: Array) -> void:
	var event: Variant = JSON.parse_string(str(args[0]))
	if not event is Dictionary:
		return
	var id: int = int(event.get("id", -1))
	if id < 0 or id >= _edits.size():
		return
	var edit: LineEdit = _edits[id]

	match event.get("kind", ""):
		"focus":
			edit.grab_focus()
		"text":
			edit.text = str(event.get("text", ""))
			edit.caret_column = edit.text.length()
			edit.text_changed.emit(edit.text)
		"submit":
			edit.text_submitted.emit(edit.text)
		"blur":
			edit.release_focus()
