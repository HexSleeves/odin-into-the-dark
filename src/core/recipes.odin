package core

Recipe :: struct {
	name:         string,
	material_id:  string,
	material_qty: int,
	result_id:    string,
	is_repair:    bool,
}

RECIPES :: [4]Recipe {
	{
		name = "Repair Pickaxe",
		material_id = "iron_ore",
		material_qty = 3,
		result_id = "",
		is_repair = true,
	},
	{
		name = "Copper Shield",
		material_id = "copper_ore",
		material_qty = 2,
		result_id = "copper_shield",
		is_repair = false,
	},
	{
		name = "Crystal Torch",
		material_id = "crystal_shard",
		material_qty = 2,
		result_id = "crystal_torch",
		is_repair = false,
	},
	{
		name = "Golden Amulet",
		material_id = "gold_nugget",
		material_qty = 1,
		result_id = "golden_amulet",
		is_repair = false,
	},
}
