-- local ie = minetest.request_insecure_environment()
-- ie.package.path = ie.package.path .. ";/home/eric/.luarocks/share/lua/5.1/?.lua;/home/eric/.luarocks/share/lua/5.1/?/init.lua"
-- ie.package.cpath = ie.package.cpath .. ";/home/eric/.luarocks/lib64/lua/5.1/?.so"

-- local request = ie.require("http.request")
-- local pegasus = ie.require('pegasus')
-- local currPath = "/home/eric/.minetest/mods/minetest_rblx_chunkgen"
local currPath = "/home/ubuntu/.minetest/mods/minetest_rblx_chunkgen"

local function getChunk(x, y, callback)
    local chunkData = {}

    local pos_min = vector.new(x * 16, 0, y * 16)
    local pos_max = vector.new(x * 16 + 15, 256, y * 16 + 15)

    local len = 0

    local iters = 0
    local function runGetChunkThing()
        iters = iters + 1

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
                    if (data[area:index(x, y, z)] == nil) then
                        minetest.log("Tried to index nil block position!")
                    else
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
        end
        callback(chunkData)
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

function split(inputstr, sep)
    if sep == nil then
        sep = "%s"
    end
    local t={}
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
        table.insert(t, str)
    end
    return t
end

local function checkRequests()
    local _pending = io.popen("ls -pa "..currPath.."/requests".. "| grep -v /")
    if _pending == nil then
        return
    end
    local pending = _pending:lines()
    for file in pending do
        local split = split(file:gsub(".txt",""), ",")
        local x = tonumber(split[1])
        local y = tonumber(split[2])
        getChunk(x,y,function(chunkData)
            file = io.open(currPath.."/responses/"..split[1]..","..split[2]..".txt", "w")
            io.output(file)
            io.write(minetest.write_json(chunkData))
            io.close(file)
            os.remove(currPath.."/requests/"..split[1]..","..split[2]..".txt")
        end)
    end
end

minetest.register_chatcommand("host", {
    privs = {
        interact = true,
    },
    func = function(name, param)
        os.execute("mkdir "..currPath.."/requests")
        os.execute("mkdir "..currPath.."/responses")
        checkRequests()
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

minetest.register_globalstep(function()
    checkRequests()
end)
