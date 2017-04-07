-- Minetest mod: creepers
-- (c) Kai Gerd Müller
-- See README.txt for licensing and other information.
minetest.register_node("temple:spikes", {
	description = "Sandstone (trap)",
	tiles = {"default_sandstone.png"},
	groups = {crumbly = 1, cracky = 3},
	sounds = default.node_sound_stone_defaults(),
})
minetest.register_node("temple:temporary_icetrap", {
	description = "Ice (temporary trap)",
	tiles = {"default_ice.png"},
	is_ground_content = false,
	paramtype = "light",
	groups = {cracky = 3, puts_out_fire = 1},
	sounds = default.node_sound_glass_defaults(),
})
minetest.register_node("temple:icetrap", {
	description = "Ice (trap)",
	tiles = {"default_ice.png"},
	is_ground_content = false,
	paramtype = "light",
	groups = {cracky = 3, puts_out_fire = 1},
	sounds = default.node_sound_glass_defaults(),
})
minetest.register_node("temple:spike", {
	description = "Spike",
	paramtype = "light",
	drawtype = "mesh",
	mesh = "spikes.obj",
	tiles = {"default_steel_block.png"},
	groups = {cracky = 1, level = 2},
	sounds = default.node_sound_stone_defaults(),
})
minetest.register_node("temple:doom", {
	description = "Malediction Totem",
	paramtype = "light",
	tiles = {"crystal.png"},
	groups = {cracky = 1, level = 2},
	sounds = default.node_sound_stone_defaults(),
})
minetest.register_abm({
	nodenames = {"temple:spikes"},
	interval = 0.01,
	chance = 1,
	action = function(pos)
		pos.y = pos.y+1
		local spiked = false
		for _,i in pairs(minetest.get_objects_inside_radius(pos,1)) do
			i:set_hp(0)
			spiked = true
		end
		if spiked then
			minetest.add_node(pos,{name="temple:spike"})
		end
end,
})
minetest.register_abm({
	nodenames = {"temple:spike"},
	interval = 0.01,
	chance = 1,
	action = function(pos)
		pos.y = pos.y+1
		for _,i in pairs(minetest.get_objects_inside_radius(pos,1)) do
			i:set_hp(0)
		end
end,
})
minetest.register_abm({
	nodenames = {"temple:doom"},
	neighbors = {"air"},
	interval = 1,
	chance = 1,
	action = function(pos)
		for _,i in pairs(minetest.get_objects_inside_radius(pos,25)) do
			i:set_hp(0)
		end
end,
})
function chest_empty(pos)
	pos.y = pos.y +1
	return minetest.get_meta(pos):get_inventory():is_empty("main")

end
minetest.register_abm({
	nodenames = {"temple:temporary_icetrap"},
	neighbors = {"default:chest"},
	interval = 1,
	chance = 1,
	action = function(posi)
		if not chest_empty(posi) then minetest.add_node(vector.subtract(posi,{x=0,y=1,z=0}),{name="temple:icetrap"})end
end,
})
minetest.register_abm({
	nodenames = {"temple:icetrap"},
	neighbors = {"default:chest"},
	interval = 0.1,
	chance = 1,
	action = function(pos)
		if chest_empty(pos) then 
			minetest.add_node(pos,{name="temple:doom"})
			pos.y = pos.y-1
			minetest.add_node(pos,{name="default:ice"})
		end
end,
})
local ice_chest_stuff ={
{name="default:sword_mese",occurance = 1,min = 1,max = 1},
{name="default:shovel_mese",occurance = 3,min = 1,max = 1},
{name="default:pick_mese",occurance = 1,min = 1,max = 1},
{name="default:axe_mese",occurance = 2,min = 1,max = 1},
{name="default:mese",occurance = 1,min = 10,max = 30}}
local jungle_chest_stuff ={
{name="default:pick_mese",occurance = 1,min = 1,max = 1},
{name="default:mese",occurance = 1,min = 10,max = 30},
{name="default:shovel_mese",occurance = 9,min = 1,max = 1},
{name="default:pick_mese",occurance = 3,min = 1,max = 1},
{name="default:axe_mese",occurance = 6,min = 1,max = 1}}
local pyramid_chest_stuff = {
{name="default:obsidian",occurance = 1,min = 30,max = 99},
{name="default:mese",occurance = 2,min = 1,max = 10},
{name="default:shovel_mese",occurance = 9,min = 1,max = 1},
{name="default:pick_mese",occurance = 3,min = 1,max = 1},
{name="default:axe_mese",occurance = 6,min = 1,max = 1}}
local icy_chanche= 200
local jungle_chanche = 200
local desert_chanche = 200
local temples = {
{spawn = {"default:ice","default:snow"},chanche = icy_chanche,neighbors = {"air"},schematic = "icetemple.mts",sidelength = 11,relative_chest_position = {x=0,y=3,z=0},treasure = ice_chest_stuff},
{spawn = {"default:dirt_with_grass","default:junglegrass"},chanche = jungle_chanche,neighbors = {"air"},schematic = "jungletemple.mts",sidelength = 13,relative_chest_position = {x=-4,y=5,z=4},treasure = jungle_chest_stuff},
{spawn = {"default:sand"},chanche = desert_chanche,neighbors = {"air"},schematic = "pyramid.mts",sidelength = 19,relative_chest_position = {x=0,y=1,z=0},treasure = pyramid_chest_stuff}}
local default_chest_formspec =
	"size[8,9]" ..
	--default.gui_bg ..
	--default.gui_bg_img ..
	--default.gui_slots ..
	"list[current_name;main;0,0.3;8,4;]" ..
	"list[current_player;main;0,4.85;8,1;]" ..
	"list[current_player;main;0,6.08;8,3;8]" ..
	"listring[current_name;main]" ..
	"listring[current_player;main]"
	--default.get_hotbar_bg(0,4.85)

function fill_chest(pos,rel_pos,cstuff)
	minetest.after(2, function()
		local pos = vector.add(pos,rel_pos)
		local n = minetest.get_node(pos)
		if n and n.name and n.name == "default:chest" then
			local meta = minetest.get_meta(pos)
			meta:set_string("formspec", default_chest_formspec)
			meta:set_string("infotext", "Chest")
			local meta = minetest.get_meta(pos)
			local inv = meta:get_inventory()
			inv:set_size("main", 8*4)
			ilist = {}
			for _,stuff in pairs(cstuff) do
				if math.random(1,stuff.occurance) == 1 then
				local stack = {name=stuff.name, count = math.random(stuff.min,stuff.max)}
				inv:set_stack("main", math.random(1,32), stack)
				end
			end	
		end
	end)
end
function place_schematic_central(schematic,sidelen,pos)
	sidelen  = (sidelen-1)/2
	minetest.place_schematic(vector.subtract(pos,{x =sidelen ,y=0,z=sidelen}),minetest.get_modpath("temple") .. "/schematics/" .. schematic)
end
function place_temple(tdata)
minetest.register_abm({
	nodenames = tdata.spawn,
	neighbors = tdata.neighbors,
	interval = 500,
	chance = tdata.chanche*12,
	action = function(pos)
	pos.y = pos.y+1
	place_schematic_central(tdata.schematic,tdata.sidelength,pos)
	fill_chest(pos,tdata.relative_chest_position,tdata.treasure)
end,
})
end
for _,i in pairs(temples) do
	place_temple(i)
end

