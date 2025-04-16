extends PurchasableItem
class_name Microphone

@export var recording_time := 60.0
@export var playback_sound : AudioStream
@export var distortion_effect : AudioEffect

var is_recording := false
var recorded_sounds := []
var audio_effect_instance : AudioEffectInstance
var audio_stream : AudioStreamMicrophone

func _ready():
    item_name = "Микрофон"
    item_price = 350
    item_weight = 0.7
    
    # Настройка аудиоэффектов
    if distortion_effect:
        audio_effect_instance = distortion_effect.instantiate()

func _apply_effect(player):
    if is_recording:
        stop_recording(player)
    else:
        start_recording(player)

func start_recording(player):
    is_recording = true
    recorded_sounds.clear()
    
    # Начать запись звуков вокруг
    audio_stream = AudioStreamMicrophone.new()
    var recording = AudioStreamGenerator.new()
    
    var bus_idx = AudioServer.get_bus_index("Recording")
    AudioServer.add_bus_effect(bus_idx, audio_effect_instance)
    
    player.show_message("Запись начата")
    await get_tree().create_timer(recording_time).timeout
    stop_recording(player)

func stop_recording(player):
    is_recording = false
    
    # Остановить запись и воспроизвести
    if recorded_sounds.size() > 0:
        play_recorded_sounds()
    
    player.show_message("Запись остановлена")

func play_recorded_sounds():
    # Воспроизведение с эффектами
    audio_player.stream = playback_sound
    audio_player.unit_db = 10.0 # Усиление звука
    audio_player.play()

func _on_audio_listener_area_entered(area):
    if is_recording and area.is_in_group("sound_source"):
        recorded_sounds.append({
            "sound": area.get_sound(),
            "position": area.global_position
        })
