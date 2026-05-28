extends RefCounted

const LUNGE_DISTANCE: float = 46.0
const LUNGE_DURATION: float = 0.12
const RETURN_DURATION: float = 0.14
const HIT_REACT_DISTANCE: float = 16.0
const HIT_REACT_DURATION: float = 0.10
const IMPACT_HOLD_DURATION: float = 0.04


func play_basic_attack(attacker_view: Node, target_view: Node, impact_callback: Callable = Callable()) -> void:
	if attacker_view == null or target_view == null:
		return
	if not _has_method(attacker_view, "play_attack_lunge") or not _has_method(target_view, "play_hit_react"):
		return

	var direction = target_view.global_position - attacker_view.global_position
	if direction.length_squared() == 0.0:
		direction = Vector2.RIGHT
	var target_push = direction.normalized() * 0.6

	await attacker_view.play_attack_lunge(direction, LUNGE_DISTANCE, LUNGE_DURATION)
	if impact_callback.is_valid():
		impact_callback.call()
	await target_view.play_hit_react(target_push, HIT_REACT_DISTANCE, HIT_REACT_DURATION)
	await _delay(attacker_view.get_tree(), IMPACT_HOLD_DURATION)
	await attacker_view.play_return(RETURN_DURATION)


func _delay(tree: SceneTree, seconds: float) -> void:
	if tree == null:
		return
	await tree.create_timer(max(0.0, seconds)).timeout


func _has_method(target: Object, method_name: String) -> bool:
	return target != null and target.has_method(method_name)
