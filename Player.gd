extends CharacterBody3D

# Настройки движения
@export var walking_speed := 4.0
@export var sprinting_speed := 7.0
@export var crouching_speed := 2.0
@export var jump_velocity := 5.0
@export var crouch_depth := 0.5
@export var acceleration := 10.0
@export var air_control := 0.3
@export var mouse_sensitivity := 0.002
@export var controller_sensitivity := 0.01

# Настройки головы и камеры
@export var headbob_frequency := 2.0
@export var headbob_amplitude := 0.05
@export var headbob_sprint_multiplier := 1.5
@export var fov_default := 75.0
@export var fov_sprint := 85.0
@export var fov_change_speed := 8.0

# Система потребностей
@export var max_health := 100.0
@export var max_hunger := 100.0
@export var max_cold := 100.0
@export var hunger_rate := 0.2
@export var cold_rate := 0.5
@export var health_regen_rate := 0.1

# Настройки инвентаря
@export var max_inventory_slots := 10
@export var pickup_range := 2.5
@export var pickup_ray_length := 3.0

# Ноды
@onready var neck := $Neck
@onready var camera := $Neck/Camera3D
@onready var interaction_ray := $Neck/Camera3D/InteractionRay
@onready var hand := $Neck/Camera3D/Hand
@onready var headbob_position := camera.position

# Переменные состояния
var current_speed := walking_speed
var health := max_health
var hunger := max_hunger
var cold := max_cold
var is_sprinting := false
var is_crouching := false
var is_grounded := false
var is_headbob_enabled := true
var headbob_progress := 0.0
var current_fov := fov_default

# Инвентарь
var inventory := []
var selected_slot := 0

# Физические параметры
var gravity := ProjectSettings.get_setting("physics/3d/default_gravity")
var direction := Vector3.ZERO
var last_velocity := Vector3.ZERO
var movement_delta := Vector3.ZERO

func _ready():
    Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
    interaction_ray.target_distance = pickup_ray_length

func _input(event):
    # Управление мышью
    if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
        rotate_y(-event.relative.x * mouse_sensitivity)
        neck.rotate_x(-event.relative.y * mouse_sensitivity)
        neck.rotation.x = clamp(neck.rotation.x, deg_to_rad(-90), deg_to_rad(90))
    
    # Управление геймпадом
    if event is InputEventJoypadMotion:
        if event.axis == 2: # Right stick horizontal
            rotate_y(-event.axis_value * controller_sensitivity)
        if event.axis == 3: # Right stick vertical
            neck.rotate_x(-event.axis_value * controller_sensitivity)
            neck.rotation.x = clamp(neck.rotation.x, deg_to_rad(-90), deg_to_rad(90))
    
    # Взаимодействие с предметами
    if Input.is_action_just_pressed("interact"):
        try_interact()
    
    # Переключение слотов инвентаря
    if Input.is_action_just_pressed("inventory_next"):
        selected_slot = (selected_slot + 1) % max_inventory_slots
        update_hand_item()
    if Input.is_action_just_pressed("inventory_prev"):
        selected_slot = (selected_slot - 1) % max_inventory_slots
        update_hand_item()
    
    # Выброс предмета
    if Input.is_action_just_pressed("drop_item") and selected_slot < inventory.size():
        drop_item(selected_slot)

func _physics_process(delta):
    # Получение ввода
    handle_movement_input()
    handle_state_input()
    
    # Применение гравитации
    handle_gravity(delta)
    
    # Обработка движения
    handle_movement(delta)
    
    # Обновление камеры и эффектов
    update_camera(delta)
    update_headbob(delta)
    
    # Обновление потребностей
    update_needs(delta)
    
    # Применение движения
    move_and_slide()
    is_grounded = is_on_floor()
    last_velocity = velocity

func handle_movement_input():
    var input_dir = Input.get_vector("left", "right", "forward", "backward")
    direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

