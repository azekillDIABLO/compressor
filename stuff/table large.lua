-- GENERATED CODE
-- Node Box Editor, version 0.9.0
-- Namespace: test

minetest.register_node("test:node_1", {
	tiles = {
		"default_wood.png",
		"default_wood.png",
		"default_wood.png",
		"default_wood.png",
		"default_wood.png",
		"default_wood.png"
	},
	drawtype = "nodebox",
	paramtype = "light",
	node_box = {
		type = "fixed",
		fixed = {
			{-1.5625, 0.375, -1.5625, 1.5625, 0.5, 1.5625}, -- table_plate
			{1.25, -0.5, 1.25, 1.375, 0.5, 1.375}, -- table_feet_1
			{1.25, -0.5, -1.375, 1.375, 0.5, -1.25}, -- table_feet_2
			{-1.4375, -0.5, -1.375, -1.3125, 0.5, -1.25}, -- table_feet_3
			{-1.4375, -0.5, 1.25, -1.3125, 0.5, 1.375}, -- table_feet_4
		}
	}
})

