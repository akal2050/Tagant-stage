@tool
extends EditorPlugin

const Component = preload("res://addons/taganat_arabesques/arabesque.gd")

func _enter_tree() -> void:
	add_tool_menu_item("Taganat: add botanical arabesque",_add_to_scene)

func _exit_tree() -> void:
	remove_tool_menu_item("Taganat: add botanical arabesque")

func _add_to_scene() -> void:
	var scene := get_editor_interface().get_edited_scene_root()
	if scene == null:
		push_warning("Open a 3D scene before adding a Taganat Arabesque.")
		return
	var garden := Component.new()
	garden.name = "TaganatArabesque"
	var undo := get_undo_redo()
	undo.create_action("Add Taganat botanical arabesque")
	undo.add_do_method(scene,"add_child",garden)
	undo.add_do_property(garden,"owner",scene)
	undo.add_do_reference(garden)
	undo.add_undo_method(scene,"remove_child",garden)
	undo.commit_action()
