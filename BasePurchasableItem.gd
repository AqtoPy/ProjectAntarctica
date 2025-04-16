extends RigidBody3D
class_name PurchasableItem

# Основные параметры
@export var item_name := "Предмет"
@export var item_price := 100
@export var item_weight := 1.0
@export var can_be_picked_up := true
@export var use_sound : AudioStream
@export var item_texture : Texture2D

# Состояние
var is_in_inventory := false
var is_being_used := false

@onready var audio_player := $AudioStreamPlayer3D

func _ready():
    # Настройка физики в зависимости от веса
    mass = item_weight
    physics_material_override = PhysicsMaterial.new()
    physics_material_override.friction = 1.0
    physics_material_override.bounce = 0.3

func get_item_data() -> Dictionary:
    return {
        "name": item_name,
        "price": item_price,
        "texture": item_texture,
        "scene": self.scene_file_path
    }

func interact(player):
    if can_be_picked_up:
        if player.add_to_inventory(self):
            pick_up(player)
    else:
        use_item(player)

func pick_up(player):
    # Логика поднятия предмета
    freeze = true
    collision_layer = 0
    collision_mask = 0
    is_in_inventory = true
    visible = false
    player.pick_up_sound.play()

func drop():
    # Логика выброса предмета
    freeze = false
    collision_layer = 1
    collision_mask = 1
    is_in_inventory = false
    visible = true
    global_transform = get_tree().get_first_node_in_group("player").global_transform
    apply_impulse(Vector3(randf_range(-1, 1), Vector3.UP * 2.0)

func use_item(player):
    if is_being_used: return
    is_being_used = true
    
    # Проигрываем звук использования
    if use_sound:
        audio_player.stream = use_sound
        audio_player.play()
    
    # Логика использования (переопределяется в дочерних классах)
    _apply_effect(player)
    
    await get_tree().create_timer(1.0).timeout
    is_being_used = false

func _apply_effect(_player):
    # Переопределяется в конкретных предметах
    pass
