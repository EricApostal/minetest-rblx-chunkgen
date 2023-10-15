minetest.log("Started!")

local function getChunk(x, y)
    local chunkData = {}

    local min = vector.new(x * 16, 0, y * 16)
    local max = vector.new(x * 16 + 15, 256, y * 16 + 15)

    local vm =  minetest.get_mapgen_object("voxelmanip")
    local emin, emax = vm:read_from_map(min, max)
    local area = VoxelArea:new{ MinEdge = emin, MaxEdge = emax }
    local data = vm:get_data()

    for z = min.z, max.z do
        for y = min.y, max.y do
            for x = min.x, max.x do
                local vi = area:index(x, y, z)
                minetest.log(data[vi])
            end
        end
    end
end

minetest.register_chatcommand("cc", {
    privs = {
        interact = true,
    },
    func = function(name, param)
        local player = minetest.get_player_by_name(name)
        local pos = player:get_pos()
        -- getChunk(math.floor(pos.x / 16), math.floor(pos.z / 16))
        getChunk(math.floor(1000), math.floor(1000))
    end,
})

minetest.register_chatcommand("pos", {
    privs = {
        interact = true,
    },
    func = function(name, param)
        local player = minetest.get_player_by_name(name)
        local pos = player:get_pos()
        minetest.log(dump(pos))
    end,
})