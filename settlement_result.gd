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

var card_overlay_bg: ColorRect = null
var card_choice_title_label: Label = null


func _ready() -> void:
	get_tree().paused = false
	process_mode = Node.PROCESS_MODE_ALWAYS

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


func _setup_layout_positions() -> void:
	var viewport_size := get_viewport_rect().size

	# ===== 底层：日结信息，正常居中显示 =====
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
		470
	)
	$ButtonBox.z_index = 40


func _setup_day_settlement() -> void:
	var summary: Dictionary = RunSetupData.last_day_summary

	title_label.text = TextDB.get_text("UI_DAY_SETTLEMENT_TITLE") % int(summary.get("day_index", 1))
	today_income_label.text = TextDB.get_text("UI_SETTLEMENT_TODAY_INCOME") % int(summary.get("today_income", 0))
	round_income_label.text = TextDB.get_text("UI_SETTLEMENT_ROUND_INCOME") % int(summary.get("run_income", 0))
	money_label.text = TextDB.get_text("UI_SETTLEMENT_CURRENT_MONEY") % int(summary.get("current_money", 0))
	cooked_stock_label.text = TextDB.get_text("UI_SETTLEMENT_COOKED_STOCK") % str(summary.get("cooked_stock_text", TextDB.get_text("UI_ITEM_NONE")))
	raw_stock_label.text = TextDB.get_text("UI_SETTLEMENT_RAW_STOCK") % str(summary.get("raw_stock_text", TextDB.get_text("UI_ITEM_NONE")))

	var reputation_delta: int = int(summary.get("today_reputation_delta", 0))
	var reputation_sign := ""

	if reputation_delta >= 0:
		reputation_sign = "+"

	waste_label.text = "今日口碑：%s%d" % [reputation_sign, reputation_delta]
	profit_label.text = "当前口碑：%d" % int(summary.get("shop_reputation", 50))

	retry_button.text = "确认"
	back_home_button.text = TextDB.get_text("UI_SETTLEMENT_ABORT_RUN")


func _setup_run_settlement() -> void:
	var summary: Dictionary = RunSetupData.last_run_summary

	title_label.text = TextDB.get_text("UI_RUN_SETTLEMENT_TITLE")
	today_income_label.text = TextDB.get_text("UI_SETTLEMENT_TOTAL_DAYS") % int(summary.get("total_days", 0))
	round_income_label.text = TextDB.get_text("UI_SETTLEMENT_ROUND_INCOME") % int(summary.get("run_income", 0))
	money_label.text = TextDB.get_text("UI_SETTLEMENT_CURRENT_MONEY") % int(summary.get("current_money", 0))
	cooked_stock_label.text = TextDB.get_text("UI_SETTLEMENT_COOKED_STOCK") % str(summary.get("cooked_stock_text", TextDB.get_text("UI_ITEM_NONE")))
	raw_stock_label.text = TextDB.get_text("UI_SETTLEMENT_RAW_STOCK") % str(summary.get("raw_stock_text", TextDB.get_text("UI_ITEM_NONE")))

	var reputation_delta: int = int(summary.get("today_reputation_delta", 0))
	var reputation_sign := ""

	if reputation_delta >= 0:
		reputation_sign = "+"

	waste_label.text = "今日口碑：%s%d" % [reputation_sign, reputation_delta]
	profit_label.text = "当前口碑：%d" % int(summary.get("shop_reputation", 50))

	retry_button.text = "确认"
	back_home_button.text = TextDB.get_text("UI_SETTLEMENT_BACK_HOME")


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
	var options: Array[String] = []

	card_overlay_bg.visible = true
	card_choice_title_label.visible = true
	night_queue_label.visible = true
	card_container.visible = true

	retry_button.visible = false
	back_home_button.visible = false

	card_choice_title_label.text = get_night_choice_title(entry)
	update_night_queue_preview()

	match str(entry.get("type", "")):
		"insight":
			options = ["爪爪飞舞", "慢慢来喵", "先备一点"]
		"good":
			options = ["热闹摊口", "一点不剩", "钻来钻去"]
		"bad":
			options = ["乱成一团", "顾客不耐烦", "节奏变慢"]
		_:
			options = ["整理一下", "缓一口气", "重新打起精神"]

	for i in range(3):
		card_buttons[i].text = options[i]
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
	var chosen_text: String = card_buttons[index].text

	print("选了：", chosen_text)

	RunSetupData.active_effects.append({
		"source": entry.get("name", "unknown"),
		"type": entry.get("type", "unknown"),
		"result": entry.get("result", "neutral"),
		"effect": chosen_text
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

		RunSetupData.current_day_in_run += 1
		get_tree().change_scene_to_file("res://main.tscn")
		return

	RunSetupData.reset_run_setup()
	get_tree().change_scene_to_file("res://home_menu.tscn")


func _on_back_home_button_pressed() -> void:
	RunSetupData.reset_run_setup()
	get_tree().change_scene_to_file("res://home_menu.tscn")
