extends Node3D

class_name MetalDetector

# Настройки обнаружения
@export var detection_range := 5.0
@export var scan_speed := 2.0
@export var max_targets := 5
@export var sensitivity := 1.0

# Типы ресурсов и их настройки
enum ResourceType { GOLD, PLATINUM, NICKEL }
const RESOURCE_COLORS = {
    ResourceType.GOLD: Color.GOLD,
    ResourceType.PLATINUM: Color.WHITE_SMOKE,
    ResourceType.NICKEL: Color.SILVER
}
const RESOURCE_VALUES = {
    ResourceType.GOLD: 100,
    ResourceType.PLATINUM: 150,
    ResourceType.NICKEL: 50
}

# Аудио
@onready var audio_player := $AudioStreamPlayer
var beep_sound := preload("res://sounds/beep.wav")

# Визуальные эффекты
@onready var detector_light := $DetectorLight
@onready var display_mesh := $Display

# Системные переменные
var is_active := false
var current_targets := []
var scan_progress := 0.0
var battery := 100.0
var is_scanning := false

func _ready():
    set_process(false)
    detector_light.visible = false

func _process(delta):
    if !is_active: return
    
    # Расход батареи
    battery = max(battery - delta * 2.0, 0.0)
    if battery <= 0:
        deactivate()
        return
    
    # Постепенное сканирование
    if is_scanning:
        scan_progress += delta * scan_speed
        if scan_progress >= 1.0:
            complete_scan()
            scan_progress = 0.0
    
    update_detection()
    update_visuals()

func activate():
    if battery <= 0: return
    is_active = true
    detector_light.visible = true
    set_process(true)
    start_scan()

func deactivate():
    is_active = false
    detector_light.visible = false
    is_scanning = false
    set_process(false)
    clear_targets()

func start_scan():
    if is_scanning: return
    is_scanning = true
    scan_progress = 0.0

func complete_scan():
    if current_targets.size() > 0:
        var best_target = get_best_target()
        mark_for_excavation(best_target)
    is_scanning = false

func update_detection():
    var space_state = get_world_3d().direct_space_state
    var query = PhysicsShapeQueryParameters.new()
    query.shape = SphereShape3D.new()
    query.shape.radius = detection_range * sensitivity
    query.transform = global_transform
    query.collision_mask = 0b0001
    
    var results = space_state.intersect_shape(query, max_targets)
    current_targets.clear()
    
    for result in results:
        if result.collider.has_meta("mineral_type"):
            var target_data = {
                "object": result.collider,
                "position": result.collider.global_position,
                "type": result.collider.get_meta("mineral_type"),
                "distance": global_position.distance_to(result.collider.global_position),
                "value": RESOURCE_VALUES[result.collider.get_meta("mineral_type")]
            }
            current_targets.append(target_data)
    
    # Сортировка по расстоянию
    current_targets.sort_custom(func(a, b): return a.distance < b.distance)

func get_best_target():
    if current_targets.size() == 0: return null
    return current_targets[0]

func mark_for_excavation(target):
    if !target: return
    target.object.get_node("Highlight").visible = true
    play_detection_sound(target.distance)
    create_waypoint_marker(target.position)

func play_detection_sound(distance):
    var volume_db = lerp(-10.0, -30.0, distance / detection_range)
    var pitch_scale = lerp(1.5, 0.8, distance / detection_range)
    
    audio_player.volume_db = volume_db
    audio_player.pitch_scale = pitch_scale
    audio_player.stream = beep_sound
    audio_player.play()

func create_waypoint_marker(position):
    var marker = preload("res://objects/waypoint_marker.tscn").instantiate()
    get_tree().current_scene.add_child(marker)
    marker.global_position = position
    marker.start_countdown(30.0) # Маркер исчезнет через 30 сек

func update_visuals():
    if current_targets.size() > 0:
        var closest = current_targets[0]
        var intensity = lerp(1.0, 0.3, closest.distance / detection_range)
        detector_light.light_color = RESOURCE_COLORS[closest.type]
        detector_light.light_energy = intensity
        
        # Обновление дисплея
        update_display(closest.type, closest.distance)
    else:
        detector_light.light_energy = 0.1
        detector_light.light_color = Color.DIM_GRAY

func update_display(resource_type, distance):
    var display_texture: Texture2D
    match resource_type:
        ResourceType.GOLD:
            display_texture = preload("res://textures/gold_display.png")
        ResourceType.PLATINUM:
            display_texture = preload("res://textures/platinum_display.png")
        ResourceType.NICKEL:
            display_texture = preload("res://textures/nickel_display.png")
    
    display_mesh.material_override.albedo_texture = display_texture
    display_mesh.material_override.emission_texture = display_texture
    display_mesh.material_override.emission_energy = lerp(1.5, 0.5, distance / detection_range)

func clear_targets():
    for target in current_targets:
        if is_instance_valid(target.object) and target.object.has_node("Highlight"):
            target.object.get_node("Highlight").visible = false
    current_targets.clear()

func recharge(amount: float):
    battery = min(battery + amount, 100.0)