func handle_state_input():
    # Бег
    is_sprinting = Input.is_action_pressed("sprint") and is_grounded and not is_crouching
    current_speed = sprinting_speed if is_sprinting else walking_speed
    current_speed = crouching_speed if is_crouching else current_speed
    
    # Приседание
    if Input.is_action_just_pressed("crouch"):
        is_crouching = !is_crouching
        if is_crouching:
            $CollisionShape3D.shape.height -= crouch_depth
            camera.position.y -= crouch_depth / 2
        else:
            $CollisionShape3D.shape.height += crouch_depth
            camera.position.y += crouch_depth / 2

func handle_gravity(delta):
    if not is_on_floor():
        velocity.y -= gravity * delta

func handle_movement(delta):
    var target_velocity = direction * current_speed
    
    if is_grounded:
        velocity.x = lerp(velocity.x, target_velocity.x, acceleration * delta)
        velocity.z = lerp(velocity.z, target_velocity.z, acceleration * delta)
        
        # Прыжок
        if Input.is_action_just_pressed("jump") and not is_crouching:
            velocity.y = jump_velocity
    else:
        # Воздушный контроль
        velocity.x = lerp(velocity.x, target_velocity.x, air_control * delta)
        velocity.z = lerp(velocity.z, target_velocity.z, air_control * delta)

func update_camera(delta):
    # Изменение FOV при беге
    var target_fov = fov_sprint if is_sprinting and direction != Vector3.ZERO else fov_default
    current_fov = lerp(current_fov, target_fov, fov_change_speed * delta)
    camera.fov = current_fov

func update_headbob(delta):
    if not is_headbob_enabled or !is_grounded or direction == Vector3.ZERO:
        camera.position = headbob_position
        return
    
    var speed_multiplier = headbob_sprint_multiplier if is_sprinting else 1.0
    headbob_progress += delta * headbob_frequency * speed_multiplier
    
    var headbob_offset = Vector3(
        sin(headbob_progress * 2.0) * headbob_amplitude,
        sin(headbob_progress) * headbob_amplitude * 2.0,
        0
    )
    
    camera.position = headbob_position + headbob_offset

func update_needs(delta):
    # Голод и холод
    hunger = max(hunger - hunger_rate * delta, 0.0)
    cold = max(cold - cold_rate * delta, 0.0)
    
    # Урон от холода и голода
    if cold <= 0.0 or hunger <= 0.0:
        health = max(health - delta * 1.0, 0.0)
    elif health < max_health and cold > 50.0 and hunger > 50.0:
        health = min(health + health_regen_rate * delta, max_health)
    
    # Эффекты при низких показателях
    if cold < 30.0:
        # Дрожание камеры
        pass
    if hunger < 30.0:
        # Замедление скорости
        pass

func try_interact():
    if interaction_ray.is_colliding():
        var collider = interaction_ray.get_collider()
        
        if collider.is_in_group("pickable"):
            pickup_item(collider)
        elif collider.has_method("interact"):
            collider.interact(self)

func pickup_item(item):
    if inventory.size() < max_inventory_slots:
        inventory.append(item)
        item.get_parent().remove_child(item)
        hand.add_child(item)
        item.position = Vector3.ZERO
        item.rotation = Vector3.ZERO
        item.set_owner(hand)
        item.collision_layer = 0
        item.collision_mask = 0
        update_hand_item()

func drop_item(slot):
    if slot >= inventory.size():
        return
    
    var item = inventory[slot]
    inventory.remove_at(slot)
    hand.remove_child(item)
    
    get_parent().add_child(item)
    item.global_transform = hand.global_transform
    item.collision_layer = 1
    item.collision_mask = 1
    
    # Применяем силу при выбросе
    if item is RigidBody3D:
        item.linear_velocity = velocity + camera.global_transform.basis.z * -5.0
    
    update_hand_item()

func update_hand_item():
    # Скрываем все предметы в руке
    for child in hand.get_children():
        child.visible = false
    
    # Показываем только выбранный
    if selected_slot < inventory.size():
        inventory[selected_slot].visible = true

func eat(food_value):
    hunger = min(hunger + food_value, max_hunger)

func warm_up(heat_value):
    cold = min(cold + heat_value, max_cold)

func take_damage(amount):
    health = max(health - amount, 0.0)
    if health <= 0:
        die()

func die():
    # Реализация смерти игрока
    pass
