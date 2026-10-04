class_name AnomalyEntry
extends Resource
# One row in Main's "anomaly_entries" list. The anomaly scene itself can have ANY
# script (or none). Main only needs this info to decide where/when to spawn it.

@export var scene: PackedScene
@export var type_id := ""                        # e.g. "mimic". Used for the "unique" check
@export_enum("order", "build") var station := "order"
@export var random_position := false             # true = random spot on screen instead of the station's marker
@export var unique := true                       # can't spawn while one of this type_id is alive
@export var attack_damage := 20.0                # dealt each time the scene emits its "attack" signal
@export var weight := 1.0                        # higher = picked more often
