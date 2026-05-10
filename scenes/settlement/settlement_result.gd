extends Control



const SettlementWidgetsControllerScript = preload("res://scenes/settlement/settlement_widgets_controller.gd")



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

var stall_echo_label: Label = null

var night_activity_label: Label = null

var night_tutorial_label: Label = null



var expense_label: Label = null

var net_income_label: Label = null



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



	var retry_callable: Callable = Callable(self, "_on_retry_button_pressed")

	if not retry_button.pressed.is_connected(retry_callable):

		retry_button.pressed.connect(_on_retry_button_pressed)



	var back_callable: Callable = Callable(self, "_on_back_home_button_pressed")

	if not back_home_button.pressed.is_connected(back_callable):

		back_home_button.pressed.connect(_on_back_home_button_pressed)



	waste_label.visible = true

	profit_label.visible = true



	_create_card_overlay()

	_create_cat_feed_widgets()

	_create_stall_echo_label()

	_create_night_activity_label()

	_create_night_tutorial_label()

	_create_accounting_extra_labels()

	_setup_layout_positions()



	if RunSetupData.get_settlement_view_mode() == "run":

		_setup_run_settlement()

		_show_final_confirm_state()

		return



	_setup_day_settlement()

	if RunSetupData.current_day_in_run >= RunSetupData.total_days_in_run:
		night_finished = true
		card_overlay_bg.visible = false
		card_choice_title_label.visible = false
		night_queue_label.visible = false
		card_container.visible = false
		_show_confirm_button_only()
		return

	setup_night_queue()
	show_current_choice()



	for i in range(3):

		var card_callable: Callable = Callable(self, "_on_card_selected").bind(i)



		if not card_buttons[i].pressed.is_connected(card_callable):

			card_buttons[i].pressed.connect(_on_card_selected.bind(i))



func load_card_db() -> void:

	var file: FileAccess = FileAccess.open("res://data/card_db.json", FileAccess.READ)



	if file == null:

		push_error("card_db.json not found")

		card_db = {}

		return



	var content: String = file.get_as_text()

	var json: JSON = JSON.new()

	var result: int = json.parse(content)



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

	var pool_name: String = "fallback"



	var entry_type: String = str(entry.get("type", ""))

	var result: String = str(entry.get("result", "neutral"))



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



		options.append(_with_card_display_text(card_data))



	if options.size() < 3:

		push_warning("Card pool has fewer than 3 cards: " + pool_name)

		return _get_fallback_card_options()



	return options.slice(0, 3)



func _get_card_text_value(card_data: Dictionary, key_field: String, fallback_field: String) -> String:

	var text_key: String = str(card_data.get(key_field, ""))

	if text_key != "":

		return TextDB.get_text(text_key)



	return str(card_data.get(fallback_field, ""))





func _with_card_display_text(card_data: Dictionary) -> Dictionary:

	var result: Dictionary = card_data.duplicate(true)

	var name_text: String = _get_card_text_value(result, "name_key", "name")

	var description_text: String = _get_card_text_value(result, "description_key", "description")



	if name_text != "":

		result["name"] = name_text



	if description_text != "":

		result["description"] = description_text



	return result



func _get_fallback_card_options() -> Array:

	return [

		{

			"id": "tidy_up",

			"name": TextDB.get_text("UI_CARD_TIDY_UP_NAME"),

			"description": TextDB.get_text("UI_CARD_TIDY_UP_DESC"),

			"modifiers": {

				"random_raw_stock_bonus": 1

			}

		},

		{

			"id": "take_a_breath",

			"name": TextDB.get_text("UI_CARD_TAKE_A_BREATH_NAME"),

			"description": TextDB.get_text("UI_CARD_TAKE_A_BREATH_DESC"),

			"modifiers": {

				"customer_patience_multiplier": 1.1

			}

		},

		{

			"id": "cheer_up_again",

			"name": TextDB.get_text("UI_CARD_CHEER_UP_AGAIN_NAME"),

			"description": TextDB.get_text("UI_CARD_CHEER_UP_AGAIN_DESC"),

			"modifiers": {

				"customer_spawn_interval_multiplier": 0.95

			}

		}

	]



