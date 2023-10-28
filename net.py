from flask import Flask
from flask import request
import os
import time
import requests
import random
import uuid

app = Flask(__name__)

queue = []
activeThreads = []
currentThread = -1
responses = {}

def _getChunk(hash):
    print(f"added hash {hash} to queue, waiting for response...")
    queue.insert(0,hash)
    while hash not in responses:
        time.sleep(0.01)

    print(f"got response for hash {hash}")
    return responses.pop(hash)

def _getChunkGroup(bulkId, chunks):
    print(f"added chunk group to queue, waiting for response...")
    chunkData = {"bulkId":bulkId, "blocks":chunks}
    queue.insert(0,chunkData)
    while not responses[bulkId]:
        time.sleep(0.01)
        
    return responses.pop(bulkId)

# For minetest mod to long poll
@app.route('/local/recieverequest')
def pollRequest():
    global currentThread

    id = request.args.get("id")
    print(f"new thread with id {id}")
    maxThreads = int(request.args.get("maxThreads"))
    activeThreads.insert(0, id)
    if currentThread == -1:
        currentThread = activeThreads[0]

    while (queue == []) or (currentThread != id):
        time.sleep(0)
    

    activeThreads.remove(id)
    currentThread = currentThread[len(currentThread)-1] 
    print("Found item in queue, it is being served!")
    print("new thread: ")
    print(currentThread)
    return queue.pop(0)

# For minetest mod to send request back
@app.route('/local/sendrequest',  methods=['POST'])
def sendRequest():
    print("Got post request...")
    data = request.json
    print("PACKET TYPE: ")
    print(data["type"])
    if data["type"] == "chunk":
        responses[data["hash"]] = data["blocks"]
    else:
        responses[data["bulkId"]] = data
    return "OK"

@app.route('/chunk')
def getChunk():
    x = request.args.get('x')
    y = request.args.get('y')
    if x == None or y == None:
        return "Invalid URL params"

    return _getChunk(x+","+y)

@app.route('/chunkgroup')
def getChunkGroup():
    chunksIn = request.args.getlist("chunk")    
    key = uuid.uuid4()
    return _getChunkGroup(key, chunksIn)

if __name__ == '__main__':
    app.run(port=8080,host="0.0.0.0")