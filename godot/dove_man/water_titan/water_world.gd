extends "res://dove_man/horizon_variant/horizon_world.gd"
const WATER_SURFACE=preload("res://dove_man/water_titan/water_surface.gd")
var water_surface: Node3D
func create_godzilla() -> void:
	super.create_godzilla()
	if gz.player!=null: gz.player.seek(0.0,true)
	water_surface=Node3D.new()
	water_surface.set_script(WATER_SURFACE)
	(gz.root as Node3D).add_child(water_surface)
	water_surface.setup(gz.model,float(D.godzilla.height))
func update_godzilla(delta: float) -> void:
	super.update_godzilla(delta)
	if water_surface==null: return
	var radius:=Vector2(gz.root.position.x,gz.root.position.z).length()
	var fade_settings: Dictionary=D.godzilla.fade
	var visibility:=1.0-smoothstep(float(fade_settings.full_m),float(fade_settings.gone_m),radius)
	water_surface.update_surface(delta,visibility)

