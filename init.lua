local ie = minetest.request_insecure_environment()
ie.package.path = ie.package.path .. ";/home/eric/.luarocks/share/lua/5.1/?.lua;/home/eric/.luarocks/share/lua/5.1/?/init.lua"
ie.package.cpath = ie.package.cpath .. ";/home/eric/.luarocks/lib64/lua/5.1/?.so"

local request = ie.require("http.request")
local pegasus = ie.require('pegasus')

local function getChunk(x, y, callback)
    minetest.log("running from getchunk")
    local chunkData = {}

    local pos_min = vector.new(x * 16, 0, y * 16)
    local pos_max = vector.new(x * 16 + 15, 256, y * 16 + 15)

    local len = 0

    local iters = 0
    local function runGetChunkThing()
        iters = iters + 1
        minetest.log("Running callback: " .. iters)

        if iters < 17 then
            return
        end

        local voxelmanip = minetest.get_voxel_manip(pos_min, pos_max)
        local emin, emax = voxelmanip:read_from_map(pos_min, pos_max)
        local area = VoxelArea:new{ MinEdge = emin, MaxEdge = emax }
        local data = voxelmanip:get_data()

        for z = pos_min.z, pos_max.z do
            for y = pos_min.y, pos_max.y do
                for x = pos_min.x, pos_max.x do
                    local blockType = minetest.get_name_from_content_id(data[area:index(x, y, z)])
                    if not (blockType == "air") then
                        local blockData = {x=x, y=y, z=z, bType=blockType}
                        local blockHash = x..","..y..","..z
                        chunkData[blockHash] = blockData
                        len = len + 1
                    end
                end
            end
        end
        minetest.log("Running callback for response")
        callback()
    end
    minetest.emerge_area(pos_min, pos_max, runGetChunkThing)
end

minetest.register_chatcommand("cc", {
    privs = {
        interact = true,
    },
    func = function(name, param)
        local player = minetest.get_player_by_name(name)
        local pos = player:get_pos()
        -- getChunk(math.floor(pos.x / 16), math.floor(pos.z / 16))
        getChunk(1000, 1000, function() minetest.log("called!") end)
    end,
})

minetest.register_chatcommand("host", {
    privs = {
        interact = true,
    },
    func = function(name, param)
        
        
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