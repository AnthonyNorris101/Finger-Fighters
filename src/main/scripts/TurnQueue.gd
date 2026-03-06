extends Node

class_name TurnQueue

var active_character

func init() -> void:
	var battlers = get_battlers()
	battlers.sort_custom(self, 'sort_battlers')
	for battler in battlers:
		battler.raise()
	active_character = get_child(0)
	
func play_turn():
	await active_character.play_turn()
	var new_index : int = (active_character.get_index()+1)%get_child_count()
	active_character = get_child(new_index)

func get_battlers():
	return self.childre
