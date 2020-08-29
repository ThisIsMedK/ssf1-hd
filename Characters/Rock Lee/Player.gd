extends KinematicBody2D

signal grounded_updated(is_grounded)
signal player_jumped(is_double)

export var walk_right = "walk_right"
export var walk_left = "walk_left"
export var up := "up"
export var crouch := "crouch"
export var jump := "jump"
export var attack := "attack"

var celMult = 638
var flatMult = 27

export (float) var speed = 22*flatMult
export (float) var jump_speed = -17*flatMult
export (float) var gravity = 1*celMult
export (float) var frict = 0.9
export (float) var accelFlat = 0.9*celMult
export (float) var turnaround = 24.5*flatMult
export (float) var slow = 0.25
export (float) var attackboost = 0.5*flatMult
export (int) var jumptimes = 2
export (float) var revspeed = 30*flatMult
var slippery = 0

var accel = accelFlat
var jumps_left = jumptimes
var friction = frict*celMult

var velocity = Vector2.ZERO
var is_grounded
var jump_timer = Timer.new()
var shorthop = false
var attacking = false
var moonwalking = false
var state_machine
var current
var check

onready var sprite = $AnimatedSprite
onready var anim_player = $AnimatedSprite/AnimationPlayer
onready var dir = 1

func _ready() -> void:
	add_child(jump_timer)
	jump_timer.set_wait_time(0.1)
	jump_timer.set_one_shot(true)
	jump_timer.connect("timeout", self, "jump_timer_end")
	
	state_machine = $AnimationTree.get("parameters/playback")

func _physics_process(delta):
	var inputX = Input.get_action_strength(walk_right) - Input.get_action_strength(walk_left)

	var was_grounded = is_grounded
	is_grounded = is_on_floor()

	var was_attacking = check
	check = attacking
	
	var previous = current
	current = state_machine.get_current_node()
		
	if (was_grounded == null || is_grounded != was_grounded):
		emit_signal("grounded_updated", is_grounded)
		
	var is_double
	if(jumps_left > 0):
		is_double = 0
	else:
		is_double = 1
		
	velocity = move_and_slide(velocity, Vector2.UP)
	velocity.y += gravity * delta
	
	if velocity.x > 0:
		dir = 1
	elif velocity.x < 0:
		dir = -1
	
# attack code starts here (I think)
	if Input.is_action_pressed(crouch) && Input.is_action_pressed(attack) && attacking && is_on_floor():
		if revspeed != 0:
			state_machine.travel("special")
		else:
			velocity.x = 0
			
	if !attacking && Input.is_action_pressed(attack):
		attacking = true
		if attacking:
			if Input.is_action_pressed(crouch) && Input.is_action_pressed(attack):
				if is_on_floor():
					state_machine.travel("special")
				else:
					state_machine.travel("air2")
			elif Input.is_action_pressed(up) && Input.is_action_pressed(attack):
				state_machine.travel("air1")
			elif (Input.is_action_pressed(walk_left) || Input.is_action_pressed(walk_right)) && Input.is_action_pressed(attack):
				state_machine.travel("smash")
			else:
				state_machine.travel("normal")
			if !Input.is_action_pressed(crouch):
				velocity.x *= slow
			if !(revspeed != 0 && current == "special") && Input.is_action_just_pressed(attack):
				velocity.x += attackboost * sprite.scale.x
	if attacking:
		if (revspeed == 0 || revspeed != 0 && current != "special") && was_attacking != check:
			accel = accelFlat*((1+slow*2)/3)
	else:
		accel = accelFlat
	if !(revspeed != 0 && current == "special"):
		if Input.is_action_just_pressed(walk_right) || inputX > 0 && revspeed != 0 && previous == "special":
			if sprite.scale.x == -1:
				attacking = false
				sprite.scale.x = 1
				position.x -= (speed-turnaround-84)/14
		if Input.is_action_just_pressed(walk_left) || inputX < 0 && revspeed != 0 && previous == "special":
			if sprite.scale.x == 1:
				attacking = false
				sprite.scale.x = -1
				position.x += (speed-turnaround-84)/14
	if is_on_floor():
		if previous != current && previous == "jump" && moonwalking:
			moonwalking = false
			if !(dir == 1 && velocity.x - friction * delta < 0 || dir == -1 && velocity.x + friction * delta > 0 || velocity.x == 0):
				sprite.scale.x = dir
