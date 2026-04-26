extends Control

@onready var card_container: Control = $CardContainer
@onready var card_buttons = [
	$CardContainer/Card1,
	$CardContainer/Card2,
	$CardContainer/Card3
]

@onready var night_queue_label: Label = $NightQueueLabel
@onready var title_label: Label = $TitleLabel

@onready var today_income_label: Label = $SummaryBox/TodayIncomeLabel
@onready var round_income_label: Label = $SummaryBox/RoundIncomeLabel
@onready var waste_label: Label = $SummaryBox/WasteLabel
@onready var profit_label: Label = $SummaryBox/ProfitLabel
@onready var money_label: Label = $SummaryBox/MoneyLabel
@onready var cooked_stock_label: Label = $SummaryBox/CookedStockLabel
@onready var raw_stock_label: Label = $SummaryBox/RawStockLabel

@onready var retry_button: Button = $ButtonBox/RetryButton
@onready var back_home_button: Button = $ButtonBox/BackHomeButton

var night_queue: Array = []
var current_index: int = 0
var night_finished: bool = false

var card_db: Dictionary = {}

var card_overlay_bg: ColorRect = null
var card_choice_title_label: Label = null
var cat_feed_area: Panel = null
var cat_reaction_label: Label = null
var leftover_food_panel: Panel = null
var leftover_food_container: HBoxContainer = null
var leftover_cooked_stock_for_cat: Dictionary = {}
var cat_hand_fed_count: int = 0

func _ready() -> void:
	get_tree().paused = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("settlement_result")

	if has_method("load_card_db"):
		load_card_db()

	retry_button.visible = false
	back_home_button.visible = false
	retry_button.disabled = false
	back_home_button.disabled = false

	retry_button.mouse_filter = Control.MOUSE_FILTER_STOP
	back_home_button.mouse_filter = Control.MOUSE_FILTER_STOP
	$ButtonBox.z_index = 200

	var retry_callable := Callable(self, "_on_retry_button_pressed")
	if not retry_button.pressed.is_connected(retry_callable):
		retry_button.pressed.connect(_on_retry_button_pressed)

	var back_callable := Callable(self, "_on_back_home_button_pressed")
	if not back_home_button.pressed.is_connected(back_callable):
		back_home_button.pressed.connect(_on_back_home_button_pressed)

	waste_label.visible = true
	profit_label.visible = true

	_create_card_overlay()
	_create_cat_feed_widgets()
	_setup_layout_positions()

	if RunSetupData.settlement_view_mode == "run":
		_setup_run_settlement()
		_show_final_confirm_state()
		return

	_setup_day_settlement()
	setup_night_queue()
	show_current_choice()

	for i in range(3):
		var card_callable := Callable(self, "_on_card_selected").bind(i)

		if not card_buttons[i].pressed.is_connected(card_callable):
			card_buttons[i].pressed.connect(_on_card_selected.bind(i))

func load_card_db() -> void:
	var file := FileAccess.open("res://data/card_db.json", FileAccess.READ)

	if file == null:
		push_error("card_db.json not found")
		card_db = {}
		return

	var content := file.get_as_text()
	var json := JSON.new()
	var result := json.parse(content)

	if result != OK:
		push_error("card_db.json parse failed: " + json.get_error_message())
		card_db = {}
		return

	if typeof(json.data) != TYPE_DICTIONARY:
		push_error("card_db.json root must be a Dictionary")
		card_db = {}
		return

	card_db = json.data

func get_card_options_for_entry(entry: Dictionary) -> Array:
	var pool_name := "fallback"

	var entry_type := str(entry.get("type", ""))
	var result := str(entry.get("result", "neutral"))

	if entry_type == "insight":
		pool_name = "insight"
	elif result == "good":
		pool_name = "good"
	elif result == "bad":
		pool_name = "bad"

	var pools: Dictionary = card_db.get("pools", {})

	if not pools.has(pool_name):
		push_warning("Missing card pool: " + pool_name)
		return _get_fallback_card_options()

	var pool = pools[pool_name]

	if typeof(pool) != TYPE_ARRAY:
		push_warning("Card pool is not an Array: " + pool_name)
		return _get_fallback_card_options()

	var options: Array = []

	for card_data in pool:
		if typeof(card_data) != TYPE_DICTIONARY:
			continue

		options.append(card_data)

	if options.size() < 3:
		push_warning("Card pool has fewer than 3 cards: " + pool_name)
		return _get_fallback_card_options()

	return options.slice(0, 3)

