extends RigidBody3D

class_name DeliveryHelicopter

# Настройки полета
@export var fly_height := 80.0
@export var approach_speed := 20.0
@export var hover_height := 15.0
@export var rotation_speed := 1.0
@export var unloading_time := 30.0

# Ноды
@onready var rotor := $Rotor
@onready var engine_sound := $EngineSound
@onready var cargo_rope := $CargoRope

# Системные переменные
var delivery_data : Dictionary
var target_position : Vector3
var current_state := "approaching"
var callback : Callable
var has_cargo := true

signal finished_return

func _ready():
    engine_sound.play()
    set_physics_process(false)

func setup_delivery(landing_zone_pos: Vector3, order_data: Dictionary, complete_callback: Callable):
    target_position = landing_zone_pos
    delivery_data = order_data
    callback = complete_callback
    set_physics_process(true)

func _physics_process(delta):
    match current_state:
        "approaching":
            approach_base(delta)
        "descending":
            descend(delta)
        "unloading":
            unload_cargo(delta)
        "ascending":
            ascend(delta)
        "returning":
            return_to_spawn(delta)
    
    update_rotor(delta)
    update_sound()

func approach_base(delta):
    var direction = (target_position - global_position).normalized()
    direction.y = 0
    
    # Движение к базе
    linear_velocity = direction * approach_speed
    linear_velocity.y = 0
    
    # Поворот в сторону движения
    var target_rotation = atan2(direction.x, direction.z)
    rotation.y = lerp_angle(rotation.y, target_rotation, rotation_speed * delta)
    
    # Проверка прибытия
    var distance = global_position.distance_to(Vector3(target_position.x, global_position.y, target_position.z))
    if distance < 20.0:
        current_state = "descending"

func descend(delta):
    var direction = (target_position - global_position).normalized()
    direction.y = 0
    
    # Медленное снижение
    linear_velocity = direction * approach_speed * 0.5
    linear_velocity.y = -5.0
    
    # Достигли высоты зависания
    if global_position.y < target_position.y + hover_height:
        global_position.y = target_position.y + hover_height
        current_state = "unloading"
        start_unloading()

func start_unloading():
    # Анимация спуска груза
    cargo_rope.extend_to_ground(unloading_time)
    await cargo_rope.finished_extending
    
    # Груз доставлен
    has_cargo = false
    callback.call(delivery_data, true)
    
    # Подъем троса
    cargo_rope.retract(unloading_time * 0.5)
    await cargo_rope.finished_retracting
    
    current_state = "ascending"

func ascend(delta):
    linear_velocity = Vector3.UP * 5.0
    
    # Достигли высоты полета
    if global_position.y > target_position.y + fly_height:
        current_state = "returning"

func return_to_spawn(delta):
    var spawn_pos = get_parent().get_heli_spawn_point()
    var direction = (spawn_pos.origin - global_position).normalized()
    
    linear_velocity = direction * approach_speed
    
    # Проверка на завершение
    if global_position.distance_to(spawn_pos.origin) < 30.0:
        set_physics_process(false)
        finished_return.emit()

func update_rotor(delta):
    rotor.rotate_y(10.0 * delta)

func update_sound():
    var volume = -10.0 + clamp(linear_velocity.length() / approach_speed * 20.0, 0.0, 10.0)
    engine_sound.volume_db = volume
    engine_sound.pitch_scale = 0.8 + linear_velocity.length() / approach_speed * 0.5

func _on_impact(force):
    if force > 50.0 and has_cargo:
        callback.call(delivery_data, false)
        queue_free()
