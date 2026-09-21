extends Node3D
## Rigged LIRA presentation using a real humanoid skeleton and imported clips.
## Gameplay remains 2D: this node only reads Runner state and drives visuals.
##
## Source character: Quaternius Ultimate Modular Men / Casual Hoodie (CC0).
## The glTF contains one humanoid skin plus 24 baked animation clips.
##
## Visual goal: a responsive platform-character silhouette. Physics stays in
## Runner; this layer exaggerates take-off, apex, landing, sprint, skid and
## chained jumps without changing collision, timing, networking or controls.
const CLOTH := Color("e2a334")
const AVATAR_SCENE := preload("res://assets/models/third_party/quaternius/casual_hoodie.gltf")
const AVATAR_SCALE := 28.0

const LAND_SQUASH_TIME := 0.13
const TAKEOFF_STRETCH_TIME := 0.10
const TRIPLE_SPIN_SPEED := TAU * 1.45

const IDLE_CLIPS := ["Idle_Neutral", "Idle"]
const WALK_CLIPS := ["Walk", "Walking", "Run"]
const RUN_CLIPS := ["Run", "Running", "Walk"]
const JUMP_UP_CLIPS := ["Jump_Start", "JumpStart", "Jump_Up", "JumpUp", "Jump", "Idle_Neutral", "Idle"]
const APEX_CLIPS := ["Jump_Idle", "JumpIdle", "Jump", "Idle_Neutral", "Idle"]
const FALL_CLIPS := ["Fall", "Falling", "Jump_Fall", "JumpFall", "Jump_Idle", "Jump", "Idle_Neutral", "Idle"]
const LAND_CLIPS := ["Land", "Landing", "Jump_Land", "JumpLand", "Idle_Neutral", "Idle"]
const CROUCH_CLIPS := ["Crouch_Idle", "CrouchIdle", "Crouch", "Idle_Neutral", "Idle"]
const ROLL_CLIPS := ["Roll", "Run"]
const HIT_CLIPS := ["HitRecieve", "HitReceive", "HitRecieve_2", "HitReact", "Hit", "Idle_Neutral", "Idle"]
const DEATH_CLIPS := ["Death", "Die", "Idle_Neutral", "Idle"]
const HANG_CLIPS := ["Climb", "Hang", "Idle_Neutral", "Idle"]
const WALL_KICK_LEFT_CLIPS := ["Kick_Left", "Kick_Right", "Roll", "Run"]
const WALL_KICK_RIGHT_CLIPS := ["Kick_Right", "Kick_Left", "Roll", "Run"]

var rig_root: Node3D
var spin_root: Node3D
var motion_root: Node3D
var avatar: Node3D
var animation_player: AnimationPlayer
var current_clip: StringName = &""
var pose := "idle"

var _was_grounded := true
var _air_time := 0.0
var _landing_time := 0.0
var _last_face := 1
var _turn_flash := 0.0
var _triple_spin_angle := 0.0

func _init(accent: Color = CLOTH) -> void:
	rig_root = Node3D.new()
	rig_root.name = "RigRoot"
	add_child(rig_root)

	spin_root = Node3D.new()
	spin_root.name = "SpinRoot"
	rig_root.add_child(spin_root)

	motion_root = Node3D.new()
	motion_root.name = "MotionRoot"
	spin_root.add_child(motion_root)

	avatar = AVATAR_SCENE.instantiate()
	avatar.name = "RiggedLira"
	motion_root.add_child(avatar)
	rig_root.scale = Vector3.ONE * AVATAR_SCALE

	animation_player = _find_animation_player(avatar)
	_disable_shadows(avatar)
	_apply_accent(avatar, accent)
	_set_looping(IDLE_CLIPS)
	_set_looping(WALK_CLIPS)
	_set_looping(RUN_CLIPS)
	_play_first(IDLE_CLIPS, 1.0, 0.0)

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null

func _disable_shadows(node: Node) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_disable_shadows(child)