func _show_confirm_button_only() -> void:

	$ButtonBox.visible = true

	$ButtonBox.z_index = 200

	$ButtonBox.mouse_filter = Control.MOUSE_FILTER_PASS



	retry_button.visible = true

	retry_button.disabled = false

	retry_button.text = TextDB.get_text("UI_SETTLEMENT_CONFIRM")

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

	var widgets: Dictionary = SettlementWidgetsControllerScript.create_cat_feed_widgets(self)

	cat_feed_area = widgets.get("cat_feed_area", null) as Panel

	cat_reaction_label = widgets.get("cat_reaction_label", null) as Label

	leftover_food_panel = widgets.get("leftover_food_panel", null) as Panel

	leftover_food_container = widgets.get("leftover_food_container", null) as HBoxContainer



func _create_stall_echo_label() -> void:

	stall_echo_label = Label.new()

	stall_echo_label.name = "StallEchoLabel"

	stall_echo_label.size = Vector2(250, 210)

	stall_echo_label.z_index = 1

	stall_echo_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	stall_echo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

	stall_echo_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP

	stall_echo_label.add_theme_font_size_override("font_size", 14)

	add_child(stall_echo_label)



func _create_night_activity_label() -> void:

	night_activity_label = Label.new()

	night_activity_label.name = "NightActivityLabel"

	night_activity_label.size = Vector2(210, 54)

	night_activity_label.z_index = 3

	night_activity_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	night_activity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	night_activity_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	night_activity_label.add_theme_font_size_override("font_size", 13)

	add_child(night_activity_label)


func _create_night_tutorial_label() -> void:

	night_tutorial_label = Label.new()

	night_tutorial_label.name = "NightTutorialLabel"

	night_tutorial_label.text = ""

	night_tutorial_label.size = Vector2(620, 42)

	night_tutorial_label.z_index = 31

	night_tutorial_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	night_tutorial_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	night_tutorial_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	night_tutorial_label.add_theme_font_size_override("font_size", 15)

	night_tutorial_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.75))

	night_tutorial_label.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.03, 0.95))

	night_tutorial_label.add_theme_constant_override("outline_size", 3)

	night_tutorial_label.visible = false

	add_child(night_tutorial_label)



func _create_accounting_extra_labels() -> void:

	if expense_label == null:

		expense_label = Label.new()

		expense_label.name = "ExpenseLabel"

		expense_label.text = ""

		$SummaryBox.add_child(expense_label)



	if net_income_label == null:

		net_income_label = Label.new()

		net_income_label.name = "NetIncomeLabel"

		net_income_label.text = ""

		$SummaryBox.add_child(net_income_label)



