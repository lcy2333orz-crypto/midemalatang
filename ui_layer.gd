extends CanvasLayer

@onready var money_label: Label = $MoneyLabel
@onready var patience_label: Label = $PatienceLabel

@onready var order_panel: Panel = $OrderPanel
@onready var title_label: Label = $OrderPanel/TitleLabel
@onready var main_food_label: Label = $OrderPanel/MainFoodLabel
@onready var ingredients_label: Label = $OrderPanel/IngredientsLabel

@onready var stock_panel: Panel = $StockPanel
@onready var cooked_stock_label: Label = $StockPanel/CookedStockLabel
@onready var raw_stock_label: Label = $StockPanel/RawStockLabel

@onready var pending_orders_panel: Panel = $PendingOrdersPanel
@onready var orders_label: Label = $PendingOrdersPanel/OrdersLabel

var stock_visibility_token: int = 0

func _ready() -> void:
	hide_order()
	stock_panel.visible = false
	update_money(0)
	hide_patience()
	hide_pending_orders()

func update_money(amount: int) -> void:
	money_label.text = "Money: %d" % amount

func show_order(order_name: String, main_food: String, ingredients_text: String) -> void:
	order_panel.visible = true
	title_label.text = "订单: %s" % order_name
	main_food_label.text = "主食: %s" % main_food
	ingredients_label.text = "食材: %s" % ingredients_text

func hide_order() -> void:
	order_panel.visible = false

func show_stock(cooked_text: String, raw_text: String) -> void:
	stock_visibility_token += 1
	stock_panel.visible = true
	cooked_stock_label.text = cooked_text
	raw_stock_label.text = raw_text

func hide_stock() -> void:
	stock_visibility_token += 1
	var my_token := stock_visibility_token
	_delayed_hide_stock(my_token)

func _delayed_hide_stock(token: int) -> void:
	await get_tree().create_timer(3.0).timeout

	if token != stock_visibility_token:
		return

	stock_panel.visible = false

func show_patience(current_value: float, max_value: float) -> void:
	patience_label.visible = true
	patience_label.text = "Patience: %d / %d" % [int(ceil(current_value)), int(max_value)]

func hide_patience() -> void:
	patience_label.visible = false

func show_pending_orders(order_text: String) -> void:
	pending_orders_panel.visible = true
	orders_label.text = order_text

func hide_pending_orders() -> void:
	pending_orders_panel.visible = false
	orders_label.text = ""
