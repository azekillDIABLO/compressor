local node = exeter.node
local breaker = exeter.breaker
local good_nodes = {}
local grassy = {}
local wall_nodes = {}

do
	local t = { "default:cobble" }
	for _, i in pairs(t) do
		wall_nodes[node(i)] = true
	end
end

local function clear_bd(plot_buf, plot_sz_x, dy, plot_sz_z)
	for k = 0, plot_sz_x + 1 do
		if not plot_buf[k] then
			plot_buf[k] = {}
		end
		for l = 0, dy do
			if not plot_buf[k][l] then
				plot_buf[k][l] = {}
			end
			for m = 0, plot_sz_z + 1 do
				plot_buf[k][l][m] = nil
			end
		end
	end
end


-- Create a table of biome ids, so I can use the biomemap.
if not exeter.biome_ids then
	local i
	exeter.biome_ids = {}
	for name, desc in pairs(minetest.registered_biomes) do
		i = minetest.get_biome_id(desc.name)
		exeter.biome_ids[i] = desc.name
	end
end

local tree_biomes = {}
tree_biomes["deciduous_forest"] = {"deciduous_trees"}
tree_biomes["coniferous_forest"] = {"conifer_trees"}
tree_biomes["rainforest"] = {"jungle_trees"}


local data = {}  -- vm data buffer
local p2data = {}  -- vm rotation data buffer
local plot_buf = {}  -- passed to functions to build houses/buildings in
local p2_buf = {}  -- passed to functions to store rotation data
local vm, emin, emax, a, csize, heightmap, biomemap
local div_sz_x, div_sz_z, minp, maxp


local function place_schematic(pos, schem)
	local yslice = {}
	if schem.yslice_prob then
		for _, ys in pairs(schem.yslice_prob) do
			yslice[ys.ypos] = ys.prob
		end
	end

	pos.x = pos.x - math.floor(schem.size.x / 2)
	pos.z = pos.z - math.floor(schem.size.z / 2)

	for z = 0, schem.size.z - 1 do
		for x = 0, schem.size.x - 1 do
			local ivm = a:index(pos.x + x, pos.y, pos.z + z)
			local isch = z * schem.size.y * schem.size.x + x + 1
			for y = 0, schem.size.y - 1 do
				if yslice[y] or 255 >= math.random(255) then
					local prob = schem.data[isch].prob or schem.data[isch].param1 or 255
					if prob >= math.random(255) then
						data[ivm] = node(schem.data[isch].name)
					end
				end
				ivm = ivm + a.ystride
				isch = isch + schem.size.x
			end
		end
	end
end