func _setup_layout_positions() -> void:

	var viewport_size: Vector2 = get_viewport_rect().size



	var center_x: float = viewport_size.x * 0.5

	var top_y: float = 36.0



	# ===== 底层：标题 =====

	title_label.position = Vector2(center_x - 160, top_y)

	title_label.size = Vector2(320, 42)

	title_label.z_index = 0

	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	title_label.add_theme_font_size_override("font_size", 24)



	# ===== 左侧：今日账本 =====

	$SummaryBox.position = Vector2(35, 98)

	$SummaryBox.size = Vector2(270, 300)

	$SummaryBox.z_index = 0

	_arrange_summary_box_labels()



	# ===== 中间：今日小摊回响 =====

	if stall_echo_label != null:

		stall_echo_label.position = Vector2(center_x - 125, 108)

		stall_echo_label.size = Vector2(250, 220)



	# ===== 右侧：小猫收摊互动 =====

	if cat_feed_area != null:

		cat_feed_area.position = Vector2(viewport_size.x - 230, 110)



	if cat_reaction_label != null:

		cat_reaction_label.position = Vector2(viewport_size.x - 235, 72)



	if night_activity_label != null:

		night_activity_label.position = Vector2(viewport_size.x - 250, 265)



	# ===== 下方：剩余熟食拖拽区 =====

	if leftover_food_panel != null:

		leftover_food_panel.position = Vector2(center_x - 270, 400)



	# ===== 上层：全屏抽卡蒙版 =====

	card_overlay_bg.position = Vector2.ZERO

	card_overlay_bg.size = viewport_size



	# ===== 抽卡内容：界面正中间 =====

	card_choice_title_label.position = Vector2(center_x - 220, 125)

	card_choice_title_label.size = Vector2(440, 36)



	night_queue_label.position = Vector2(center_x - 260, 175)

	night_queue_label.size = Vector2(520, 30)

	night_queue_label.z_index = 30

	night_queue_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	night_queue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER



	if night_tutorial_label != null:

		night_tutorial_label.position = Vector2(center_x - 310, 195)

		night_tutorial_label.size = Vector2(620, 42)



	card_container.position = Vector2(center_x - 315, 230)

	card_container.z_index = 30

	card_container.mouse_filter = Control.MOUSE_FILTER_PASS



	card_buttons[0].position = Vector2(0, 0)

	card_buttons[1].position = Vector2(220, 0)

	card_buttons[2].position = Vector2(440, 0)



	for button in card_buttons:

		button.custom_minimum_size = Vector2(200, 190)

		button.size = Vector2(200, 190)

		button.mouse_filter = Control.MOUSE_FILTER_STOP

		button.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY

		button.clip_text = true

		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS



	# ===== 底部：确认按钮 =====

	$ButtonBox.position = Vector2(center_x - 120, viewport_size.y - 82)

	$ButtonBox.z_index = 200



func _arrange_summary_box_labels() -> void:

	var x: int = 16

	var y: int = 16

	var line_h: int = 28

	var label_w: int = 238

	var label_h: int = 24



	var labels: Array = [

		today_income_label,

		expense_label,

		net_income_label,

		round_income_label,

		money_label,

		waste_label,

		profit_label,

		raw_stock_label

	]



	for label in labels:

		if label == null:

			continue



		label.visible = true

		label.position = Vector2(x, y)

		label.size = Vector2(label_w, label_h)

		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

		label.add_theme_font_size_override("font_size", 14)



		y += line_h



	if cooked_stock_label != null:

		cooked_stock_label.visible = false



func _setup_day_settlement() -> void:

	var summary: Dictionary = RunSetupData.get_day_summary()



	title_label.text = TextDB.get_text("UI_DAY_SETTLEMENT_TITLE") % int(summary.get("day_index", 1))

	today_income_label.text = TextDB.get_text("UI_SETTLEMENT_TODAY_GROSS") % int(summary.get("today_gross_income", summary.get("today_income", 0)))



	if expense_label != null:

		expense_label.text = TextDB.get_text("UI_SETTLEMENT_TODAY_EXPENSE") % int(summary.get("today_expense", 0))



	if net_income_label != null:

		net_income_label.text = TextDB.get_text("UI_SETTLEMENT_TODAY_NET") % int(summary.get("today_net_income", summary.get("today_income", 0)))



	round_income_label.text = TextDB.get_text("UI_SETTLEMENT_RUN_NET") % int(summary.get("run_net_income", summary.get("run_income", 0)))

	money_label.text = TextDB.get_text("UI_SETTLEMENT_CURRENT_MONEY") % int(summary.get("current_money", 0))



	cooked_stock_label.visible = false

	raw_stock_label.visible = true

	raw_stock_label.text = TextDB.get_text("UI_SETTLEMENT_RAW_STOCK") % str(summary.get("raw_stock_text", TextDB.get_text("UI_ITEM_NONE")))



	var reputation_delta: int = int(summary.get("today_reputation_delta", 0))

	var reputation_sign: String = ""



	if reputation_delta >= 0:

		reputation_sign = "+"



	waste_label.text = TextDB.get_text("UI_SETTLEMENT_TODAY_REPUTATION") % [reputation_sign, reputation_delta]

	profit_label.text = TextDB.get_text("UI_SETTLEMENT_CURRENT_REPUTATION") % int(summary.get("shop_reputation", 50))



	retry_button.text = TextDB.get_text("UI_SETTLEMENT_CONFIRM")

	back_home_button.text = TextDB.get_text("UI_SETTLEMENT_ABORT_RUN")



	_setup_stall_echo(summary)

	_setup_cat_leftover_food(summary)

	_setup_night_activity(true)

	_setup_layout_positions()



