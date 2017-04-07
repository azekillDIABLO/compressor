-- Check for necessary mod functions and abort if they aren't available.
if not minetest.get_biome_id then
	minetest.log()
	minetest.log("* Not loading Exeter *")
	minetest.log("Exeter requires mod functions which are")
	minetest.log(" not exposed by your Minetest build.")
	minetest.log()
	return
end

exeter = {}
exeter.version = "1.0"

exeter.path = minetest.get_modpath("exeter")
exeter.vacancies = tonumber(minetest.setting_get('exeter_vacancies')) or 0
if exeter.vacancies < 0 or exeter.vacancies > 10 then
	exeter.vacancies = 0
end
exeter.divisions_x = tonumber(minetest.setting_get('exeter_divisions_x')) or 3
if exeter.divisions_x < 0 or exeter.divisions_x > 4 then
	exeter.divisions_x = 3
end
exeter.divisions_z = tonumber(minetest.setting_get('exeter_divisions_z')) or 3
if exeter.divisions_z < 0 or exeter.divisions_z > 4 then
	exeter.divisions_z = 3
end
exeter.desolation = tonumber(minetest.setting_get('exeter_desolation')) or 0
if exeter.desolation < 0 or exeter.desolation > 10 then
	exeter.desolation = 0
end
exeter.suburbs = tonumber(minetest.setting_get('exeter_suburbs')) or 3
if exeter.suburbs < 0 or exeter.suburbs > 10 then
	exeter.suburbs = 3
end

-- Modify a node to add a group
function minetest.add_group(node, groups)
	local def = minetest.registered_items[node]
	if not def then
		return false
	end
	local def_groups = def.groups or {}
	for group, value in pairs(groups) do
		if value ~= 0 then
			def_groups[group] = value
		else
			def_groups[group] = nil
		end
	end
	minetest.override_item(node, {groups = def_groups})
	return true
end

function exeter.clone_node(name)
	local node = minetest.registered_nodes[name]
	local node2 = table.copy(node)
	return node2
end

function exeter.node(name)
	if not exeter.node_cache then
		exeter.node_cache = {}
	end

	if not exeter.node_cache[name] then
		exeter.node_cache[name] = minetest.get_content_id(name)
		--print("*** "..name..": "..exeter.node_cache[name])
		if name ~= "ignore" and exeter.node_cache[name] == 127 then
			print("*** Failure to find node: "..name)
		end
	end

	return exeter.node_cache[name]
end

function exeter.breaker(node)
	local sr = math.random(50)
	if sr <= exeter.desolation then
		return "air"
	elseif exeter.desolation > 0 and sr / 5 <= exeter.desolation then
		return string.gsub(node, ".*:", "exeter:").."_broken"
	else
		return node
	end
end


dofile(exeter.path .. "/nodes.lua")
dofile(exeter.path .. "/deco.lua")
dofile(exeter.path .. "/deco_rocks.lua")
dofile(exeter.path .. "/mapgen.lua")
--dofile(exeter.path .. "/buildings.lua")
--dofile(exeter.path .. "/houses.lua")

exeter.players_to_check = {}

function exeter.respawn(player)
	exeter.players_to_check[#exeter.players_to_check+1] = player:get_player_name()
end

function exeter.unearth(dtime)
	for i, player_name in pairs(exeter.players_to_check) do
		local player = minetest.get_player_by_name(player_name)
		if not player then
			return
		end
		local pos = player:getpos()
		if not pos then
			return
		end
		local count = 0
		local node = minetest.get_node_or_nil(pos)
		while node do
			if node.name == 'air' then
				player:setpos(pos)
				table.remove(exeter.players_to_check, i)
				if count > 1 then
					print("*** Exeter unearthed "..player_name.." from "..count.." meters below.")
				end
				return
			elseif node.name == "ignore" then
				return
			else
				pos.y = pos.y + 1
				count = count + 1
			end
			node = minetest.get_node_or_nil(pos)
			end
	end
end

minetest.register_on_newplayer(exeter.respawn)
minetest.register_on_respawnplayer(exeter.respawn)
minetest.register_on_generated(exeter.generate)
minetest.register_globalstep(exeter.unearth)
