# Minetest mod/webserver for use in Roblox block mechanics

# Installing
Install packages using
```
luarocks --lua-version 5.1 LUA_INCDIR="/home/eric/.minetest/mods/minetest_rblx_chunkgen/lua" install LuaSocket
```
# About
If you are navigating to this project directly, I highly recommend you check out [https://github.com/EricApostal/block-mechanics](https://github.com/EricApostal/block-mechanics), as it provides context for the problem this project solves.

This project aims to provide a webserver for use to take chunk generation from Minetest for use in a Roblox game. This allows for increased performance, as well as more advanced terrain generation. 

# How it works
![image](https://github.com/EricApostal/minetest-rblx-chunkgen/assets/60072374/d44086f9-8851-4086-8ae3-377db924c95a)

The nature of this project is deceivingly complex, due to the single-threaded nature of Minetest's modding API. There are two components to this project; the Flask webserver, and the Minetest mod. The Minetest mod is constantly HTTP long polling the Flask webserver for new updates from the Roblox game. Whenever one is received, it's added to the queue, which is then returned to the thread that is actively long polling. This is then returned back to the game server, which is able to replicate the chunk data to the client.

If I were to reapproach this project (which I likely will, since it's pretty cool), I'd likely directly take out the chunk generation, instead of setting up a mod. While this is (surprisingly) performant, there is still inherent overhead, and the single-threaded nature of the Lua runtime limits the max amount of servers that could run it. This example does have the capability to handle multiple requests at once via `maxThreads`, however, it's broken due to the Lua interpreter lock. Interfacing with the C++ library directly would allow for this extensibility, and would simplify the network pipeline. 
