extends PurchasableItem
class_name WaterBottle

@export var thirst_restore := 30.0
@export var drink_sound : AudioStream

func _ready():
    item_name = "Бутылка воды"
    item_price = 50
    use_sound = drink_sound

func _apply_effect(player):
    # Восстанавливаем жажду
    if player.has_method("restore_thirst"):
        player.restore_thirst(thirst_restore)
    
    # Удаляем предмет после использования
    queue_free()
    
    # Эффекты
    var particles = preload("res://effects/drink_particles.tscn").instantiate()
    player.add_child(particles)
    particles.emitting = true
    await particles.finished
    particles.queue_free()