func _setup_run_settlement() -> void:
	var summary: Dictionary = RunSetupData.get_run_summary()

	var total_days: int = int(summary.get("total_days", RunSetupData.total_days_in_run))
	var run_gross_income: int = int(summary.get("run_gross_income", 0))
	var run_expense: int = int(summary.get("run_expense", 0))
	var run_net_income: int = int(summary.get("run_net_income", summary.get("run_income", 0)))
	var current_money: int = int(summary.get("current_money", 0))

	title_label.text = TextDB.get_text("UI_RUN_SETTLEMENT_COMPLETE_TITLE") % total_days

	today_income_label.text = TextDB.get_text("UI_RUN_SETTLEMENT_TOTAL_SALES") % run_gross_income

	if expense_label != null:
		expense_label.text = TextDB.get_text("UI_RUN_SETTLEMENT_TOTAL_EXPENSE") % run_expense

	if net_income_label != null:
		net_income_label.text = TextDB.get_text("UI_RUN_SETTLEMENT_NET_PROFIT") % run_net_income
		net_income_label.add_theme_font_size_override("font_size", 20)

	round_income_label.text = TextDB.get_text("UI_RUN_SETTLEMENT_FINAL_CASH") % current_money
	money_label.text = TextDB.get_text("UI_RUN_SETTLEMENT_EARNED_HINT")

	cooked_stock_label.visible = false

	raw_stock_label.visible = true
	raw_stock_label.text = TextDB.get_text("UI_RUN_SETTLEMENT_CARRIED_STOCK") % str(summary.get("raw_stock_text", TextDB.get_text("UI_ITEM_NONE")))

	var reputation_delta: int = int(summary.get("today_reputation_delta", 0))
	var reputation_sign: String = ""

	if reputation_delta >= 0:
		reputation_sign = "+"

	waste_label.text = TextDB.get_text("UI_RUN_SETTLEMENT_FINAL_DAY_REPUTATION") % [reputation_sign, reputation_delta]
	profit_label.text = TextDB.get_text("UI_RUN_SETTLEMENT_CURRENT_REPUTATION") % int(summary.get("shop_reputation", 50))

	retry_button.text = TextDB.get_text("UI_SETTLEMENT_CONFIRM")
	back_home_button.text = TextDB.get_text("UI_SETTLEMENT_BACK_HOME")

	_setup_stall_echo(summary)
	_setup_cat_leftover_food(summary)
	_setup_night_activity(false)
	_setup_layout_positions()


func _prepare_final_run_summary_from_day_summary() -> void:
	var day_summary: Dictionary = RunSetupData.get_day_summary()

	if day_summary.is_empty():
		push_warning("Final day run summary requested, but the day summary is empty.")

	var run_summary: Dictionary = day_summary.duplicate(true)
	var integer_fields: Array[String] = [
		"total_days",
		"today_gross_income",
		"today_expense",
		"today_net_income",
		"run_gross_income",
		"run_expense",
		"run_net_income",
		"current_money",
		"today_reputation_delta"
	]

	run_summary["total_days"] = int(run_summary.get("total_days", RunSetupData.total_days_in_run))

	for field_name in integer_fields:
		run_summary[field_name] = int(run_summary.get(field_name, 0))

	run_summary["shop_reputation"] = int(run_summary.get("shop_reputation", RunSetupData.shop_reputation))
	run_summary["cooked_stock_text"] = str(run_summary.get("cooked_stock_text", ""))
	run_summary["raw_stock_text"] = str(run_summary.get("raw_stock_text", TextDB.get_text("UI_ITEM_NONE")))
	run_summary["cooked_stock_data"] = run_summary.get("cooked_stock_data", {})
	run_summary["raw_stock_data"] = run_summary.get("raw_stock_data", {})
	run_summary["staple_stock_data"] = run_summary.get("staple_stock_data", {})
	run_summary["today_echo_lines"] = run_summary.get("today_echo_lines", [])
	run_summary["cooked_stock_discarded"] = true

	RunSetupData.set_run_summary(run_summary)


