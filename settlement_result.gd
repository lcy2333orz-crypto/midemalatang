extends Control

@onready var card_buttons = [
	$CardContainer/Card1,
	$CardContainer/Card2,
	$CardContainer/Card3
]

var night_queue: Array = []
var current_index := 0

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

func _ready() -> void:
	retry_button.visible = false
	back_home_button.visible = false

	waste_label.visible = false
	profit_label.visible = false

	if RunSetupData.settlement_view_mode == "run":
		_setup_run_settlement()
		return

	_setup_day_settlement()

	setup_night_queue()
	show_current_choice()

	for i in range(3):
		card_buttons[i].pressed.connect(_on_card_selected.bind(i))

func _setup_day_settlement() -> void:
	var summary: Dictionary = RunSetupData.last_day_summary

	title_label.text = TextDB.get_text("UI_DAY_SETTLEMENT_TITLE") % int(summary.get("day_index", 1))

	today_income_label.text = TextDB.get_text("UI_SETTLEMENT_TODAY_INCOME") % int(summary.get("today_income", 0))
	round_income_label.text = TextDB.get_text("UI_SETTLEMENT_ROUND_INCOME") % int(summary.get("run_income", 0))
	money_label.text = TextDB.get_text("UI_SETTLEMENT_CURRENT_MONEY") % int(summary.get("current_money", 0))
	cooked_stock_label.text = TextDB.get_text("UI_SETTLEMENT_COOKED_STOCK") % str(summary.get("cooked_stock_text", TextDB.get_text("UI_ITEM_NONE")))
	raw_stock_label.text = TextDB.get_text("UI_SETTLEMENT_RAW_STOCK") % str(summary.get("raw_stock_text", TextDB.get_text("UI_ITEM_NONE")))

	retry_button.text = TextDB.get_text("UI_SETTLEMENT_NEXT_DAY")
	back_home_button.text = TextDB.get_text("UI_SETTLEMENT_ABORT_RUN")

func _setup_run_settlement() -> void:
	var summary: Dictionary = RunSetupData.last_run_summary

	title_label.text = TextDB.get_text("UI_RUN_SETTLEMENT_TITLE")

	today_income_label.text = TextDB.get_text("UI_SETTLEMENT_TOTAL_DAYS") % int(summary.get("total_days", 0))
	round_income_label.text = TextDB.get_text("UI_SETTLEMENT_ROUND_INCOME") % int(summary.get("run_income", 0))
	money_label.text = TextDB.get_text("UI_SETTLEMENT_CURRENT_MONEY") % int(summary.get("current_money", 0))
	cooked_stock_label.text = TextDB.get_text("UI_SETTLEMENT_COOKED_STOCK") % str(summary.get("cooked_stock_text", TextDB.get_text("UI_ITEM_NONE")))
	raw_stock_label.text = TextDB.get_text("UI_SETTLEMENT_RAW_STOCK") % str(summary.get("raw_stock_text", TextDB.get_text("UI_ITEM_NONE")))

	retry_button.text = TextDB.get_text("UI_SETTLEMENT_RESTART_RUN")
	back_home_button.text = TextDB.get_text("UI_SETTLEMENT_BACK_HOME")

func _on_retry_button_pressed() -> void:
	if RunSetupData.settlement_view_mode == "day":
		RunSetupData.current_day_in_run += 1
		get_tree().change_scene_to_file("res://main.tscn")
		return

	var stage_id := RunSetupData.selected_stage_id
	var difficulty_days := RunSetupData.selected_difficulty_days
	RunSetupData.setup_stage_run(stage_id, difficulty_days)
	get_tree().change_scene_to_file("res://main.tscn")

func _on_back_home_button_pressed() -> void:
	RunSetupData.reset_run_setup()
	get_tree().change_scene_to_file("res://home_menu.tscn")


func setup_night_queue() -> void:
	night_queue = RunSetupData.generated_night_queue.duplicate(true)

	if night_queue.is_empty():
		night_queue = [
			{"type": "insight", "name": "小猫领悟", "result": "neutral"}
		]

	current_index = 0
	update_night_queue_preview()
	
func show_current_choice() -> void:
	if current_index >= night_queue.size():
		finish_night()
		return

	update_night_queue_preview()

	var entry: Dictionary = night_queue[current_index]
	var options: Array[String] = []

	title_label.text = get_night_choice_title(entry)

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

	# 👇 记录效果（先只存文本）
	RunSetupData.active_effects.append({
		"source": entry.get("name", "unknown"),
		"type": entry.get("type", "unknown"),
		"result": entry.get("result", "neutral"),
		"effect": chosen_text
	})

	print("当前已获得效果列表：", RunSetupData.active_effects)

	current_index += 1
	show_current_choice()
func finish_night():
	RunSetupData.current_day_in_run += 1
	get_tree().change_scene_to_file("res://main.tscn")


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
