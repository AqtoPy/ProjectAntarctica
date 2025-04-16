extends Node3D
class_name PlayerComputer

# Настройки компьютера
@export var computer_screen_mesh : MeshInstance3D
@export var camera_position : Marker3D
@export var interaction_distance := 2.0
@export var transition_speed := 3.0
@export var screen_resolution := Vector2(1024, 768)

# Настройки интерфейса
@export var desktop_background : Texture2D
@export var font_large : FontFile
@export var font_small : FontFile

# Ноды
@onready var screen_camera := $ScreenCamera
@onready var ray_cast := $RayCast3D
@onready var gui_viewport := $SubViewport
@onready var gui_control := $SubViewport/ComputerGUI
@onready var animation_player := $AnimationPlayer
@onready var boot_sound := $BootSound
@onready var click_sound := $ClickSound

# Состояние компьютера
var is_active := false
var is_player_near := false
var original_camera_transform : Transform3D
var original_camera_parent : Node3D
var player_ref : Node3D
var current_app := "desktop"

# Данные радара
var radar_targets := []
var last_scan_time := 0.0

func _ready():
    # Настройка Viewport
    gui_viewport.size = screen_resolution
    computer_screen_mesh.material_override.albedo_texture = gui_viewport.get_texture()
    
    # Инициализация GUI
    init_computer_gui()
    
    # Выключение ненужных компонентов
    screen_camera.current = false
    gui_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

func _process(delta):
    # Проверка расстояния до игрока
    if player_ref:
        var distance = global_position.distance_to(player_ref.global_position)
        is_player_near = distance <= interaction_distance
        
        # Обновление радара, если активно
        if is_active and current_app == "radar":
            update_radar(delta)
    
    # Обновление даты и времени
    if is_active and current_app == "desktop":
        update_clock()

func _input(event):
    if !is_active: return
    
    # Обработка ввода для компьютера
    if event is InputEventKey:
        gui_control.handle_key_input(event)
    
    if event.is_action_pressed("exit_computer"):
        exit_computer()

func init_computer_gui():
    # Создаем базовые элементы интерфейса
    gui_control.add_theme_font_override("font", font_small)
    gui_control.add_theme_font_size_override("font_size", 16)
    
    # Инициализация приложений
    gui_control.init_apps({
        "desktop": create_desktop_app(),
        "order_system": create_order_app(),
        "radar": create_radar_app(),
        "weather": create_weather_app()
    })

func create_desktop_app() -> Control:
    var desktop = Control.new()
    desktop.name = "Desktop"
    
    # Фоновое изображение
    var bg = TextureRect.new()
    bg.texture = desktop_background
    bg.stretch_mode = TextureRect.STRETCH_SCALE
    bg.anchor_right = 1.0
    bg.anchor_bottom = 1.0
    desktop.add_child(bg)
    
    # Часы и дата
    var clock = Label.new()
    clock.name = "Clock"
    clock.anchor_left = 0.8
    clock.anchor_top = 0.05
    clock.anchor_right = 0.95
    clock.anchor_bottom = 0.1
    clock.add_theme_font_override("font", font_large)
    clock.add_theme_font_size_override("font_size", 24)
    clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    desktop.add_child(clock)
    
    # Иконки приложений
    create_app_icon(desktop, "Order System", "order_system", Vector2(0.1, 0.2))
    create_app_icon(desktop, "Radar", "radar", Vector2(0.1, 0.35))
    create_app_icon(desktop, "Weather", "weather", Vector2(0.1, 0.5))
    
    return desktop

func create_app_icon(parent: Control, name: String, app_id: String, position: Vector2):
    var button = Button.new()
    button.text = name
    button.custom_minimum_size = Vector2(120, 40)
    button.position = position * screen_resolution
    button.pressed.connect(open_app.bind(app_id))
    parent.add_child(button)