func _get_fallback_card_options() -> Array:
	return [
		{
			"id": "tidy_up",
			"name": "整理一下"
		},
		{
			"id": "take_a_breath",
			"name": "缓一口气"
		},
		{
			"id": "cheer_up_again",
			"name": "重新打起精神"
		}
	]




func _show_confirm_button_only() -> void:
	$ButtonBox.visible = true
	$ButtonBox.z_index = 200
	$ButtonBox.mouse_filter = Control.MOUSE_FILTER_PASS

	retry_button.visible = true
	retry_button.disabled = false
	retry_button.text = "确认"
	retry_button.mouse_filter = Control.MOUSE_FILTER_STOP
	retry_button.z_index = 201

	back_home_button.visible = false
	back_home_button.disabled = true

	retry_button.grab_focus()

func _create_card_overlay() -> void:
	card_overlay_bg = ColorRect.new()
	card_overlay_bg.name = "CardOverlayBackground"

	# 接近不透明，只保留一点“下面是日结背景”的感觉
	card_overlay_bg.color = Color(0.03, 0.03, 0.03, 0.90)
	card_overlay_bg.z_index = 10
	card_overlay_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(card_overlay_bg)

	card_choice_title_label = Label.new()
	card_choice_title_label.name = "CardChoiceTitleLabel"
	card_choice_title_label.text = ""
	card_choice_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_choice_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	card_choice_title_label.z_index = 30
	card_choice_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_choice_title_label.add_theme_font_size_override("font_size", 22)
	add_child(card_choice_title_label)

func _create_cat_feed_widgets() -> void:
	cat_feed_area = Panel.new()
	cat_feed_area.name = "CatFeedArea"
	cat_feed_area.size = Vector2(150, 120)
	cat_feed_area.z_index = 2
	cat_feed_area.mouse_filter = Control.MOUSE_FILTER_STOP
	cat_feed_area.set_script(preload("res://cat_feed_area.gd"))
	add_child(cat_feed_area)

	var cat_label := Label.new()
	cat_label.name = "CatLabel"
	cat_label.text = "🐱\n小猫"
	cat_label.position = Vector2(0, 12)
	cat_label.size = Vector2(150, 70)
	cat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cat_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cat_label.add_theme_font_size_override("font_size", 26)
	cat_feed_area.add_child(cat_label)

	var cat_hint := Label.new()
	cat_hint.name = "CatHintLabel"
	cat_hint.text = "拖熟食来喂\n或点击摸头"
	cat_hint.position = Vector2(0, 78)
	cat_hint.size = Vector2(150, 38)
	cat_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cat_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cat_hint.add_theme_font_size_override("font_size", 12)
	cat_feed_area.add_child(cat_hint)

	cat_reaction_label = Label.new()
	cat_reaction_label.name = "CatReactionLabel"
	cat_reaction_label.text = ""
	cat_reaction_label.size = Vector2(170, 34)
	cat_reaction_label.z_index = 5
	cat_reaction_label.visible = false
	cat_reaction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cat_reaction_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cat_reaction_label.add_theme_font_size_override("font_size", 18)
	add_child(cat_reaction_label)

	leftover_food_panel = Panel.new()
	leftover_food_panel.name = "LeftoverFoodPanel"
	leftover_food_panel.size = Vector2(420, 70)
	leftover_food_panel.z_index = 2
	add_child(leftover_food_panel)

	leftover_food_container = HBoxContainer.new()
	leftover_food_container.name = "LeftoverFoodContainer"
	leftover_food_container.position = Vector2(12, 18)
	leftover_food_container.size = Vector2(396, 42)
	leftover_food_panel.add_child(leftover_food_container)