func _setup_stall_echo(summary: Dictionary) -> void:

	if stall_echo_label == null:

		return



	var echo_lines = summary.get("today_echo_lines", [])



	if typeof(echo_lines) != TYPE_ARRAY or echo_lines.is_empty():

		stall_echo_label.text = TextDB.get_text("UI_SETTLEMENT_STALL_ECHO_EMPTY")

		return



	var lines: Array[String] = []



	for line in echo_lines:

		lines.append(str(line))



	stall_echo_label.text = "

".join(lines)



func _setup_night_activity(has_next_day: bool) -> void:

	if night_activity_label == null:

		return



	var activity: Dictionary = RunSetupData.generate_night_background_activity(has_next_day)

	var activity_text: String = str(activity.get("activity_text", ""))



	if activity_text == "":

		night_activity_label.visible = false

		return



	night_activity_label.visible = true

	night_activity_label.text = activity_text



func _setup_cat_leftover_food(summary: Dictionary) -> void:

	leftover_cooked_stock_for_cat = {}

	cat_hand_fed_count = 0



	var cooked_data = summary.get("cooked_stock_data", {})



	if typeof(cooked_data) == TYPE_DICTIONARY:

		for item_id in cooked_data.keys():

			var amount: int = int(cooked_data.get(item_id, 0))

			leftover_cooked_stock_for_cat[str(item_id)] = max(amount, 0)



	_refresh_leftover_food_buttons()





func _refresh_leftover_food_buttons() -> void:

	if leftover_food_container == null:

		return



	for child in leftover_food_container.get_children():

		child.queue_free()



	if not _has_leftover_food_for_cat():

		leftover_food_container.add_child(SettlementWidgetsControllerScript.create_empty_leftover_label())

		return



	for item_id in leftover_cooked_stock_for_cat.keys():

		var amount: int = int(leftover_cooked_stock_for_cat.get(item_id, 0))



		if amount <= 0:

			continue



		leftover_food_container.add_child(

			SettlementWidgetsControllerScript.create_leftover_food_button(

				item_id,

				_get_food_display_name(item_id),

				amount

			)

		)





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

		show_cat_reaction(TextDB.get_text("UI_CAT_REACTION_CONFUSED"))

		return



	var amount: int = int(leftover_cooked_stock_for_cat.get(item_id, 0))



	if amount <= 0:

		show_cat_reaction(TextDB.get_text("UI_CAT_REACTION_FINISHED"))

		return



	leftover_cooked_stock_for_cat[item_id] = amount - 1

	cat_hand_fed_count += 1



	var reaction_options: Array[String] = [

		TextDB.get_text("UI_CAT_REACTION_EAT_1"),

		TextDB.get_text("UI_CAT_REACTION_EAT_2"),

		TextDB.get_text("UI_CAT_REACTION_EAT_3"),

		TextDB.get_text("UI_CAT_REACTION_EAT_4"),

		TextDB.get_text("UI_CAT_REACTION_EAT_5")

	]



	show_cat_reaction(reaction_options[randi() % reaction_options.size()])

	_refresh_leftover_food_buttons()



	if not _has_leftover_food_for_cat():

		show_cat_reaction(TextDB.get_text("UI_CAT_REACTION_ALL_DONE"))



