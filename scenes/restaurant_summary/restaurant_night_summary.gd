extends Control

const HOME_SCENE_PATH = "res://scenes/menus/home_menu.tscn"
const RESTAURANT_SCENE_PATH = "res://scenes/gameplay/test_restaurant.tscn"

var summary_label: Label
var continue_button: Button
var home_button: Button


func _ready() -> void:
	_build_ui()
	_refresh_summary()


func _build_ui() -> void:
	var root: VBoxContainer = VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 180
	root.offset_top = 72
	root.offset_right = -180
	root.offset_bottom = -72
	root.add_theme_constant_override("separation", 18)
	add_child(root)

	var title_label: Label = Label.new()
	title_label.text = "夜间总结"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 32)
	root.add_child(title_label)

	summary_label = Label.new()
	summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	summary_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	summary_label.add_theme_font_size_override("font_size", 20)
	root.add_child(summary_label)

	continue_button = Button.new()
	continue_button.pressed.connect(_on_continue_pressed)
	root.add_child(continue_button)

	home_button = Button.new()
	home_button.text = "返回主页"
	home_button.pressed.connect(_on_home_pressed)
	root.add_child(home_button)


func _refresh_summary() -> void:
	var summary: Dictionary = RestaurantRunState.last_day_summary
	var day: int = int(summary.get("day", RestaurantRunState.current_day))
	var max_days: int = int(summary.get("max_days", RestaurantRunState.max_days))
	var completed: int = int(summary.get("completed_orders", 0))
	var failed: int = int(summary.get("failed_orders", 0))
	var queue_lost: int = int(summary.get("queue_lost_customers", 0))
	var money: int = int(summary.get("money_today", 0))
	var score: int = int(summary.get("score_today", 0))
	var review: String = str(summary.get("review_text", _get_review_text(score)))

	summary_label.text = "第 %d / %d 天结束\n完成订单：%d\n失败订单：%d\n排队流失：%d\n今日收入：%d\n今日评分：%d\n%s" % [
		day,
		max_days,
		completed,
		failed,
		queue_lost,
		money,
		score,
		review
	]

	if RestaurantRunState.is_run_complete():
		continue_button.text = "完成本轮，返回主页"
		home_button.visible = false
	else:
		continue_button.text = "继续下一天"
		home_button.visible = true


func _get_review_text(score: int) -> String:
	if score >= 30:
		return "评价：今天很顺。"
	if score >= 10:
		return "评价：还能再稳一点。"
	return "评价：明天先把节奏找回来。"


func _on_continue_pressed() -> void:
	if RestaurantRunState.is_run_complete():
		get_tree().change_scene_to_file(HOME_SCENE_PATH)
		return
	RestaurantRunState.advance_day()
	get_tree().change_scene_to_file(RESTAURANT_SCENE_PATH)


func _on_home_pressed() -> void:
	get_tree().change_scene_to_file(HOME_SCENE_PATH)
