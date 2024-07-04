extends WorldEnvironment



func _ready():
	Global.settings_changed.connect(change_variable)



func change_variable(variable, type):
	match type:
		0:
			environment.glow_enabled = variable
		1:
			environment.ssao_enabled = variable
		2:
			environment.ssil_enabled = variable
