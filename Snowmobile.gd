extends RigidBody3D

class_name Snowmobile

# Настройки движения
@export var engine_power := 150.0
@export var max_speed := 25.0
@export var reverse_power := 80.0
@export var max_reverse_speed := 10.0
@export var steering_speed := 1.5
@export var max_steering_angle := 0.8
@export var brake_power := 200.0
@export var drift_threshold := 8.0
@export var drift_control := 0.3
@export var stability_control := 0.8

# Ноды
@onready var front_ray := $FrontRay
@onready var rear_ray := $RearRay
@onready var engine_sound := $EngineSound
@onready var skid_sound := $SkidSound
@onready var particles_left := $ParticlesLeft
@onready var particles_right := $ParticlesRight

# Состояние
var is_player_inside := false
var current_steering := 0.0
var is_drifting := false
var current_rpm := 0.0
var acceleration_input := 0.0
var steering_input := 0.0
var brake_input := 0.0

# Физические параметры
var ground_normal := Vector3.UP
var on_ground := false
var forward_velocity := 0.0
var lateral_velocity := 0.0

func _ready():
    mass = 300.0
    center_of_mass.y = -0.5

func _physics_process(delta):
    check_ground()
    process_input(delta)
    apply_forces(delta)
    update_effects(delta)
    limit_speed()

func check_ground():
    on_ground = front_ray.is_colliding() or rear_ray.is_colliding()
    if front_ray.is_colliding():
        ground_normal = front_ray.get_collision_normal()
    elif rear_ray.is_colliding():
        ground_normal = rear_ray.get_collision_normal()
    else:
        ground_normal = Vector3.UP

func process_input(delta):
    if !is_player_inside: return
    
    # Получение ввода
    acceleration_input = Input.get_action_strength("accelerate") - Input.get_action_strength("brake")
    steering_input = Input.get_axis("right", "left")
    brake_input = Input.get_action_strength("brake")
    
    # Плавное руление
    current_steering = lerp(current_steering, 
                          steering_input * max_steering_angle, 
                          steering_speed * delta)
    
    # Расчет RPM для звука двигателя
    var target_rpm = abs(forward_velocity / max_speed)
    current_rpm = lerp(current_rpm, target_rpm, 5.0 * delta)

func apply_forces(delta):
    if !on_ground: return
    
    # Расчет базовых векторов
    var forward_dir = -global_transform.basis.z
    var right_dir = global_transform.basis.x
    
    # Расчет скорости вперед/назад
    forward_velocity = forward_dir.dot(linear_velocity)
    lateral_velocity = right_dir.dot(linear_velocity)
    
    # Применение двигателя
    if acceleration_input > 0:
        var power = engine_power * acceleration_input
        apply_force(forward_dir * power * delta, Vector3.ZERO)
    elif acceleration_input < 0:
        var power = reverse_power * -acceleration_input
        apply_force(-forward_dir * power * delta, Vector3.ZERO)
    
    # Торможение
    if brake_input > 0.1:
        var brake_force = -forward_dir * forward_velocity * brake_power * brake_input * delta
        apply_force(brake_force, Vector3.ZERO)
    
    # Проверка на занос
    is_drifting = abs(lateral_velocity) > drift_threshold and abs(forward_velocity) > 2.0
    
    # Руление с учетом заноса
    if is_drifting:
        # В заносе - контрруление
        var drift_steering = -sign(lateral_velocity) * drift_control
        apply_torque(Vector3.UP * drift_steering * delta * 100.0)
    else:
        # Обычное руление
        apply_torque(Vector3.UP * current_steering * delta * 100.0)
    
    # Стабилизация
    if !is_drifting and abs(angular_velocity.y) > 0.1:
        apply_torque(Vector3.UP * -angular_velocity.y * stability_control * delta * 100.0)

func limit_speed():
    var forward_dir = -global_transform.basis.z
    forward_velocity = forward_dir.dot(linear_velocity)
    
    if forward_velocity > max_speed:
        var excess = forward_velocity - max_speed
        apply_force(-forward_dir * excess * mass * 0.1, Vector3.ZERO)
    elif forward_velocity < -max_reverse_speed:
        var excess = -forward_velocity - max_reverse_speed
        apply_force(forward_dir * excess * mass * 0.1, Vector3.ZERO)

func update_effects(delta):
    # Звук двигателя
    engine_sound.pitch_scale = 0.8 + current_rpm * 0.7
    engine_sound.volume_db = -20.0 + current_rpm * 20.0
    
    # Звук заноса
    if is_drifting and abs(forward_velocity) > 5.0:
        if !skid_sound.playing:
            skid_sound.play()
        skid_sound.volume_db = -10.0 + clamp(abs(lateral_velocity) * 2.0, -10.0, 0.0)
        skid_sound.pitch_scale = 0.9 + abs(forward_velocity) / max_speed * 0.3
    else:
        skid_sound.stop()
    
    # Частицы снега
    update_snow_particles()

func update_snow_particles():
    var slip_amount = clamp(abs(lateral_velocity) / drift_threshold, 0.0, 1.0)
    var speed_amount = clamp(abs(forward_velocity) / max_speed, 0.0, 1.0)
    
    particles_left.emitting = on_ground and (is_drifting or speed_amount > 0.3)
    particles_right.emitting = on_ground and (is_drifting or speed_amount > 0.3)
    
    var emission_rate = 20.0 + 80.0 * (slip_amount + speed_amount) / 2.0
    particles_left.amount = int(emission_rate)
    particles_right.amount = int(emission_rate)

func enter_vehicle(player):
    is_player_inside = true
    player.visible = false
    player.process_mode = Node.PROCESS_MODE_DISABLED
    player.global_transform = $DriverPosition.global_transform

func exit_vehicle():
    var player = get_tree().get_nodes_in_group("player")[0]
    is_player_inside = false
    player.visible = true
    player.process_mode = Node.PROCESS_MODE_INHERIT
    player.global_transform = $ExitPosition.global_transform

func _input(event):
    if !is_player_inside: return
    
    if event.is_action_pressed("exit_vehicle"):
        exit_vehicle()
