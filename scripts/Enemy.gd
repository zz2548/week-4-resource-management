extends Node2D

@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D

func set_stage_index(stage_idx: int) -> void:
	var total: int = DataDb.enemies.size()
	if stage_idx < 0 or stage_idx >= total:
		anim_sprite.visible = false
		return
	anim_sprite.visible = true
	var enemy: Dictionary = DataDb.enemies[stage_idx]
	# Size: use "scale" in DataDB (number = uniform, or Vector2 for x/y)
	var scale_val = enemy.get("scale", 4.0)
	if scale_val is Vector2:
		anim_sprite.scale = scale_val
	elif scale_val is float or scale_val is int:
		var s: float = float(scale_val)
		anim_sprite.scale = Vector2(s, s)
	else:
		anim_sprite.scale = Vector2(4.0, 4.0)
	# Animation: prefer GUI-edited SpriteFrames (.tres), else "frames" or "image" from DataDB
	if enemy.has("sprite_frames"):
		var sf: Resource = load(enemy["sprite_frames"]) as SpriteFrames
		if sf:
			anim_sprite.sprite_frames = sf
			if sf.get_animation_names().size() > 0:
				anim_sprite.play(sf.get_animation_names()[0])
	else:
		var frames_data: Array = enemy.get("frames", [])
		if frames_data.size() > 0:
			_build_sprite_frames(frames_data, enemy)
		elif enemy.has("image"):
			_build_sprite_frames([enemy["image"]], enemy)
	# Playback speed multiplier (optional)
	var speed: float = enemy.get("animation_speed", 1.0)
	anim_sprite.speed_scale = speed

func _build_sprite_frames(frames_data: Array, enemy: Dictionary) -> void:
	var default_duration: float = 1.0
	if enemy.has("fps") and enemy["fps"] > 0:
		default_duration = 1.0 / float(enemy["fps"])
	elif enemy.has("frame_duration"):
		default_duration = float(enemy["frame_duration"])
	var sf := SpriteFrames.new()
	sf.add_animation("default")
	for i in range(frames_data.size()):
		var path: String = ""
		var duration: float = default_duration
		if frames_data[i] is String:
			path = frames_data[i]
		elif frames_data[i] is Dictionary:
			path = frames_data[i].get("path", "")
			if frames_data[i].has("duration"):
				duration = float(frames_data[i]["duration"])
		if path.is_empty():
			continue
		var tex: Texture2D = load(path) as Texture2D
		if tex:
			sf.add_frame("default", tex, duration)
	if sf.get_frame_count("default") > 0:
		anim_sprite.sprite_frames = sf
		anim_sprite.play("default")

func play_defeat_animation() -> void:
	var original_scale: Vector2 = anim_sprite.scale
	var original_pos: Vector2 = anim_sprite.position

	var tween: Tween = create_tween()
	tween.set_parallel(true)

	# Big shake — wider and faster
	tween.tween_method(_do_shake.bind(original_pos), 0.0, 1.0, 0.6)

	# Flash red repeatedly
	tween.tween_method(_do_flash, 0.0, 1.0, 0.6)

	# Slight scale punch up first
	tween.tween_property(anim_sprite, "scale", original_scale * 1.3, 0.1).set_trans(Tween.TRANS_BACK)

	await tween.finished

	# Fade to dust — shrink, drift upward, dissolve
	var dust_tween: Tween = create_tween()
	dust_tween.set_parallel(true)
	dust_tween.tween_property(anim_sprite, "modulate", Color(0.6, 0.4, 0.2, 0.0), 0.8).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	dust_tween.tween_property(anim_sprite, "scale", original_scale * 0.3, 0.8).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	dust_tween.tween_property(anim_sprite, "position", original_pos + Vector2(0, -60), 0.8).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)

	await dust_tween.finished
	anim_sprite.visible = false
	# Reset for next spawn
	anim_sprite.position = original_pos
	anim_sprite.scale = original_scale
	anim_sprite.modulate = Color.WHITE

func _do_shake(original_pos: Vector2, t: float) -> void:
	var intensity: float = 30.0 * (1.0 - t)
	anim_sprite.position = original_pos + Vector2(
		randf_range(-intensity, intensity),
		randf_range(-intensity * 0.3, intensity * 0.3)
	)

func _do_flash(t: float) -> void:
	var flicker: float = sin(t * 40.0)
	if flicker > 0.0:
		anim_sprite.modulate = Color(1.0, 0.2, 0.2, 1.0)
	else:
		anim_sprite.modulate = Color.WHITE
	
func play_spawn_animation() -> void:
	anim_sprite.modulate = Color(1, 1, 1, 0)
	anim_sprite.scale *= 0.5
	var original_scale: Vector2 = anim_sprite.scale / 0.5
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(anim_sprite, "modulate", Color.WHITE, 0.4)
	tween.tween_property(anim_sprite, "scale", original_scale, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