func _apply_accent(node: Node, accent: Color) -> void:
	if accent != CLOTH and node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null:
			for surface in mesh_instance.mesh.get_surface_count():
				var source := mesh_instance.mesh.surface_get_material(surface)
				if source is StandardMaterial3D and source.resource_name in ["Purple", "LightBlue"]:
					var material := source.duplicate() as StandardMaterial3D
					material.albedo_color = accent
					mesh_instance.set_surface_override_material(surface, material)
	for child in node.get_children():
		_apply_accent(child, accent)

func _set_looping(candidates: Array) -> void:
	if animation_player == null:
		return
	var clip := _resolve_clip(candidates)
	if clip == &"":
		return
	var animation := animation_player.get_animation(clip)
	if animation != null:
		animation.loop_mode = Animation.LOOP_LINEAR

func _play_first(candidates: Array, speed: float = 1.0, blend: float = 0.08) -> void:
	if animation_player == null:
		return
	var clip := _resolve_clip(candidates)
	if clip == &"":
		return
	if current_clip != clip:
		animation_player.play(clip, blend, speed)
		current_clip = clip
	else:
		animation_player.speed_scale = speed

func _resolve_clip(candidates: Array) -> StringName:
	if animation_player == null:
		return &""
	for candidate in candidates:
		if animation_player.has_animation(StringName(candidate)):
			return StringName(candidate)
	for available in animation_player.get_animation_list():
		var lower := String(available).to_lower()
		for candidate in candidates:
			var wanted := String(candidate).to_lower()
			if lower.ends_with(wanted) or lower.ends_with("/" + wanted):
				return StringName(available)
	return &""

func available_animation_count() -> int:
	return animation_player.get_animation_list().size() if animation_player != null else 0