# attack code ends here (I think). See the over function below, too.
	if is_on_floor() && Input.is_action_pressed(crouch) && !(revspeed != 0 && current == "special"):
		# screw the lerp function
		if !attacking:
			state_machine.travel("crouch")
			if dir == 1 && velocity.x - friction * 1.75 * delta < 0 || dir == -1 && velocity.x + friction * 1.75 * delta > 0 || velocity.x == 0:
				velocity.x = 0
			else:
				velocity.x -= friction * delta * 1.75 * dir
		else:
			if dir == 1 && velocity.x - friction * delta < 0 || dir == -1 && velocity.x + friction * delta > 0 || velocity.x == 0:
				velocity.x = 0
			else:
				velocity.x -= friction * delta * dir
	elif inputX > 0 && !(revspeed != 0 && current == "special"):
		if dir == -1 && velocity.x < 0:
			velocity.x += turnaround * delta
		if is_on_floor() && !attacking:
			state_machine.travel("run")
		if sprite.scale.x == 1:
			moonwalking = false
			if velocity.x < speed:
				velocity.x += accel * delta
			else:
				velocity.x = speed
		elif dir == 1 && velocity.x - friction * delta < 0 || dir == -1 && velocity.x + friction * delta > 0:
			velocity.x = 0
		if sprite.scale.x == -1:
			moonwalking = true
	elif inputX < 0 && !(revspeed != 0 && current == "special"):
		if dir == 1 && velocity.x > 0:
			velocity.x -= turnaround * delta
		if is_on_floor() && !attacking:
			state_machine.travel("run")
		if sprite.scale.x == -1:
			moonwalking = false
			if velocity.x > -speed:
				velocity.x -= accel * delta
			else:
				velocity.x = -speed
		elif dir == 1 && velocity.x - friction * delta < 0 || dir == -1 && velocity.x + friction * delta > 0:
			velocity.x = 0
		if sprite.scale.x == 1:
			moonwalking = true
	else:
		# screw the lerp function
		if dir == 1 && velocity.x - friction * delta < 0 || dir == -1 && velocity.x + friction * delta > 0 || velocity.x == 0:
			velocity.x = 0
			if is_on_floor() && !attacking:
				state_machine.travel("idle")
		else:
			velocity.x -= friction * delta * dir
			if is_on_floor() && current != "run" && !attacking:
				state_machine.travel("idle")
	if Input.is_action_pressed(jump):
		if Input.is_action_just_pressed(jump):
			if !Input.is_action_just_pressed(attack):
				attacking = false
			if is_on_floor():
				jump_timer.start()
			elif jumps_left > 0:
					velocity.y = jump_speed
					jumps_left -= 1
			if !is_on_floor():
				emit_signal("player_jumped", is_double)
	if Input.is_action_just_released(jump) && is_on_floor():
		shorthop = true
	elif is_on_floor() && !Input.is_action_pressed(jump):
		jumps_left = jumptimes
	if !attacking:
		if !is_on_floor():
			if velocity.y < 0 || velocity.y > 0 && current != "run":
				state_machine.travel("jump")
		elif !jump_timer.is_stopped():
			state_machine.travel("jumpsquat")
			if Input.is_action_pressed(crouch) && inputX != 0 && jump_timer.get_time_left() >= 0.05 && velocity.x > -speed && velocity.x < speed:
				if current != "crouch":
					if inputX > 0:
						velocity.x = ((revspeed+10*flatMult+speed)/2) * frict + slippery
					else:
						velocity.x = ((revspeed+10*flatMult+speed)/2) * -frict - slippery
				anim_player.stop()
				state_machine.travel("idle")
				jump_timer.stop()
				jump_timer.set_wait_time(0.1)

func jump_timer_end():
	if shorthop:
		velocity.y = jump_speed + (gravity/celMult*5)*28
	else:
		velocity.y = jump_speed
	jumps_left -= 1
	shorthop = false

func rev_check():
	if !attacking:
		anim_player.stop()
		state_machine.travel("idle")
	elif revspeed != 0:
		velocity.x = revspeed * sprite.scale.x

#over function
func over():
	attacking = false
	anim_player.stop()
	state_machine.travel("idle")
