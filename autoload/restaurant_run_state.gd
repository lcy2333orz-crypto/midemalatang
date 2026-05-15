extends Node

var current_day: int = 1
var max_days: int = 3
var total_money: int = 0
var total_completed_orders: int = 0
var total_failed_orders: int = 0
var queue_lost_customers: int = 0
var last_day_summary: Dictionary = {}


func start_new_run(new_max_days: int = 3) -> void:
	current_day = 1
	max_days = max(1, new_max_days)
	total_money = 0
	total_completed_orders = 0
	total_failed_orders = 0
	queue_lost_customers = 0
	last_day_summary = {}


func record_day(summary: Dictionary) -> void:
	last_day_summary = summary.duplicate(true)
	total_money += int(summary.get("money_today", 0))
	total_completed_orders += int(summary.get("completed_orders", 0))
	total_failed_orders += int(summary.get("failed_orders", 0))
	queue_lost_customers += int(summary.get("queue_lost_customers", 0))


func advance_day() -> void:
	current_day = min(current_day + 1, max_days)


func is_run_complete() -> bool:
	return current_day >= max_days
