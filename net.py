from flask import Flask
from flask import request
import os
import time
import requests

app = Flask(__name__)

queue = []
responses = {}

def _getChunk(hash):
    print(f"added hash {hash} to queue, waiting for response...")
    # Add hash to queue
    queue.insert(0,hash)
    # Wait for response
    while hash not in responses:
        time.sleep(0.1)

        # Add to responses, taken care of elsewhere
    print(f"got response for hash {hash}")
    return responses.pop(hash)

# For minetest mod to long poll
@app.route('/local/recieverequest')
def pollRequest():
    print("yielding until nonzero queue...")
    while queue == []:
        time.sleep(0.1)
    
    print("Found item in queue!")
    return queue.pop(0)

# For minetest mod to send request back
@app.route('/local/sendrequest',  methods=['POST'])
def sendRequest():
    print("Got post request...")
    data = request.json
    print(data)
    responses[data["hash"]] = data["blocks"]
    print(responses)
    return "OK"
    # return {"hash": chunkHash, "blocks": data["blocks"]}
    # return chunkHash

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
    chunksOut = {}
    for chunkHash in chunksIn:
        chunksOut[chunkHash] = _getChunk(chunkHash)
        
    return chunksOut

if __name__ == '__main__':
    app.run(port=8080,host="0.0.0.0")