func create_order_app() -> Control:
    var order_app = VBoxContainer.new()
    order_app.name = "OrderSystem"
    
    var title = Label.new()
    title.text = "Система заказов снабжения"
    title.add_theme_font_override("font", font_large)
    title.add_theme_font_size_override("font_size", 24)
    order_app.add_child(title)
    
    # Список доступных товаров
    var scroll = ScrollContainer.new()
    scroll.custom_minimum_size = Vector2(screen_resolution.x * 0.8, screen_resolution.y * 0.6)
    
    var item_list = VBoxContainer.new()
    item_list.name = "ItemList"
    
    # Пример товаров (можно загружать из базы данных)
    var items = [
        {"name": "Бутылка воды", "price": 50, "id": "water"},
        {"name": "Комплект еды", "price": 120, "id": "food_kit"},
        {"name": "Топливо", "price": 200, "id": "fuel"},
        {"name": "Запчасти", "price": 350, "id": "parts"},
        {"name": "Научное оборудование", "price": 500, "id": "science"}
    ]
    
    for item in items:
        var hbox = HBoxContainer.new()
        hbox.custom_minimum_size = Vector2(0, 40)
        
        var name_label = Label.new()
        name_label.text = item.name
        name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        
        var price_label = Label.new()
        price_label.text = "$%d" % item.price
        
        var order_btn = Button.new()
        order_btn.text = "Заказать"
        order_btn.pressed.connect(order_item.bind(item.id))
        
        hbox.add_child(name_label)
        hbox.add_child(price_label)
        hbox.add_child(order_btn)
        item_list.add_child(hbox)
    
    scroll.add_child(item_list)
    order_app.add_child(scroll)
    
    # Статус заказа
    var status_label = Label.new()
    status_label.name = "StatusLabel"
    status_label.text = "Готов к заказу"
    order_app.add_child(status_label)
    
    return order_app

func create_radar_app() -> Control:
    var radar_app = Control.new()
    radar_app.name = "RadarApp"
    
    var radar_texture = TextureRect.new()
    radar_texture.name = "RadarView"
    radar_texture.texture = preload("res://textures/radar_base.png")
    radar_texture.anchor_right = 1.0
    radar_texture.anchor_bottom = 1.0
    radar_texture.stretch_mode = TextureRect.STRETCH_SCALE
    radar_app.add_child(radar_texture)
    
    # Индикаторы целей
    for i in 10:
        var target = TextureRect.new()
        target.name = "Target%d" % i
        target.texture = preload("res://textures/radar_target.png")
        target.visible = false
        radar_texture.add_child(target)
    
    # Кнопка сканирования
    var scan_btn = Button.new()
    scan_btn.text = "Сканировать"
    scan_btn.position = Vector2(screen_resolution.x * 0.8, screen_resolution.y * 0.9)
    scan_btn.pressed.connect(start_scan)
    radar_app.add_child(scan_btn)
    
    return radar_app

func create_weather_app() -> Control:
    var weather_app = VBoxContainer.new()
    weather_app.name = "WeatherApp"
    
    var title = Label.new()
    title.text = "Метеорологическая станция"
    title.add_theme_font_override("font", font_large)
    title.add_theme_font_size_override("font_size", 24)
    weather_app.add_child(title)
    
    # График температуры
    var temp_graph = TextureRect.new()
    temp_graph.name = "TempGraph"
    temp_graph.custom_minimum_size = Vector2(screen_resolution.x * 0.9, screen_resolution.y * 0.4)
    temp_graph.texture = generate_temp_graph()
    weather_app.add_child(temp_graph)
    
    # Текущие показания
    var readings = Label.new()
    readings.name = "CurrentReadings"
    readings.text = "Загрузка данных..."
    weather_app.add_child(readings)
    
    return weather_app

func generate_temp_graph() -> ImageTexture:
    # Генерация простого графика температуры
    var image = Image.create(800, 300, false, Image.FORMAT_RGBA8)
    image.fill(Color(0, 0, 0, 0.7))
    
    # Рисуем оси
    image.fill_rect(Rect2i(50, 50, 700, 2), Color.WHITE)
    image.fill_rect(Rect2i(50, 250, 700, 2), Color.WHITE)
    
    # Генерируем случайные данные температуры
    var rng = RandomNumberGenerator.new()
    var last_point = Vector2(50, 150)
    
    for i in 1..30:
        var x = 50 + i * 23
        var y = 150 + rng.randf_range(-80, 80)
        image.fill_rect(Rect2i(x-2, y-2, 4, 4), Color.RED)
        
        # Линия между точками
        if i > 1:
            image.draw_line(last_point, Vector2(x, y), Color.RED, 2)
        
        last_point = Vector2(x, y)
    
    var texture = ImageTexture.create_from_image(image)
    return texture