func pet_settlement_cat() -> void:

	var pet_options: Array[String] = [

		TextDB.get_text("UI_CAT_REACTION_PET_1"),

		TextDB.get_text("UI_CAT_REACTION_PET_2"),

		TextDB.get_text("UI_CAT_REACTION_PET_3"),

		TextDB.get_text("UI_CAT_REACTION_PET_4"),

		TextDB.get_text("UI_CAT_REACTION_PET_5")

	]



	show_cat_reaction(pet_options[randi() % pet_options.size()])



func show_cat_reaction(text: String) -> void:

	if cat_reaction_label == null:

		return



	cat_reaction_label.text = text

	cat_reaction_label.visible = true

	cat_reaction_label.modulate.a = 1.0

	cat_reaction_label.scale = Vector2.ONE



	var tween: Tween = create_tween()

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

		show_cat_reaction(TextDB.get_text("UI_CAT_REACTION_CLEAN_LEFTOVERS"))



	leftover_cooked_stock_for_cat = {}

	_refresh_leftover_food_buttons()



func setup_night_queue() -> void:

	night_queue = RunSetupData.generated_night_queue.duplicate(true)



	if night_queue.is_empty():

		night_queue = [

			{"type": "insight", "name": TextDB.get_text("UI_NIGHT_CHOICE_INSIGHT"), "result": "neutral"}

		]



	current_index = 0

	night_finished = false

	update_night_queue_preview()



func format_card_button_text(card_name: String, card_description: String) -> String:

	var wrapped_description: String = wrap_cjk_text(card_description, 12)



	if wrapped_description == "":

		return card_name



	return "%s\n\n%s" % [

		card_name,

		wrapped_description

	]





func wrap_cjk_text(text: String, max_chars_per_line: int = 12) -> String:

	var cleaned: String = text.strip_edges()



	if cleaned == "":

		return ""



	var lines: Array[String] = []

	var current_line: String = ""



	for i in range(cleaned.length()):

		var ch: String = cleaned.substr(i, 1)

		current_line += ch



		if current_line.length() >= max_chars_per_line:

			lines.append(current_line)

			current_line = ""



	if current_line != "":

		lines.append(current_line)



	return "\n".join(lines)



func show_current_choice() -> void:

	if current_index >= night_queue.size():

		finish_night()

		return



	var entry: Dictionary = night_queue[current_index]

	var options: Array = get_card_options_for_entry(entry)



	card_overlay_bg.visible = true

	card_choice_title_label.visible = true

	night_queue_label.visible = true

	if night_tutorial_label != null:

		night_tutorial_label.visible = RunSetupData.is_tutorial_day_1()

		night_tutorial_label.text = TextDB.get_text("UI_TUTORIAL_NIGHT_CHOICE")

	card_container.visible = true

	retry_button.visible = false

	back_home_button.visible = false



	card_choice_title_label.text = get_night_choice_title(entry)

	update_night_queue_preview()



	for i in range(3):

		var card_data: Dictionary = options[i]

		var card_name: String = str(card_data.get("name", TextDB.get_text("UI_FALLBACK_UNKNOWN_CARD")))

		var card_description: String = str(card_data.get("description", ""))



		card_buttons[i].text = format_card_button_text(card_name, card_description)

		card_buttons[i].set_meta("card_id", str(card_data.get("id", "unknown_card")))

		card_buttons[i].set_meta("card_name", card_name)

		card_buttons[i].visible = true

		card_buttons[i].disabled = false



		card_buttons[i].autowrap_mode = TextServer.AUTOWRAP_ARBITRARY

		card_buttons[i].clip_text = true

		card_buttons[i].text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS





func get_night_choice_title(entry: Dictionary) -> String:

	var entry_type: String = str(entry.get("type", ""))

	var entry_name: String = str(entry.get("name", TextDB.get_text("UI_FALLBACK_SPECIAL_CUSTOMER")))

	var result: String = str(entry.get("result", "neutral"))



	if entry_type == "insight":

		return TextDB.get_text("UI_NIGHT_CHOICE_INSIGHT")



	if result == "good":

		return TextDB.get_text("UI_NIGHT_CHOICE_GOOD") % entry_name



	if result == "bad":

		return TextDB.get_text("UI_NIGHT_CHOICE_BAD") % entry_name



	return TextDB.get_text("UI_NIGHT_CHOICE_NEUTRAL") % entry_name



