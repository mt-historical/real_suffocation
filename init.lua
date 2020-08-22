-- Load setting
local suffocation_damage = tonumber(minetest.settings:get("real_suffocation_damage")) or 10

local function is_truthy(val)
	return val ~= nil and val ~= false and val ~= 0 and val ~= ""
end

local function should_suffocate(def)
--[[ Here comes the HUGE conditional deciding whether we use suffocation. We want to catch as many nodes as possible
while avoiding bad nodes. We care mostly about physical properties, we don't care about visual appearance.
Here's what it checks and why:
- Walkable: Must be walkable, which means player can get stuck inside. If player can move freely, suffocation does not make sense
- Drowning and damage: If node has set any of those explicitly, it probably knows why. We don't want to mess with it.
- collision_box, node_box: Checks whether we deal with full-sized standard cubes, since only care about those.
	Everything else is probably too small for suffocation to seem real.
- disable_suffocation group: If set to 1, we bail out. This makes it possible for nodes to defend themselves against hacking. :-)
]]
	local groups = def.groups or {}
	return (def.walkable == nil or def.walkable == true)
		and (def.drowning == nil or def.drowning == 0)
		and (def.damage_per_second == nil or def.damage_per_second <= 0)
		and (def.collision_box == nil or def.collision_box.type == "regular")
		and (def.node_box == nil or def.node_box.type == "regular")
		and not is_truthy(groups.disable_suffocation)
		and not is_truthy(groups.door)
end

-- Checks all nodes and adds suffocation (drowning damage) for suitable nodes
local function add_suffocation()
	-- For debugging output
	local suffocate_nodes = {}
	local no_suffocate_nodes = {}
	-- Check ALL the nodes!
	for itemstring, def in pairs(minetest.registered_nodes) do
		if should_suffocate(def) then
			-- Add “real_suffocation” group so other mods know this node was touched by this mod
			local marked_groups = table.copy(def.groups)
			marked_groups.real_suffocation = 1
			-- Let's hack the node!
			minetest.override_item(itemstring, { drowning = suffocation_damage, groups = marked_groups })
			table.insert(suffocate_nodes, itemstring)
		else
			table.insert(no_suffocate_nodes, itemstring)
		end
	end
	minetest.log("info", "[real_suffocation] Suffocation has been hacked into "..#suffocate_nodes.." nodes.")
	minetest.log("verbose", "[real_suffocation] Nodes with suffocation: "..dump(suffocate_nodes))
	minetest.log("verbose", "[real_suffocation] Suffocation has not been hacked into "..#no_suffocate_nodes.." nodes: "..dump(no_suffocate_nodes))
end

-- Skip the rest if suffocation damage is 0, no point in overwriting stuff
if suffocation_damage > 0 then
	-- This is a minor hack to make sure our loop runs after all nodes have been registered
	minetest.after(0, add_suffocation)
end
