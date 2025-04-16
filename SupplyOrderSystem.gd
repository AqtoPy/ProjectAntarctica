extends Node

class_name SupplyOrderSystem

# Настройки доставки
@export var delivery_min_time := 300.0 # 5 минут
@export var delivery_max_time := 600.0 # 10 минут
@export var heli_scene : PackedScene
@export var base_landing_zone : Marker3D
@export var delivery_items : Array[PackedScene]

# Системные переменные
var current_orders := []
var pending_deliveries := []
var heli_instance : Node3D
var is_heli_available := true
var delivery_time_multiplier := 1.0

func _ready():
    # Загрузка сохраненных заказов
    load_orders()

func order_item(item_index : int, quantity : int = 1):
    if item_index < 0 or item_index >= delivery_items.size():
        push_error("Invalid item index")
        return
    
    var order = {
        "item_index": item_index,
        "quantity": quantity,
        "order_time": Time.get_unix_time_from_system(),
        "delivery_time": calculate_delivery_time(),
        "status": "ordered"
    }
    
    current_orders.append(order)
    pending_deliveries.append(order)
    
    # Запуск доставки если вертолет свободен
    if is_heli_available:
        start_delivery()
    
    save_orders()

func calculate_delivery_time():
    var base_time = randf_range(delivery_min_time, delivery_max_time)
    return base_time * delivery_time_multiplier

func start_delivery():
    if pending_deliveries.is_empty() or !is_heli_available: return
    
    is_heli_available = false
    var next_delivery = pending_deliveries.pop_front()
    
    # Создаем вертолет
    heli_instance = heli_scene.instantiate()
    get_tree().current_scene.add_child(heli_instance)
    heli_instance.global_transform = get_heli_spawn_point()
    
    # Настройка маршрута
    heli_instance.setup_delivery(
        base_landing_zone.global_position,
        next_delivery,
        funcref(self, "on_delivery_complete")
    )

func on_delivery_complete(delivery_data, success):
    if success:
        complete_order(delivery_data)
    
    # Улетаем
    heli_instance.start_return()
    await heli_instance.finished_return
    
    heli_instance.queue_free()
    heli_instance = null
    is_heli_available = true
    
    # Проверяем следующие доставки
    if !pending_deliveries.is_empty():
        await get_tree().create_timer(60.0).timeout # Пауза между доставками
        start_delivery()

func complete_order(order):
    # Создаем предметы на зоне выгрузки
    var item_scene = delivery_items[order.item_index]
    for i in range(order.quantity):
        var item = item_scene.instantiate()
        get_tree().current_scene.add_child(item)
        
        # Позиционируем в зоне выгрузки с небольшим разбросом
        var pos = base_landing_zone.global_position
        pos.x += randf_range(-2.0, 2.0)
        pos.z += randf_range(-2.0, 2.0)
        item.global_position = pos
        
        # Небольшой подброс
        if item is RigidBody3D:
            item.linear_velocity = Vector3.UP * 2.0
    
    # Обновляем статус заказа
    for o in current_orders:
        if o.order_time == order.order_time:
            o.status = "delivered"
    
    save_orders()

func get_heli_spawn_point() -> Transform3D:
    # Генерируем точку появления где-то в небе над базой
    var spawn_pos = base_landing_zone.global_position
    spawn_pos.y += 100.0
    spawn_pos.x += randf_range(-50.0, 50.0)
    spawn_pos.z += randf_range(-50.0, 50.0)
    
    var transform = Transform3D()
    transform.origin = spawn_pos
    transform = transform.looking_at(base_landing_zone.global_position, Vector3.UP)
    
    return transform

func save_orders():
    var save_data = {
        "orders": current_orders,
        "pending": pending_deliveries
    }
    
    var file = FileAccess.open("user://orders.save", FileAccess.WRITE)
    file.store_var(save_data)

func load_orders():
    if !FileAccess.file_exists("user://orders.save"): return
    
    var file = FileAccess.open("user://orders.save", FileAccess.READ)
    var save_data = file.get_var()
    
    current_orders = save_data.orders
    pending_deliveries = save_data.pending
    
    # Восстанавливаем активные доставки
    if !pending_deliveries.is_empty():
        start_delivery()

func get_order_status(order_time) -> String:
    for order in current_orders:
        if order.order_time == order_time:
            return order.status
    return "not_found"
