class_name SaveStore
extends RefCounted

const SECTION := "petri"
var path: String


func _init(custom_path: String = "user://petri.cfg") -> void:
	path = custom_path


func defaults() -> Dictionary:
	return {
		"best_score": 0,
		"best_time": 0.0,
		"sfx_volume": 0.8,
		"music_volume": 0.45,
		"fullscreen": false,
		"reduced_motion": false,
	}


func load_data() -> Dictionary:
	var data := defaults()
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return data
	for key in data.keys():
		data[key] = cfg.get_value(SECTION, key, data[key])
	return data


func save_data(data: Dictionary) -> Error:
	var cfg := ConfigFile.new()
	var safe := defaults()
	for key in safe.keys():
		cfg.set_value(SECTION, key, data.get(key, safe[key]))
	return cfg.save(path)


func update_bests(score: int, survival_time: float, data: Dictionary) -> bool:
	var changed := false
	if score > int(data.get("best_score", 0)):
		data["best_score"] = score
		changed = true
	if survival_time > float(data.get("best_time", 0.0)):
		data["best_time"] = survival_time
		changed = true
	if changed:
		save_data(data)
	return changed