func _setup_layout_positions() -> void:
	var viewport_size := get_viewport_rect().size

	# ===== 底层：日结信息 =====
	title_label.position = Vector2(
		viewport_size.x * 0.5 - 80,
		75
	)
	title_label.z_index = 0

	$SummaryBox.position = Vector2(
		viewport_size.x * 0.5 - 170,
		125
	)
	$SummaryBox.z_index = 0

	# ===== 夜间喂猫互动区：作为结算背景的一部分 =====
	if cat_feed_area != null:
		cat_feed_area.position = Vector2(
			viewport_size.x * 0.5 + 230,
			145
		)

	if cat_reaction_label != null:
		cat_reaction_label.position = Vector2(
			viewport_size.x * 0.5 + 220,
			112
		)

	if leftover_food_panel != null:
		leftover_food_panel.position = Vector2(
			viewport_size.x * 0.5 - 210,
			420
		)

	# ===== 上层：全屏抽卡蒙版 =====
	card_overlay_bg.position = Vector2.ZERO
	card_overlay_bg.size = viewport_size

	# ===== 抽卡内容：整个界面的正中间 =====
	card_choice_title_label.position = Vector2(
		viewport_size.x * 0.5 - 220,
		125
	)
	card_choice_title_label.size = Vector2(440, 36)

	night_queue_label.position = Vector2(
		viewport_size.x * 0.5 - 260,
		175
	)
	night_queue_label.size = Vector2(520, 30)
	night_queue_label.z_index = 30
	night_queue_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	night_queue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	card_container.position = Vector2(
		viewport_size.x * 0.5 - 255,
		230
	)
	card_container.z_index = 30
	card_container.mouse_filter = Control.MOUSE_FILTER_PASS

	card_buttons[0].position = Vector2(0, 0)
	card_buttons[1].position = Vector2(175, 0)
	card_buttons[2].position = Vector2(350, 0)

	for button in card_buttons:
		button.custom_minimum_size = Vector2(150, 180)
		button.size = Vector2(150, 180)
		button.mouse_filter = Control.MOUSE_FILTER_STOP

	# 确认按钮只在抽完卡后显示
	$ButtonBox.position = Vector2(
		viewport_size.x * 0.5 - 120,
		510
	)
	$ButtonBox.z_index = 200


func _setup_day_settlement() -> void:
	var summary: Dictionary = RunSetupData.last_day_summary

	title_label.text = TextDB.get_text("UI_DAY_SETTLEMENT_TITLE") % int(summary.get("day_index", 1))
	today_income_label.text = TextDB.get_text("UI_SETTLEMENT_TODAY_INCOME") % int(summary.get("today_income", 0))
	round_income_label.text = TextDB.get_text("UI_SETTLEMENT_ROUND_INCOME") % int(summary.get("run_income", 0))
	money_label.text = TextDB.get_text("UI_SETTLEMENT_CURRENT_MONEY") % int(summary.get("current_money", 0))
	cooked_stock_label.text = "剩余熟食（收摊处理）：%s" % str(summary.get("cooked_stock_text", TextDB.get_text("UI_ITEM_NONE")))
	raw_stock_label.text = TextDB.get_text("UI_SETTLEMENT_RAW_STOCK") % str(summary.get("raw_stock_text", TextDB.get_text("UI_ITEM_NONE")))

	var reputation_delta: int = int(summary.get("today_reputation_delta", 0))
	var reputation_sign := ""

	if reputation_delta >= 0:
		reputation_sign = "+"

	waste_label.text = "今日口碑：%s%d" % [reputation_sign, reputation_delta]
	profit_label.text = "当前口碑：%d" % int(summary.get("shop_reputation", 50))

	retry_button.text = "确认"
	back_home_button.text = TextDB.get_text("UI_SETTLEMENT_ABORT_RUN")

	_setup_cat_leftover_food(summary)


func _setup_run_settlement() -> void:
	var summary: Dictionary = RunSetupData.last_run_summary

	title_label.text = TextDB.get_text("UI_RUN_SETTLEMENT_TITLE")
	today_income_label.text = TextDB.get_text("UI_SETTLEMENT_TOTAL_DAYS") % int(summary.get("total_days", 0))
	round_income_label.text = TextDB.get_text("UI_SETTLEMENT_ROUND_INCOME") % int(summary.get("run_income", 0))
	money_label.text = TextDB.get_text("UI_SETTLEMENT_CURRENT_MONEY") % int(summary.get("current_money", 0))
	cooked_stock_label.text = "剩余熟食（收摊处理）：%s" % str(summary.get("cooked_stock_text", TextDB.get_text("UI_ITEM_NONE")))
	raw_stock_label.text = TextDB.get_text("UI_SETTLEMENT_RAW_STOCK") % str(summary.get("raw_stock_text", TextDB.get_text("UI_ITEM_NONE")))

	var reputation_delta: int = int(summary.get("today_reputation_delta", 0))
	var reputation_sign := ""

	if reputation_delta >= 0:
		reputation_sign = "+"

	waste_label.text = "今日口碑：%s%d" % [reputation_sign, reputation_delta]
	profit_label.text = "当前口碑：%d" % int(summary.get("shop_reputation", 50))

	retry_button.text = "确认"
	back_home_button.text = TextDB.get_text("UI_SETTLEMENT_BACK_HOME")

	_setup_cat_leftover_food(summary)