function exeter.generate(p_minp, p_maxp, seed)
	minp, maxp = p_minp, p_maxp
	vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
	local ivm = 0  -- vm data index
	a = VoxelArea:new({MinEdge = emin, MaxEdge = emax})
	csize = vector.add(vector.subtract(maxp, minp), 1)
	heightmap = minetest.get_mapgen_object("heightmap")
	biomemap = minetest.get_mapgen_object("biomemap")
	local build_min = 8
	local build_max = 16
	local wall_thick = 3
	local wall_height = 12
	local max_headroom = 4
	local road_width = 3
	local building_height = 8
	local buildings = {}
	local wilderness = false

	local function oor(x, z)
		if x > maxp.x or x < minp.x or z > maxp.z or z < minp.z then
			return true
		end
		return false
	end

	local function partition(plan, x1, z1)
		--
		if plan[x1][z1] then
			return
		end

		local x2 = x1 + math.random(build_min, build_max)
		if x2 > maxp.x then
			return
		end
		local xh
		for x = x1, x2 do
			if not xh and plan[x][z1] then
				if x - x1 < build_min then
					return
				else
					xh = x
				end
			end
		end
		if not xh then
			xh = x2
		end
		x2 = xh

		local z2 = z1 + math.random(build_min, build_max)
		if z2 > maxp.z then
			return
		end
		local zh
		for z = z1, z2 do
			for x = x1, x2 do
				if not zh and plan[x][z] then
					if z - z1 - 1 < build_min then
						return
					else
						zh = z - 1
					end
				end
			end
		end
		if not zh then
			zh = z2
		end
		z2 = zh

		for z = z1, z2 do
			for x = x1, x2 do
				if x == x1 or x == x2 or z == z1 or z == z2 then
					if plan[x][z] then
						print("wtf!?")
						return
					else
						plan[x][z] = "build"
					end
				else
					plan[x][z] = "interior"
				end
			end
		end
		buildings[#buildings+1] = {x1, x2, z1, z2}
	end

	local function build(coords)
		local x1, x2, z1, z2 = coords[1], coords[2], coords[3], coords[4]
		local min = 31000
		local index = 0
		local avg = 0
		for z = z1, z2 do
			for x = x1, x2 do
				index = (z - minp.z) * csize.x + (x - minp.x) + 1
				if heightmap[index] < min then
					min = heightmap[index]
				end
				avg = avg + heightmap[index]
			end
		end
		avg = math.floor(avg / ((z2 - z1 + 1) * (x2 - x1 + 1)) + 0.5)

		for z = z1, z2 do
			for x = x1, x2 do
				ivm = a:index(x, min, z)
				for y = min, avg + building_height do
					if x == x1 or x == x2 or z == z1 or z == z2 then
						data[ivm] = node("default:wood")
					elseif y < avg then
						data[ivm] = node("default:wood")
					else
						data[ivm] = node("air")
					end

					ivm = ivm + a.ystride
				end
			end
		end
	end


	-- Deal with memory issues. This, of course, is supposed to be automatic.
	local mem = math.floor(collectgarbage("count")/1024)
	if mem > 500 then
		print("Exeter is manually collecting garbage as memory use has exceeded 500K.")
		collectgarbage("collect")
	end

	-- This may fix problems with the generate function getting
	-- called twice and producing split buildings.
	-- The same buildings should be generated each time if we
	-- use the same seed (based on perlin noise).
	local seed_noise = minetest.get_perlin({offset = 0, scale = 32768,
	seed = 5202, spread = {x = 80, y = 80, z = 80}, octaves = 2,
	persist = 0.4, lacunarity = 2})
	math.randomseed(seed_noise:get2d({x=minp.x, y=minp.z}))

	local index = 0
	local alt = 0
	local count = 0
	local min = 31000
	local max = -31000
	local border = 6

	vm:get_data(data)
	p2data = vm:get_param2_data()

	for z = minp.z, maxp.z do
		for x = minp.x, maxp.x do
			index = index + 1
			-- One off values are likely to be errors.
			if heightmap[index] ~= minp.y - 1 and heightmap ~= maxp.y + 1 then
				-- Terrain going through minp.y or maxp.y causes problems,
				-- since there's no practical way to tell if you're above
				-- or below a city block.
				if heightmap[index] > maxp.y or heightmap[index] < minp.y then
					wilderness = true
				end

				if x == minp.x + (border + 1) or z == minp.z + (border + 1) or x == maxp.x - (border + 1) or z == maxp.z - (border + 1) then
					if heightmap[index] < min then
						min = heightmap[index]
					end
					if heightmap[index] > max then
						max = heightmap[index]
					end

					alt = alt + heightmap[index]
					count = count + 1
				end
			end
		end
	end

	-- Avoid steep terrain.
	if max - min > 20 then
		wilderness = true
	end

	-- If the average ground level is too high, there won't
	-- be enough room for any buildings.
	alt = math.floor((alt / count) + 0.5)
	if alt > minp.y + 67 or alt < 1 then
		wilderness = true
	end

	if wilderness then
		-- Plant the missing trees in the untamed wilderness.
		-- This is unbelievably slow.
		for dz = 0, csize.z - 5, 5 do
			for dx = 0, csize.x - 5, 5 do
				if math.random(2) == 1 then
					local x = minp.x + dx + math.random(5)
					local z = minp.z + dz + math.random(5)
					local y = heightmap[(z - minp.z) * csize.x + (x - minp.x) + 1]
					if y and y >= minp.y and y <= maxp.y then
						local ivm = a:index(x, y, z)
						if data[ivm + a.ystride] == node("air") and (data[ivm] == node("default:dirt") or data[ivm] == node("default:dirt_with_grass") or data[ivm] == node("default:dirt_with_snow")) then
							local index_2d = (z - minp.z) * csize.x + (x - minp.x) + 1
							local biome = exeter.biome_ids[biomemap[index_2d]]
							if tree_biomes[biome] and y >= minp.y and y <= maxp.y then
								local tree_type = tree_biomes[biome][math.random(#tree_biomes[biome])]
								local schem = exeter.schematics[tree_type][math.random(#exeter.schematics[tree_type])]
								local pos = {x=x, y=y, z=z}
								-- This is bull****. The schematic functions do not work.
								-- Place them programmatically since the lua api is ****ed.
								place_schematic(pos, schem)
							end
						end
					end
				end
			end
		end
	else
		-- divide the block into this many buildings
		local ivm_xn, ivm_xp, ivm_zn, ivm_zp  -- vm data indexes
		-- amount of border to clear, to avoid schematic bleed-over
		local bord_xn, bord_xp, bord_zn, bord_zp = border, border, border, border
		local city_xn, city_xp, city_zn, city_zp = false, false, false, false
		local gate_x = math.ceil(csize.z / 2) + minp.z
		local gate_z = math.ceil(csize.x / 2) + minp.x

		-- Border data is frequently incorrect. However, there's not
		-- really any other way to deal with these issues.
		for z = minp.z, maxp.z do
			local index_xn = (z - minp.z) * csize.x + 1
			local index_xp = (z - minp.z) * csize.x + csize.x
			local hn = heightmap[index_xn] - 4
			local hp = heightmap[index_xp] - 4
			local ivm_xn = a:index(minp.x - 1, hn, z)
			local ivm_xp = a:index(maxp.x + 1, hp, z)

			for y = math.min(hn, hp), maxp.y do
				if wall_nodes[data[ivm_xn]] then
					city_xn = true
					bord_xn = 0
				elseif wall_nodes[data[ivm_xp]] then
					city_xp = true
					bord_xp = 0
				end

				ivm_xn = ivm_xn + a.ystride
				ivm_xp = ivm_xp + a.ystride
			end
		end

		for x = minp.x, maxp.x do
			local index_zn = (x - minp.x) + 1
			local index_zp = (x - minp.x) + csize.z
			local hn = heightmap[index_zn] - 4
			local hp = heightmap[index_zp] - 4
			local ivm_zn = a:index(x, hn, minp.z - 1)
			local ivm_zp = a:index(x, hp, maxp.z + 1)

			for y = math.min(hn, hp), maxp.y do
				if wall_nodes[data[ivm_zn]] then
					city_zn = true
					bord_zn = 0
				elseif wall_nodes[data[ivm_zp]] then
					city_zp = true
					bord_zp = 0
				end

				ivm_zn = ivm_zn + a.ystride
				ivm_zp = ivm_zp + a.ystride
			end
		end

		local plan = {}
		for i = minp.x, maxp.x do
			if not plan[i] then
				plan[i] = {}
			end
		end

		local dx, dz, wall, river, river_depth, wall_border_x, wall_border_z
		index = 0
		for z = minp.z, maxp.z do
			for x = minp.x, maxp.x do
				index = index + 1
				dx = x - minp.x
				dz = z - minp.z
				wall = (not city_xn and x <= minp.x + wall_thick) or (not city_xp and x >= maxp.x - wall_thick) or (not city_zn and z <= minp.z + wall_thick) or (not city_zp and z >= maxp.z - wall_thick)
				wall_border_x = (x == minp.x and not city_xn) or (x == maxp.x and not city_xp)
				wall_border_z = (z == minp.z and not city_zn) or (z == maxp.z and not city_zp)
				river = false
				river_depth = 0

				ivm = a:index(x, minp.y, z)
				for y = minp.y, maxp.y + 15 do
					-- Clear the existing param2 data.
					p2data[ivm] = 0

					if y <= heightmap[index] and y > min - 5 then
						data[ivm] = node("default:dirt")
					elseif data[ivm] == node("default:river_water_source") then
						river = true
						plan[x][z] = "river"
						river_depth = river_depth + 1
					elseif data[ivm] == node("default:water_source") then
						plan[x][z] = "water"
					elseif river and y > heightmap[index] + river_depth + max_headroom and y < heightmap[index] + wall_height + river_depth + 1 + x % 2 and wall_border_z then
						data[ivm] = node("default:cobble")
					elseif river and y > heightmap[index] + river_depth + max_headroom and y < heightmap[index] + wall_height + river_depth + 1 + z % 2 and wall_border_x then
						data[ivm] = node("default:cobble")
					elseif river and y > heightmap[index] + river_depth + max_headroom and y < heightmap[index] + wall_height + river_depth and wall then
						data[ivm] = node("default:cobble")
					elseif not river and y < heightmap[index] + wall_height and wall then
						data[ivm] = node("default:cobble")
						plan[x][z] = "wall"
					elseif not river and y < heightmap[index] + wall_height + 1 + z % 2 and wall_border_x then
						data[ivm] = node("default:cobble")
						plan[x][z] = "wall"
					elseif not river and y < heightmap[index] + wall_height + 1 + x % 2 and wall_border_z then
						data[ivm] = node("default:cobble")
						plan[x][z] = "wall"
					elseif y > min - 5 then
						data[ivm] = node("air")
					end

					ivm = ivm + a.ystride
				end
			end
		end

		for z = minp.z, maxp.z do
			for x = minp.x, maxp.x do
				if plan[x][z] == "river" then
					for dz = -road_width, road_width do
						for dx = -road_width, road_width do
							if not oor(x + dx, z + dz) and (not plan[x + dx][z + dz] or plan[x + dx][z + dz] == "wall") then
								plan[x + dx][z + dz] = "road"
							end
						end
					end
				end
			end
		end

		local z = gate_x
		for x = minp.x, maxp.x do
			local zt = (gate_x - z) / (maxp.x - x)
			if math.abs(zt) > 0.5 then
				z = z + math.ceil(zt)
			else
				local rzn, rzp = 0, 0
				if z > minp.z + road_width + wall_thick then
					rzn = -1
				end
				if z < maxp.z - road_width - wall_thick then
					rzp = 1
				end
				local zr = math.random(rzn, rzp)
				z = z + zr
			end

			local rw = math.floor(road_width / 2)
			for dx = -rw, rw do
				for dz = -rw, rw do
					if not oor(x + dx, z + dz) and (not plan[x + dx][z + dz] or plan[x + dx][z + dz] == "wall") then
						plan[x + dx][z + dz] = "road"
					end
				end
			end
		end

		local x = gate_z
		for z = minp.z, maxp.z do
			local xt = (gate_z - x) / (maxp.z - z)
			if math.abs(xt) > 0.5 then
				x = x + math.ceil(xt)
			else
				local rxn, rxp = 0, 0
				if x > minp.x + road_width + wall_thick then
					rxn = -1
				end
				if x < maxp.x - road_width - wall_thick then
					rxp = 1
				end
				local xr = math.random(rxn, rxp)
				x = x + xr
			end

			local rw = math.floor(road_width / 2)
			for dx = -rw, rw do
				for dz = -rw, rw do
					if not oor(x + dx, z + dz) and (not plan[x + dx][z + dz] or plan[x + dx][z + dz] == "wall") then
						plan[x + dx][z + dz] = "road"
					end
				end
			end
		end

		local b_range_x = csize.x - (city_xn and wall_thick or 0) - (city_xp and wall_thick or 0) - build_min
		local b_range_z = csize.z - (city_zn and wall_thick or 0) - (city_zp and wall_thick or 0) - build_min
		for ct = 1, 1000 do
			partition(plan, math.random(b_range_x) + (city_xn and wall_thick or 0) + minp.x, math.random(b_range_z) + (city_zn and wall_thick or 0) + minp.z)
		end


		for z = minp.z, maxp.z do
			for x = minp.x, maxp.x do
				if not plan[x][z] then
					plan[x][z] = "grass"
				end
			end
		end

		index = 0
		for z = minp.z, maxp.z do
			for x = minp.x, maxp.x do
				index = index + 1

				if plan[x][z] == "road" then
					ivm = a:index(x, minp.y, z)
					for y = minp.y, maxp.y + 15 do
						if y == heightmap[index] then
							data[ivm] = node("default:cobble")
						elseif y > heightmap[index] and y < heightmap[index] + max_headroom then
							data[ivm] = node("air")
						end

						ivm = ivm + a.ystride
					end
				elseif plan[x][z] == "build" then
				elseif plan[x][z] == "grass" then
					ivm = a:index(x, heightmap[index], z)
					data[ivm] = node("default:dirt_with_grass")
				end
			end
		end

		for _, c in pairs(buildings) do
			build(c)
		end

		--if exeter.desolation > 0 then
		--	for z = minp.z - bord_zn, maxp.z + bord_zp do
		--		for x = minp.x - bord_xn, maxp.x + bord_xp do
		--			ivm = a:index(x, minp.y, z)
		--			for y = minp.y, maxp.y do
		--				if grassy[data[ivm]] and data[ivm+a.ystride] == node("air") and math.random(5) == 1 then
		--					data[ivm+a.ystride] = node("default:grass_"..math.random(3))
		--				elseif good_nodes[data[ivm]] and data[ivm] ~= node("exeter:road_broken") and data[ivm+a.ystride] == node("air") and math.random(20) == 1 then
		--					data[ivm+a.ystride] = node("exeter:small_rocks"..math.random(6))
		--					p2data[ivm+a.ystride] = math.random(4) - 1
		--				end
		--				ivm = ivm + a.ystride
		--			end
		--		end
		--	end
		--end
	end

	vm:set_data(data)
	vm:set_param2_data(p2data)
	vm:set_lighting({day = 0, night = 0})
	vm:calc_lighting()
	vm:update_liquids()
	vm:write_to_map()
end
