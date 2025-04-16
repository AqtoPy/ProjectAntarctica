extends Node3D

class_name CameraTripod

# Настройки камеры
@export var zoom_levels := [75.0, 50.0, 30.0] # Уровни приближения (FOV)
@export var zoom_speed := 5.0
@export var rotation_speed := 2.0
@export var max_tilt := 30.0 # Макс. наклон в градусах
@export var min_tilt := -60.0 # Мин. наклон в градусах

# Ноды
@onready var camera := $Camera3D
@onready var tripod_legs := $Legs
@onready var shutter_sound := $ShutterSound
@onready var photo_flash := $PhotoFlash

# Состояние
var current_zoom := 0
var is_active := false
var is_placing := false
var can_take_photo := true
var photos_taken := 0
var photo_quality := 1.0 # 0.0-1.0

func _ready():
    camera.current = false
    camera.fov = zoom_levels[current_zoom]
    photo_flash.hide()

func _input(event):
    if !is_active: return
    
    # Управление камерой
    if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
        rotate_y(-event.relative.x * rotation_speed * 0.01)
        camera.rotate_x(-event.relative.y * rotation_speed * 0.01)
        camera.rotation_degrees.x = clamp(camera.rotation_degrees.x, min_tilt, max_tilt)
    
    if event.is_action_pressed("zoom_in"):
        zoom_in()
    if event.is_action_pressed("zoom_out"):
        zoom_out()
    if event.is_action_pressed("take_photo"):
        take_photo()
    if event.is_action_pressed("exit_camera"):
        exit_camera_mode()

func _process(delta):
    if is_placing:
        update_placement()
    elif is_active:
        update_photo_quality(delta)

func activate():
    is_active = true
    camera.current = true
    Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
    update_photo_quality(0.0)

func exit_camera_mode():
    is_active = false
    camera.current = false
    Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func start_placement():
    is_placing = true
    tripod_legs.visible = true
    show()

func update_placement():
    var ray_length = 10.0
    var mouse_pos = get_viewport().get_mouse_position()
    var ray_origin = camera.project_ray_origin(mouse_pos)
    var ray_dir = camera.project_ray_normal(mouse_pos)
    var ray_end = ray_origin + ray_dir * ray_length
    
    var space_state = get_world_3d().direct_space_state
    var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
    var result = space_state.intersect_ray(query)
    
    if result:
        global_transform.origin = result.position
        global_transform.origin.y += 0.2 # Небольшой отступ от поверхности
        
        # Выравнивание по нормали поверхности
        var normal = result.normal
        var up = Vector3.UP
        var dot = normal.dot(up)
        
        if abs(dot) > 0.001: # Не перпендикулярно
            var axis = up.cross(normal).normalized()
            var angle = acos(dot)
            global_transform.basis = Basis(axis, angle)
    
    if Input.is_action_just_pressed("place_object"):
        complete_placement()

func complete_placement():
    is_placing = false
    activate()

func zoom_in():
    current_zoom = clamp(current_zoom + 1, 0, zoom_levels.size() - 1)
    update_zoom()

func zoom_out():
    current_zoom = clamp(current_zoom - 1, 0, zoom_levels.size() - 1)
    update_zoom()

func update_zoom():
    var target_fov = zoom_levels[current_zoom]
    create_tween().tween_property(camera, "fov", target_fov, 0.2)

func take_photo():
    if !can_take_photo: return
    
    can_take_photo = false
    photos_taken += 1
    
    # Эффекты
    shutter_sound.play()
    photo_flash.show()
    
    # Создание фото
    var image = get_viewport().get_texture().get_image()
    var photo_name = "photo_%s_%d.jpg" % [Time.get_datetime_string_from_system(), photos_taken]
    var save_path = "user://photos/%s" % photo_name
    
    # Создаем папку если ее нет
    var dir = DirAccess.open("user://")
    if !dir.dir_exists("photos"):
        dir.make_dir("photos")
    
    # Сохраняем с учетом качества
    image.save_jpg(save_path, photo_quality * 100)
    
    # Анализ фото (можно добавить обнаружение объектов)
    analyze_photo(image)
    
    # Сброс после фото
    await get_tree().create_timer(0.5).timeout
    photo_flash.hide()
    await get_tree().create_timer(1.0).timeout
    can_take_photo = true

func analyze_photo(image):
    # Здесь можно добавить анализ изображения
    # Например, поиск редких животных или аномалий
    pass

func update_photo_quality(delta):
    # Качество зависит от стабильности (дрожание рук, движение и т.д.)
    var stability = 1.0
    
    # Проверяем движение камеры
    var camera_movement = camera.global_transform.origin.distance_to(camera.global_transform.origin)
    stability -= clamp(camera_movement * 10.0, 0.0, 0.5)
    
    # Проверяем скорость вращения
    var rotation_speed = camera.rotation.length()
    stability -= clamp(rotation_speed * 2.0, 0.0, 0.3)
    
    # Плавное изменение качества
    photo_quality = lerp(photo_quality, stability, delta * 5.0)
    
    # Визуальная индикация качества
    update_quality_indicator()

func update_quality_indicator():
    # Можно добавить UI элемент показывающий качество
    pass