func _setup_cat_leftover_food(summary: Dictionary) -> void:
	leftover_cooked_stock_for_cat = {}
	cat_hand_fed_count = 0

	var cooked_data = summary.get("cooked_stock_data", {})

	if typeof(cooked_data) == TYPE_DICTIONARY:
		for item_id in cooked_data.keys():
			var amount := int(cooked_data.get(item_id, 0))
			leftover_cooked_stock_for_cat[str(item_id)] = max(amount, 0)

	_refresh_leftover_food_buttons()


func _refresh_leftover_food_buttons() -> void:
	if leftover_food_container == null:
		return

	for child in leftover_food_container.get_children():
		child.queue_free()

	if not _has_leftover_food_for_cat():
		var empty_label := Label.new()
		empty_label.text = "今天没有剩余熟食，可以摸摸小猫。"
		empty_label.size = Vector2(390, 34)
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_label.add_theme_font_size_override("font_size", 14)
		leftover_food_container.add_child(empty_label)
		return

	for item_id in leftover_cooked_stock_for_cat.keys():
		var amount := int(leftover_cooked_stock_for_cat.get(item_id, 0))

		if amount <= 0:
			continue

		var button := Button.new()
		button.set_script(preload("res://draggable_leftover_food_button.gd"))
		button.custom_minimum_size = Vector2(120, 36)
		button.size = Vector2(120, 36)
		button.call("setup", item_id, _get_food_display_name(item_id), amount)

		leftover_food_container.add_child(button)


func _has_leftover_food_for_cat() -> bool:
	for item_id in leftover_cooked_stock_for_cat.keys():
		if int(leftover_cooked_stock_for_cat.get(item_id, 0)) > 0:
			return true

	return false


func _get_food_display_name(item_id: String) -> String:
	return TextDB.get_item_name(item_id)


func feed_cat_with_leftover_food(item_id: String) -> void:
	if item_id == "":
		return

	if not leftover_cooked_stock_for_cat.has(item_id):
		show_cat_reaction("喵？")
		return

	var amount := int(leftover_cooked_stock_for_cat.get(item_id, 0))

	if amount <= 0:
		show_cat_reaction("已经吃完啦")
		return

	leftover_cooked_stock_for_cat[item_id] = amount - 1
	cat_hand_fed_count += 1

	var reaction_options: Array[String] = [
		"喵~",
		"好吃！",
		"呼噜呼噜",
		"满足~",
		"❤️"
	]

	show_cat_reaction(reaction_options[randi() % reaction_options.size()])
	_refresh_leftover_food_buttons()

	if not _has_leftover_food_for_cat():
		show_cat_reaction("小猫把今天剩下的都解决啦")


func pet_settlement_cat() -> void:
	var pet_options: Array[String] = [
		"喵~",
		"蹭蹭",
		"呼噜~",
		"❤️",
		"今天也辛苦啦"
	]

	show_cat_reaction(pet_options[randi() % pet_options.size()])


func show_cat_reaction(text: String) -> void:
	if cat_reaction_label == null:
		return

	cat_reaction_label.text = text
	cat_reaction_label.visible = true
	cat_reaction_label.modulate.a = 1.0
	cat_reaction_label.scale = Vector2.ONE

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(cat_reaction_label, "position:y", cat_reaction_label.position.y - 12.0, 0.8)
	tween.tween_property(cat_reaction_label, "modulate:a", 0.0, 0.8)
	tween.tween_property(cat_reaction_label, "scale", Vector2(1.15, 1.15), 0.8)

	await get_tree().create_timer(0.85).timeout

	if is_instance_valid(cat_reaction_label):
		cat_reaction_label.visible = false
		_setup_layout_positions()


func clear_leftover_food_for_next_day() -> void:
	if _has_leftover_food_for_cat():
		print("剩余熟食被小猫收拾掉了：", leftover_cooked_stock_for_cat)

	leftover_cooked_stock_for_cat = {}
	_refresh_leftover_food_buttons()

func setup_night_queue() -> void:
	night_queue = RunSetupData.generated_night_queue.duplicate(true)

	if night_queue.is_empty():
		night_queue = [
			{"type": "insight", "name": "小猫领悟", "result": "neutral"}
		]

	current_index = 0
	night_finished = false
	update_night_queue_preview()


