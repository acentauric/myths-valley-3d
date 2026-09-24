extends Node
## Temporary procedural bone animation for the supplied, unanimated Tripo FBX.
## This is not a Mixamo animation clip. Replace with authored clips for production.
## The inspected model is Y-up, faces +Z, and has asymmetric bone rest rotations.

var _skeleton: Skeleton3D
var _bones: Dictionary = {}
var _phase: float = 0.0
var _clock: float = 0.0
var _blend: float = 0.0
var _run_blend: float = 0.0


func configure(model: Node3D) -> void:
	_skeleton = _find_skeleton(model)
	_bones.clear()
	_phase = 0.0
	_clock = 0.0
	_blend = 0.0
	_run_blend = 0.0
	if _skeleton == null:
		push_warning("Prototype: character has no Skeleton3D for procedural locomotion.")
		return
	for suffix in ["Hips", "Spine", "Spine1", "Spine2", "Head", "LeftArm", "RightArm", "LeftForeArm", "RightForeArm", "LeftUpLeg", "RightUpLeg", "LeftLeg", "RightLeg", "LeftFoot", "RightFoot"]:
		var index: int = _skeleton.find_bone("mixamorig_" + suffix)
		if index == -1:
			continue
		var rest: Transform3D = _skeleton.get_bone_rest(index)
		_bones[suffix] = {
			"index": index,
			"parent": _skeleton.get_bone_parent(index),
			"rotation": rest.basis.orthonormalized().get_rotation_quaternion(),
		}
	update_motion(0.0, 0.0)


func update_motion(speed: float, delta: float) -> void:
	if not is_instance_valid(_skeleton):
		return
	_clock += delta
	var moving: float = clampf(speed / 1.0, 0.0, 1.0)
	var smoothing: float = 1.0 - exp(-10.0 * delta)
	_blend = lerpf(_blend, moving, smoothing)
	_run_blend = lerpf(_run_blend, clampf((speed - 3.0) / 3.0, 0.0, 1.0), smoothing)
	_phase += delta * lerpf(8.5, 13.0, _run_blend) * minf(speed / 2.4, 1.0)
	var stride: float = sin(_phase) * _blend
	var stride_opposite: float = -stride
	var leg_angle: float = lerpf(0.42, 0.68, _run_blend)
	var arm_angle: float = lerpf(0.30, 0.55, _run_blend)
	var knee_angle: float = lerpf(0.66, 1.05, _run_blend)
	var breath: float = sin(_clock * 2.1) * 0.009 * (1.0 - _blend * 0.6)

	# Pose parents first so each child's axes include the current torso pose.
	_pose("Hips", Quaternion(Vector3.UP, stride * 0.025) * Quaternion(Vector3.BACK, stride * 0.018))
	_pose("Spine", Quaternion(Vector3.RIGHT, breath + _run_blend * 0.07))
	_pose("Spine1", Quaternion(Vector3.UP, -stride * 0.035))
	_pose("Spine2", Quaternion(Vector3.RIGHT, breath * 0.5))

	# Skeleton-space X swings a down-pointing limb forward/back in the Z plane.
	_pose("LeftUpLeg", Quaternion(Vector3.RIGHT, -stride * leg_angle))
	_pose("RightUpLeg", Quaternion(Vector3.RIGHT, -stride_opposite * leg_angle))
	_pose("LeftLeg", Quaternion(Vector3.RIGHT, maxf(0.0, stride) * knee_angle))
	_pose("RightLeg", Quaternion(Vector3.RIGHT, maxf(0.0, stride_opposite) * knee_angle))
	_pose("LeftFoot", Quaternion(Vector3.RIGHT, stride * 0.10))
	_pose("RightFoot", Quaternion(Vector3.RIGHT, stride_opposite * 0.10))

	# Lower each arm around Z first, then swing it around X, opposite its leg.
	_pose("LeftArm", Quaternion(Vector3.RIGHT, stride * arm_angle) * Quaternion(Vector3.BACK, -1.12 + breath))
	_pose("RightArm", Quaternion(Vector3.RIGHT, stride_opposite * arm_angle) * Quaternion(Vector3.BACK, 1.12 - breath))
	_pose("LeftForeArm", Quaternion(Vector3.RIGHT, -0.13 - _run_blend * 0.35))
	_pose("RightForeArm", Quaternion(Vector3.RIGHT, -0.13 - _run_blend * 0.35))
	_pose("Head", Quaternion(Vector3.UP, sin(_clock * 0.7) * 0.018 * (1.0 - _blend)))


func _pose(suffix: String, skeleton_rotation: Quaternion) -> void:
	if not _bones.has(suffix):
		return
	var cached: Dictionary = _bones[suffix]
	var rest_rotation: Quaternion = cached["rotation"]
	var parent_rotation: Quaternion = Quaternion.IDENTITY
	if cached["parent"] >= 0:
		parent_rotation = _skeleton.get_bone_global_pose(cached["parent"]).basis.orthonormalized().get_rotation_quaternion()
	var inherited_rest: Quaternion = parent_rotation * rest_rotation
	# Conjugation converts the desired skeleton-space rotation to this bone's
	# local axes after its parent moved. Composing from rest prevents drift.
	var local_delta: Quaternion = inherited_rest.inverse() * skeleton_rotation * inherited_rest
	_skeleton.set_bone_pose_rotation(cached["index"], (rest_rotation * local_delta).normalized())


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var found: Skeleton3D = _find_skeleton(child)
		if found != null:
			return found
	return null