func animate(delta: float, velocity: Vector2, grounded: bool, state: int, face: int,
		crouch: bool = false, pound: bool = false, wall: bool = false,
		wall_kick: bool = false, jump_chain: int = 0) -> void:
	var speed := absf(velocity.x)
	var clip_speed := clampf(speed / 210.0, 0.72, 1.75)
	var just_landed := grounded and not _was_grounded
	var just_left_ground := not grounded and _was_grounded

	if just_landed:
		_landing_time = LAND_SQUASH_TIME
		_air_time = 0.0
	elif grounded:
		_landing_time = maxf(0.0, _landing_time - delta)
		_air_time = 0.0
	else:
		if just_left_ground:
			_air_time = 0.0
			spin_root.rotation.z = 0.0
			_triple_spin_angle = 0.0
		_air_time += delta

	if face != _last_face and grounded and speed > 70.0:
		_turn_flash = 0.10
	_turn_flash = maxf(0.0, _turn_flash - delta)
	_last_face = face
	_was_grounded = grounded

	var skidding := grounded and speed > 70.0 and signf(velocity.x) != 0.0 		and signi(int(signf(velocity.x))) != face
	var target_lean := 0.0
	var target_scale := Vector3.ONE
	var target_offset_y := 0.0

	if state == Runner.State.DEAD:
		pose = "dead"
		_play_first(DEATH_CLIPS, 1.0)
		target_lean = float(face) * 1.35
		target_scale = Vector3(1.04, 0.90, 1.04)
	elif state == Runner.State.HURT:
		pose = "hurt"
		_play_first(HIT_CLIPS, 1.0)
		target_lean = float(face) * 0.34
		target_scale = Vector3(1.06, 0.92, 1.02)
	elif pound:
		pose = "pound"
		_play_first(ROLL_CLIPS, 1.05)
		target_scale = Vector3(0.90, 1.10, 0.94)
		target_lean = -float(face) * 0.08
	elif wall_kick:
		pose = "wall_kick"
		_play_first(WALL_KICK_RIGHT_CLIPS if face > 0 else WALL_KICK_LEFT_CLIPS, 1.15, 0.035)
		target_lean = -float(face) * 0.30
		target_scale = Vector3(0.94, 1.08, 1.0)
		target_offset_y = 0.015
	elif wall or state == Runner.State.HANG:
		pose = "wall" if wall else "hang"
		_play_first(HANG_CLIPS, 0.85)
		target_lean = float(face) * 0.13
		target_scale = Vector3(0.96, 1.04, 1.0)
	elif crouch:
		if grounded and speed > 80.0:
			pose = "slide"
			_play_first(ROLL_CLIPS, maxf(1.0, clip_speed))
			target_lean = -float(face) * 0.22
		else:
			pose = "crouch"
			_play_first(CROUCH_CLIPS, 1.0)
		target_scale = Vector3(1.08, 0.72, 1.04)
		target_offset_y = -0.02
	elif not grounded:
		if velocity.y < -65.0:
			pose = "rise"
			_play_first(JUMP_UP_CLIPS, 1.0)
			target_lean = -float(face) * 0.09
		elif velocity.y > 90.0:
			pose = "fall"
			_play_first(FALL_CLIPS, 1.0)
			target_lean = float(face) * 0.07
		else:
			pose = "apex"
			_play_first(APEX_CLIPS, 0.9)
			target_scale = Vector3(1.03, 0.97, 1.02)

		if _air_time < TAKEOFF_STRETCH_TIME:
			var takeoff := 1.0 - _air_time / TAKEOFF_STRETCH_TIME
			target_scale.x *= lerpf(1.0, 0.93, takeoff)
			target_scale.y *= lerpf(1.0, 1.10 + 0.03 * minf(float(jump_chain), 3.0), takeoff)

		# Chained jumps read as three distinct take-offs. The second carries a
		# stronger forward pose; the third performs one complete forward somersault.
		# This is presentation only: the CharacterBody2D remains authoritative.
		if jump_chain >= 3:
			_play_first(ROLL_CLIPS, 1.20, 0.035)
			target_scale *= Vector3(0.94, 0.96, 0.96)
			_triple_spin_angle = minf(TAU, _triple_spin_angle + TRIPLE_SPIN_SPEED * delta)
			spin_root.rotation.z = float(face) * _triple_spin_angle
		elif jump_chain == 2:
			target_lean += -float(face) * 0.16
			target_scale *= Vector3(0.97, 1.04, 1.0)
	elif _landing_time > 0.0:
		pose = "land"
		_play_first(LAND_CLIPS, 1.0)
		var impact := clampf(_landing_time / LAND_SQUASH_TIME, 0.0, 1.0)
		target_scale = Vector3(
			lerpf(1.0, 1.13, impact),
			lerpf(1.0, 0.78, impact),
			lerpf(1.0, 1.06, impact)
		)
	elif state == Runner.State.DASH:
		pose = "dash"
		_play_first(RUN_CLIPS, maxf(1.3, clip_speed))
		target_lean = -float(face) * 0.24
		target_scale = Vector3(1.02, 0.98, 1.0)
	elif skidding or _turn_flash > 0.0:
		pose = "skid"
		_play_first(RUN_CLIPS, maxf(0.75, clip_speed * 0.75))
		target_lean = float(face) * 0.26
		target_scale = Vector3(1.04, 0.96, 1.0)
	elif speed > 300.0:
		pose = "sprint"
		_play_first(RUN_CLIPS, clip_speed)
		target_lean = -float(face) * 0.13
	elif speed > 35.0:
		pose = "run"
		_play_first(RUN_CLIPS, clip_speed)
		target_lean = -float(face) * 0.06
	elif speed > 5.0:
		pose = "walk"
		_play_first(WALK_CLIPS, clampf(speed / 150.0, 0.65, 1.1))
	else:
		pose = "idle"
		_play_first(IDLE_CLIPS, 1.0)

	var blend := 1.0 - exp(-delta * 18.0)
	rig_root.rotation.y = lerp_angle(
		rig_root.rotation.y,
		-PI * 0.5 if face >= 0 else PI * 0.5,
		blend
	)
	rig_root.scale = Vector3.ONE * AVATAR_SCALE

	if grounded or jump_chain < 3:
		spin_root.rotation.z = lerp_angle(spin_root.rotation.z, 0.0, minf(1.0, blend * 1.5))
		if grounded:
			_triple_spin_angle = 0.0
	motion_root.rotation.z = lerp_angle(motion_root.rotation.z, target_lean, blend)
	motion_root.scale = motion_root.scale.lerp(target_scale, blend)
	motion_root.position.y = lerpf(motion_root.position.y, target_offset_y, blend)