func show_current_choice() -> void:
	if current_index >= night_queue.size():
		finish_night()
		return

	var entry: Dictionary = night_queue[current_index]
	var options: Array = get_card_options_for_entry(entry)

	card_overlay_bg.visible = true
	card_choice_title_label.visible = true
	night_queue_label.visible = true
	card_container.visible = true

	retry_button.visible = false
	back_home_button.visible = false

	card_choice_title_label.text = get_night_choice_title(entry)
	update_night_queue_preview()

	for i in range(3):
		var card_data: Dictionary = options[i]
		card_buttons[i].text = str(card_data.get("name", "未知卡牌"))
		card_buttons[i].set_meta("card_id", str(card_data.get("id", "unknown_card")))
		card_buttons[i].set_meta("card_name", str(card_data.get("name", "未知卡牌")))
		card_buttons[i].visible = true
		card_buttons[i].disabled = false


func get_night_choice_title(entry: Dictionary) -> String:
	var entry_type: String = str(entry.get("type", ""))
	var entry_name: String = str(entry.get("name", "特殊客人"))
	var result: String = str(entry.get("result", "neutral"))

	if entry_type == "insight":
		return "小猫领悟"

	if result == "good":
		return "%s：成功服务结算" % entry_name

	if result == "bad":
		return "%s：服务失败结算" % entry_name

	return "%s：夜间结算" % entry_name


func _on_card_selected(index: int) -> void:
	if current_index >= night_queue.size():
		return

	var entry: Dictionary = night_queue[current_index]

	var chosen_id := str(card_buttons[index].get_meta("card_id", "unknown_card"))
	var chosen_name := str(card_buttons[index].get_meta("card_name", card_buttons[index].text))

	print("选了：", chosen_name, " / id=", chosen_id)

	RunSetupData.active_effects.append({
		"source": entry.get("name", "unknown"),
		"type": entry.get("type", "unknown"),
		"result": entry.get("result", "neutral"),
		"effect_id": chosen_id,
		"effect": chosen_name
	})

	print("当前已获得效果列表：", RunSetupData.active_effects)

	current_index += 1
	show_current_choice()


func finish_night() -> void:
	night_finished = true
	get_tree().paused = false

	card_overlay_bg.visible = false
	card_choice_title_label.visible = false
	night_queue_label.visible = false
	card_container.visible = false

	for button in card_buttons:
		button.disabled = true
		button.visible = false

	_show_confirm_button_only()

	print("Night finished. Confirm button should be clickable now.")


func _show_final_confirm_state() -> void:
	night_finished = true
	get_tree().paused = false

	if card_overlay_bg != null:
		card_overlay_bg.visible = false

	if card_choice_title_label != null:
		card_choice_title_label.visible = false

	night_queue_label.visible = false
	card_container.visible = false

	for button in card_buttons:
		button.disabled = true
		button.visible = false

	_show_confirm_button_only()

	print("Final settlement confirm state ready.")


func update_night_queue_preview() -> void:
	var parts: Array[String] = []

	for i in range(night_queue.size()):
		var entry: Dictionary = night_queue[i]
		var text := ""

		if str(entry.get("type", "")) == "insight":
			text = "领悟"
		else:
			var name := str(entry.get("name", "特殊客人"))
			var result := str(entry.get("result", "neutral"))

			if result == "good":
				text = "%s✓" % name
			elif result == "bad":
				text = "%s✗" % name
			else:
				text = name

		if i == current_index:
			text = "【%s】" % text

		parts.append(text)

	night_queue_label.text = "今夜结算：%s" % "  ".join(parts)


func _on_retry_button_pressed() -> void:
	print("Confirm button pressed. mode=", RunSetupData.settlement_view_mode, " night_finished=", night_finished)

	get_tree().paused = false

	if RunSetupData.settlement_view_mode == "day":
		if not night_finished:
			print("Cannot continue: night is not finished yet.")
			return

		clear_leftover_food_for_next_day()

		RunSetupData.current_day_in_run += 1
		get_tree().change_scene_to_file("res://main.tscn")
		return

	clear_leftover_food_for_next_day()

	RunSetupData.reset_run_setup()
	get_tree().change_scene_to_file("res://home_menu.tscn")

func _on_back_home_button_pressed() -> void:
	RunSetupData.reset_run_setup()
	get_tree().change_scene_to_file("res://home_menu.tscn")
