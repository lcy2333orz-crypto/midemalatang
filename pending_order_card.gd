extends Panel

@onready var status_label: Label = $VBox/StatusLabel
@onready var main_food_label: Label = $VBox/MainFoodLabel
@onready var ingredients_label: Label = $VBox/IngredientsLabel
@onready var patience_label: Label = $VBox/PatienceLabel
@onready var extra_label: Label = $VBox/ExtraLabel

func _ready() -> void:
	custom_minimum_size = Vector2(180, 110)

func apply_data(card_data: Dictionary) -> void:
	var main_food_text: String = str(card_data.get("main_food_text", ""))
	var ingredients_text: String = str(card_data.get("ingredients_text", ""))
	var patience_text: String = str(card_data.get("patience_text", ""))

	status_label.visible = false
	extra_label.visible = false

	main_food_label.text = TextDB.get_text("UI_MAIN_FOOD") % main_food_text
	ingredients_label.text = TextDB.get_text("UI_INGREDIENTS") % ingredients_text
	patience_label.text = TextDB.get_text("UI_PATIENCE") % _parse_patience_text(patience_text)

func _parse_patience_text(patience_text: String) -> Array:
	var parts := patience_text.split("/")
	if parts.size() != 2:
		return [0, 0]

	return [int(parts[0]), int(parts[1])]