func update_clock():
    var time_dict = Time.get_datetime_dict_from_system()
    var time_str = "%02d:%02d:%02d\n%d.%02d.%04d" % [
        time_dict.hour, time_dict.minute, time_dict.second,
        time_dict.day, time_dict.month, time_dict.year
    ]
    
    var clock = gui_control.get_app("desktop").get_node("Clock")
    if clock:
        clock.text = time_str

func update_radar(delta):
    last_scan_time += delta
    
    # Обновление позиций целей
    for i in min(radar_targets.size(), 10):
        var target = gui_control.get_app("radar").get_node("RadarView/Target%d" % i)
        if target:
            target.visible = true
            var pos = radar_targets[i].position * Vector2(350, 350) + Vector2(400, 400)
            target.position = pos - Vector2(8, 8)
    
    # Автосканирование каждые 5 секунд
    if last_scan_time >= 5.0:
        start_scan()
        last_scan_time = 0.0

func start_scan():
    # Сканирование окружения для радара
    radar_targets.clear()
    
    var space_state = get_world_3d().direct_space_state
    var query = PhysicsShapeQueryParameters.new()
    query.shape = SphereShape3D.new()
    query.shape.radius = 100.0
    query.transform = global_transform
    query.collision_mask = 0b0010 # Слой для сканируемых объектов
    
    var results = space_state.intersect_shape(query, 10)
    
    for result in results:
        if result.collider.has_meta("radar_target"):
            var screen_pos = camera_position.transform.basis.xform_inv(
                result.position - global_position
            )
            radar_targets.append({
                "object": result.collider,
                "position": Vector2(screen_pos.x, screen_pos.z).normalized()
            })
    
    # Ограничиваем количество целей для отображения
    radar_targets = radar_targets.slice(0, 9)

func open_app(app_id: String):
    click_sound.play()
    current_app = app_id
    gui_control.show_app(app_id)

func order_item(item_id: String):
    click_sound.play()
    
    # Здесь можно подключить систему заказов
    var status_label = gui_control.get_app("order_system").get_node("StatusLabel")
    if status_label:
        status_label.text = "Заказ %s принят. Ожидайте доставки." % item_id
    
    # Симулируем задержку доставки
    await get_tree().create_timer(2.0).timeout
    if status_label:
        status_label.text = "Заказ %s доставлен на склад." % item_id

func interact(player: Node3D):
    if is_active: return
    
    player_ref = player
    enter_computer()

func enter_computer():
    if is_active: return
    
    is_active = true
    
    # Сохраняем оригинальную камеру
    original_camera_parent = player_ref.get_viewport().get_camera_3d().get_parent()
    original_camera_transform = player_ref.get_viewport().get_camera_3d().global_transform
    
    # Переключаем на камеру компьютера
    player_ref.get_viewport().get_camera_3d().get_parent().remove_child(
        player_ref.get_viewport().get_camera_3d()
    )
    camera_position.add_child(player_ref.get_viewport().get_camera_3d())
    player_ref.get_viewport().get_camera_3d().global_transform = camera_position.global_transform
    
    # Включаем GUI
    gui_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    animation_player.play("boot_up")
    boot_sound.play()
    
    # Блокируем движение игрока
    player_ref.set_process_input(false)
    Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func exit_computer():
    if !is_active: return
    
    is_active = false
    
    # Возвращаем камеру игроку
    player_ref.get_viewport().get_camera_3d().get_parent().remove_child(
        player_ref.get_viewport().get_camera_3d()
    )
    original_camera_parent.add_child(player_ref.get_viewport().get_camera_3d())
    player_ref.get_viewport().get_camera_3d().global_transform = original_camera_transform
    
    # Выключаем GUI
    gui_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
    animation_player.play("shut_down")
    
    # Восстанавливаем управление
    player_ref.set_process_input(true)
    Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
