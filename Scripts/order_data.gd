class_name OrderData
extends RefCounted

enum Ingredient { PATTY, CHEESE, TOMATO, LETTUCE }   # 0, 1, 2, 3

# BBCode colors and names for the speech bubble and the ticket
const BUN_COLOR = "#e3b574"

const NAMES = {
	Ingredient.PATTY: "Patty",
	Ingredient.CHEESE: "Cheese",
	Ingredient.TOMATO: "Tomato",
	Ingredient.LETTUCE: "Lettuce",
}

const COLORS = {
	Ingredient.PATTY: "#a0623a",
	Ingredient.CHEESE: "#f2c230",
	Ingredient.TOMATO: "#e0453a",
	Ingredient.LETTUCE: "#6cc24a",
}

var ingredients: Array[int] = []   # bottom to top, buns not included
var regular := 50.0                # patty cook split the customer wants
var flipped := 50.0
var customerIndex := 0


static func makeRandom(customerCount: int, minItems := 3, maxItems := 5) -> OrderData:
	var order := OrderData.new()
	order.customerIndex = randi_range(0, customerCount - 1)

	# exactly one patty, plus random extras (patty counts toward the total)
	for i in randi_range(minItems, maxItems) - 1:
		order.ingredients.append(randi_range(Ingredient.CHEESE, Ingredient.LETTUCE))
	order.ingredients.insert(randi_range(0, order.ingredients.size()), Ingredient.PATTY)

	# usually 50/50, sometimes weird (anything from 10 to 80 in steps of 5)
	if randf() < 0.6:
		order.regular = 50.0
		order.flipped = 50.0
	else:
		order.regular = randi_range(2, 16) * 5.0
		order.flipped = randi_range(2, 16) * 5.0
	return order


func isCorrect(burger: Array[int], burgerRegular: float, burgerFlipped: float, tolerance: float) -> bool:
	print("want ", ingredients, "  ", regular, "/", flipped)
	print("got  ", burger, "  ", burgerRegular, "/", burgerFlipped)

	if burger.size() != ingredients.size():
		print("FAIL: different number of layers")
		return false
	for i in ingredients.size():
		if burger[i] != ingredients[i]:
			print("FAIL: layer ", i, " differs (", burger[i], " vs ", ingredients[i], ")")
			return false

	var straight := absf(burgerRegular - regular) <= tolerance and absf(burgerFlipped - flipped) <= tolerance
	var swapped := absf(burgerRegular - flipped) <= tolerance and absf(burgerFlipped - regular) <= tolerance
	if not (straight or swapped):
		print("FAIL: cook values out of tolerance")
	return straight or swapped


func toBBCode() -> String:
	var lines: Array[String] = [_colored("Bun", BUN_COLOR)]
	# ingredients are stored bottom to top, but the ticket reads top to bottom,
	# so print them reversed to match what the burger looks like
	for i in range(ingredients.size() - 1, -1, -1):
		var ing := ingredients[i]
		var text: String = NAMES[ing]
		if ing == Ingredient.PATTY:
			text += "\n(%d%%/%d%%)" % [int(regular), int(flipped)]
		lines.append(_colored(text, COLORS[ing]))
	lines.append(_colored("Bun", BUN_COLOR))
	return "\n".join(lines)


func _colored(text: String, hex: String) -> String:
	return "[color=%s]%s[/color]" % [hex, text]
