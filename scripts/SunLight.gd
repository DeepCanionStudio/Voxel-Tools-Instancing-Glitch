extends DirectionalLight3D


# Called when the node enters the scene tree for the first time.
func _ready():
	Global.settings_changed.connect(update_settings)

func update_settings(variable, type):
	if type == 3:
		shadow_enabled = variable