func _on_card_selected(index: int) -> void:

	if current_index >= night_queue.size():

		return



	var entry: Dictionary = night_queue[current_index]



	var chosen_id: String = str(card_buttons[index].get_meta("card_id", "unknown_card"))

	var chosen_name: String = str(card_buttons[index].get_meta("card_name", card_buttons[index].text))

	var gift_id: String = str(entry.get("gift_id", ""))



	var source_name: String = str(entry.get("name", "unknown"))

	var effect_type: String = str(entry.get("type", "unknown"))

	var effect_result: String = str(entry.get("result", "neutral"))



	var chosen_card: Dictionary = {

		"id": chosen_id,

		"name": chosen_name

	}



	if gift_id != "":

		var gift_data: Dictionary = RunSetupData.get_unopened_gift_by_id(gift_id)



		if not gift_data.is_empty():

			source_name = str(gift_data.get("display_name", source_name))

			effect_type = "special_echo"

			RunSetupData.mark_gift_opened(gift_id, chosen_card)



	print("选了：", chosen_name, " / id=", chosen_id)



	var effect_data: Dictionary = {

		"source": source_name,

		"type": effect_type,

		"result": effect_result,

		"effect_id": chosen_id,

		"effect": chosen_name

	}



	if gift_id != "":

		effect_data["from_gift_id"] = gift_id



	RunSetupData.active_effects.append(effect_data)



	print("当前已获得效果列表：", RunSetupData.active_effects)



	current_index += 1

	show_current_choice()





func finish_night() -> void:

	night_finished = true

	get_tree().paused = false



	card_overlay_bg.visible = false

	card_choice_title_label.visible = false

	night_queue_label.visible = false

	if night_tutorial_label != null:

		night_tutorial_label.visible = false

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

	if night_tutorial_label != null:

		night_tutorial_label.visible = false

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

		var text: String = ""



		if str(entry.get("type", "")) == "insight":

			text = TextDB.get_text("UI_NIGHT_INSIGHT")

		else:

			var name: String = str(entry.get("name", TextDB.get_text("UI_FALLBACK_SPECIAL_CUSTOMER")))

			var result: String = str(entry.get("result", "neutral"))



			if result == "good":

				text = "%s+" % name

			elif result == "bad":

				text = "%s-" % name

			else:

				text = name



		if i == current_index:

			text = "[%s]" % text



		parts.append(text)



	night_queue_label.text = TextDB.get_text("UI_NIGHT_QUEUE") % "  ".join(parts)



func _on_retry_button_pressed() -> void:
	print("Confirm button pressed. mode=", RunSetupData.get_settlement_view_mode(), " night_finished=", night_finished)

	get_tree().paused = false

	if RunSetupData.get_settlement_view_mode() == "day":
		var is_final_day: bool = RunSetupData.current_day_in_run >= RunSetupData.total_days_in_run

		if is_final_day:
			print("Final day settlement confirmed. Entering run summary.")
			_prepare_final_run_summary_from_day_summary()
			clear_leftover_food_for_next_day()
			get_tree().change_scene_to_file("res://scenes/settlement/settlement_result.tscn")
			return

		if not night_finished:
			print("Cannot continue: night is not finished yet.")
			return

		clear_leftover_food_for_next_day()

		RunSetupData.current_day_in_run += 1
		get_tree().change_scene_to_file("res://scenes/gameplay/main.tscn")
		return

	clear_leftover_food_for_next_day()

	RunSetupData.reset_run_setup()
	get_tree().change_scene_to_file("res://scenes/menus/home_menu.tscn")

func _on_back_home_button_pressed() -> void:

	RunSetupData.reset_run_setup()

	get_tree().change_scene_to_file("res://scenes/menus/home_menu.tscn")
