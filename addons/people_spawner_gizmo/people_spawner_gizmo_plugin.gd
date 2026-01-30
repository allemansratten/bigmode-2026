@tool
extends EditorPlugin

const PeopleSpawnerGizmo = preload("res://addons/people_spawner_gizmo/people_spawner_gizmo.gd")

var gizmo_plugin: EditorNode3DGizmoPlugin


func _enter_tree() -> void:
	gizmo_plugin = PeopleSpawnerGizmo.new()
	add_node_3d_gizmo_plugin(gizmo_plugin)


func _exit_tree() -> void:
	remove_node_3d_gizmo_plugin(gizmo_plugin)
