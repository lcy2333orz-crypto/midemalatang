extends Node

var active_effects: Array = []
var selected_stage_id: String = ""
var selected_difficulty_days: int = 7

# 主场景开局时使用的默认站点布局
var station_layout: Dictionary = {
	"counter": "",
	"delivery": "",
	"storage": "",
	"cooker_1": "",
	"cooker_2": "",
	"emergency_shop": ""
}

# 给未来“本局规则”预留，但当前不要在主逻辑里到处分叉使用
var run_modifiers: Dictionary = {
	"allow_pre_open_waiting_customers": false,
	"lock_station_layout": false
}

# ===== 一整轮（多天）运行数据 =====
var current_day_in_run: int = 1
var total_days_in_run: int = 7

var run_money: int = 0
var run_total_income: int = 0

var current_raw_stock: Dictionary = {}
var current_cooked_stock: Dictionary = {}

# ===== 夜间系统 / 特殊顾客接口 =====
# 未来可由别处提前写入“今天计划出现的特殊顾客”
# 当前允许为空；为空就代表今天没有真正进入主循环的特殊顾客
var current_day_special_spawn_plan: Array = []

# 按“服务结束顺序”记录的当天特殊顾客结算结果
# 例如：
# [
#   {"type": "mouse", "name": "老鼠", "result": "good"},
#   {"type": "cow", "name": "牛", "result": "bad"}
# ]
var today_special_customer_results: Array = []

# 当天实际生成给夜间页面读取的队列
var generated_night_queue: Array = []

# settlement_view_mode:
# "day" = 今日结算
# "run" = 本轮结算
var settlement_view_mode: String = "day"

var last_day_summary: Dictionary = {}
var last_run_summary: Dictionary = {}

func reset_run_setup() -> void:
	selected_stage_id = ""
	selected_difficulty_days = 7

	station_layout = {
		"counter": "",
		"delivery": "",
		"storage": "",
		"cooker_1": "",
		"cooker_2": "",
		"emergency_shop": ""
	}

	run_modifiers = {
		"allow_pre_open_waiting_customers": false,
		"lock_station_layout": false
	}

	current_day_in_run = 1
	total_days_in_run = 7

	run_money = 0
	run_total_income = 0

	current_raw_stock = {}
	current_cooked_stock = {}

	current_day_special_spawn_plan = []
	today_special_customer_results = []
	generated_night_queue = []
	active_effects = []

	settlement_view_mode = "day"
	last_day_summary = {}
	last_run_summary = {}

func setup_stage_run(stage_id: String, difficulty_days: int = 7) -> void:
	reset_run_setup()

	selected_stage_id = stage_id
	selected_difficulty_days = difficulty_days

	current_day_in_run = 1
	total_days_in_run = difficulty_days

	_apply_default_station_layout()

func _apply_default_station_layout() -> void:
	station_layout["counter"] = "slot_a"
	station_layout["delivery"] = "slot_b"
	station_layout["storage"] = "slot_c"
	station_layout["cooker_1"] = "slot_d"

	if ProgressData.has_second_cooker:
		station_layout["cooker_2"] = "slot_e"
		station_layout["emergency_shop"] = "slot_f"
	else:
		station_layout["cooker_2"] = ""
		station_layout["emergency_shop"] = "slot_e"

func setup_daily_special_customer_plan() -> void:
	current_day_special_spawn_plan = [
		{
			"type": "mouse",
			"name": "老鼠"
		}
	]
