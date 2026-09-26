extends TextureRect

# Idle sword/bow badge showing whether a unit's attacks are melee or missile.
# Textures are exported so the placeholder VFX art can be swapped for proper
# icons without code changes.

@export var melee_texture: Texture2D
@export var missile_texture: Texture2D


func set_attack_type(attack_type: String) -> void:
	texture = melee_texture if attack_type == "melee" else missile_texture
