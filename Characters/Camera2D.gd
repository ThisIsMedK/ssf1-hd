extends Camera2D
		
func _on_Player_grounded_updated(is_grounded):
	drag_margin_v_enabled = !is_grounded
		
func _on_Player_jumped(is_double):
	drag_margin_v_enabled = is_double
