local ie = minetest.request_insecure_environment()
local http = minetest.request_http_api()
local currPath = "/home/ubuntu/.minetest/mods/rblx_chunkgen"

print("started chunkgen bridge")

--[[
    We can create an array that has all of the pending chunk requests, scoped outside of getChunk.
    If every item of the current bulk request is in the array, we can send the request.
    Otherwise, don't send the callback.

    Wait, even easier. We have an array in the GET method. We then modify the callback to add to the array,
    for all but the last chunk that needs to be generated. The callback for the last chunk will add the item,
    but then send *every* chunk as a poll request.

    Problem: Because getting chunks is async, we can't guarantee that the last chunk will be the last one *generated*
    Solution: We can use a counter to count the number of chunks that have been generated, and then send the request
    when the counter is equal to the number of chunks in the bulk request.

    So essentially just check the length of the array in every callback.
]]

local function getChunk(x, y, callback)
    print("Running getChunk!")
    local chunkData = {}
    if (not x) or (not y) then
        minetest.log("Tried to get chunk with nil x or y!")
        return
    end
    local pos_min = vector.new(x * 16, 0, y * 16)
    local pos_max = vector.new(x * 16 + 15, 256, y * 16 + 15)

    local iters = 0
    local function runGetChunkThing()
        iters = iters + 1

        if iters < 17 then
            return
        end
        minetest.log("Iterations: "..iters)

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
                            local blockData = {x=x, y=y, z=z, t=blockType:gsub("default:", "")}
                            table.insert(chunkData, blockData)
                        end
                    end
                end
            end
        end
        callback(chunkData)
        end
    minetest.emerge_area(pos_min, pos_max, runGetChunkThing)
end

local function getBulkChunks(bulkId, hashes)
    local chunks = {}
    local length = #hashes
    local currLength = 0

    for _, hash in ipairs(hashes) do
        local x = tonumber(split(hash, ",")[1])
        local y = tonumber(split(hash, ",")[2])
        getChunk(x,y,function(blocks)
            chunks[hash] = blocks
            minetest.log("callback responded...")
            currLength = currLength + 1
            if (length == currLength) then
                minetest.log("At desired length, sending post...")
                local POSTRequest = {
                    url="http://localhost:8080/local/sendrequest",
                    timeout = 10,
                    method = "POST",
                    data = minetest.write_json({type="bulk", bulkId=bulkId, hash=hash, blocks=blocks}),
                    extra_headers = {"Content-Type: application/json"}
                }
                minetest.log("[Callback] BULK Chunk data grabbed, sending POST back to server.")
                http.fetch(POSTRequest, function(ret)
                    minetest.log("POST returned!")
                end)
            end
        end)
    end
end

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

local openThreads = 0
local pollThreadCount = 1
local function checkRequests()
    if (openThreads >= pollThreadCount ) then
        return
    end
    openThreads = openThreads + 1
    minetest.log("Checking requests...")
    -- Use Long Poll to wait for hash, then do request
    local GETRequest = {
        url="http://localhost:8080/local/recieverequest?id="..openThreads.."&maxThreads="..pollThreadCount,
        timeout = 1000000000000,
        method = "GET",
    }
    minetest.log("Sending GET...")
    http.fetch(GETRequest, function(data)
        minetest.log("GET returned!")
        local hash = data["data"]
        minetest.log("data: ")
        minetest.log(dump(data))

        if (data["timeout"]) then
            -- For some reason the request timed out, so we should just try again.
            minetest.log("Request timed out, trying again.")
            openThreads = openThreads - 1
            return
        end

        local isbulk = true

        local x = tonumber(split(hash, ",")[1])
        local y = tonumber(split(hash, ",")[2])
        if type(minetest.parse_json(data["data"])) == "number" then
            isbulk = false
        end
        -- 
        if (not isbulk) then
            minetest.log("bulkId is nil, sending chunk request.")
            getChunk(x,y,function(blocks)
                local POSTRequest = {
                    url="http://localhost:8080/local/sendrequest",
                    timeout = 1000000000000,
                    method = "POST",
                    data = minetest.write_json({type="chunk", hash=hash, blocks=blocks}),
                    extra_headers = {"Content-Type: application/json"}
                }
                minetest.log("[Callback] Chunk data grabbed, sending POST back to server.")
                http.fetch(POSTRequest, function(ret)
                    minetest.log("POST returned!")
                end)
                minetest.log("sent post request!")
            end)
        else
            if (minetest.parse_json(data["data"])) then
                local bulkId = minetest.parse_json(data["data"])["bulkId"]
                minetest.log("bulkId is not nil, sending bulk chunk request.")
                getBulkChunks(bulkId, minetest.parse_json(data["data"])["chunks"])
            end
        end
        openThreads = openThreads - 1
    end)
end

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

local stepBuffer = 1
local current = 0
minetest.register_globalstep(function()
    if ((current % stepBuffer) == 0) then
        checkRequests()
        current = 0
    end
    current = current + 1
end)