@tool
extends EditorPlugin
## E06 — Lifecycle EditorPlugin: register/unregister/reload sạch.
## Bật/tắt plugin nhiều lần KHÔNG được nhân đôi dock hay action.

const H5DockScript := preload("res://addons/h5/h5_dock.gd")
const H5ExportScript := preload("res://addons/h5/h5_export_plugin.gd")

var _dock: Control = null
var _export_plugin: EditorExportPlugin = null

func _enter_tree() -> void:
	# Export plugin trước, để hook sẵn sàng khi người dùng mở hộp thoại Export.
	if _export_plugin == null:
		_export_plugin = H5ExportScript.new()
		add_export_plugin(_export_plugin)

	if _dock == null:
		_dock = H5DockScript.new()
		_dock.name = "H5"
		add_control_to_dock(EditorPlugin.DOCK_SLOT_RIGHT_UL, _dock)

	print("H5 Platform: plugin đã bật.")

func _exit_tree() -> void:
	if _dock != null:
		remove_control_from_docks(_dock)
		_dock.queue_free()
		_dock = null

	if _export_plugin != null:
		remove_export_plugin(_export_plugin)
		_export_plugin = null

	print("H5 Platform: plugin đã tắt.")

func _get_plugin_name() -> String:
	return "H5 Platform"
