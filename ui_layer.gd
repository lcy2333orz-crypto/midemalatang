extends CanvasLayer

@onready var money_label: Label = $MoneyLabel
@onready var patience_label: Label = $PatienceLabel
@onready var business_state_label: Label = $BusinessStateLabel

@onready var order_panel: Panel = $OrderPanel
@onready var title_label: Label = $OrderPanel/TitleLabel
@onready var main_food_label: Label = $OrderPanel/MainFoodLabel
@onready var ingredients_label: Label = $OrderPanel/IngredientsLabel

@onready var stock_panel: Panel = $StockPanel
@onready var cooked_stock_label: Label = $StockPanel/CookedStockLabel
@onready var raw_stock_label: Label = $StockPanel/RawStockLabel

@onready var pending_orders_panel: Panel = $PendingOrdersPanel
@onready var cards_container: HBoxContainer = $PendingOrdersPanel/CardsContainer

var stock_visibility_token: int = 0
var pending_order_card_scene: PackedScene = preload("res://pending_order_card.tscn")


func _ready() -> void:
	money_label.text = TextDB.get_text("UI_MONEY") % 0
	patience_label.text = TextDB.get_text("UI_PATIENCE_EMPTY")
	business_state_label.text = TextDB.get_text("UI_DAY_STATE_NOT_OPEN") % 0

	title_label.text = TextDB.get_text("UI_ORDER_EMPTY")
	main_food_label.text = TextDB.get_text("UI_MAIN_FOOD_EMPTY")
	ingredients_label.text = TextDB.get_text("UI_INGREDIENTS_EMPTY")
	cooked_stock_label.text = TextDB.get_text("UI_COOKED_STOCK_EMPTY")
	raw_stock_label.text = TextDB.get_text("UI_RAW_STOCK_EMPTY")

	hide_order()
	stock_panel.visible = false
	update_money(0)
	hide_patience()
	hide_pending_orders()


func update_money(value: int) -> void:
	money_label.text = "金钱：%d\n口碑：%d" % [
		value,
		RunSetupData.shop_reputation
	]


func show_order(order_name: String, main_food: String, ingredients_text: String) -> void:
	order_panel.visible = true
	title_label.text = TextDB.get_text("UI_ORDER_TITLE") % order_name
	main_food_label.text = TextDB.get_text("UI_MAIN_FOOD") % main_food
	ingredients_label.text = TextDB.get_text("UI_INGREDIENTS") % ingredients_text


func hide_order() -> void:
	order_panel.visible = false
	title_label.text = TextDB.get_text("UI_ORDER_EMPTY")
	main_food_label.text = TextDB.get_text("UI_MAIN_FOOD_EMPTY")
	ingredients_label.text = TextDB.get_text("UI_INGREDIENTS_EMPTY")


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
	cooked_stock_label.text = TextDB.get_text("UI_COOKED_STOCK_EMPTY")
	raw_stock_label.text = TextDB.get_text("UI_RAW_STOCK_EMPTY")


func show_patience(current_value: float, max_value: float) -> void:
	patience_label.visible = true
	patience_label.text = TextDB.get_text("UI_PATIENCE") % [
		int(ceil(current_value)),
		int(max_value)
	]


func hide_patience() -> void:
	patience_label.visible = false
	patience_label.text = TextDB.get_text("UI_PATIENCE_EMPTY")


func show_pending_orders(order_cards: Array) -> void:
	_clear_pending_order_cards()

	if order_cards.is_empty():
		hide_pending_orders()
		return

	pending_orders_panel.visible = true

	for card_data in order_cards:
		var card = pending_order_card_scene.instantiate()
		cards_container.add_child(card)
		card.apply_data(card_data)


func hide_pending_orders() -> void:
	pending_orders_panel.visible = false
	_clear_pending_order_cards()


func _clear_pending_order_cards() -> void:
	for child in cards_container.get_children():
		child.queue_free()


func update_business_state(
	day_time_left: float,
	is_open: bool,
	is_closing: bool,
	is_finished: bool,
	is_cleanup: bool = false
) -> void:
	if is_finished:
		business_state_label.text = TextDB.get_text("UI_DAY_STATE_FINISHED")
		return

	if is_cleanup:
		business_state_label.text = "收摊整理：在收银台按 E 进入结算"
		return

	if is_open:
		business_state_label.text = TextDB.get_text("UI_DAY_STATE_OPEN") % int(ceil(day_time_left))
		return

	if is_closing:
		business_state_label.text = TextDB.get_text("UI_DAY_STATE_CLOSING")
		return

	business_state_label.text = TextDB.get_text("UI_DAY_STATE_NOT_OPEN") % int(ceil(day_time_left))
