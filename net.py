from flask import Flask
from flask import request
import os
import time
import requests

app = Flask(__name__)

@app.route('/')
def getChunk():
    x = request.args.get('x')
    y = request.args.get('y')
    if x == None or y == None:
        return "Invalid URL params"

    filename = f"{x},{y}.txt"

    f = open(f"requests/{filename}", "w")
    f.write("")
    f.close()
    
    print("Waiting for chunk gen")
    while not os.path.isfile(f"responses/{filename}"):
        time.sleep(0.1)

    print("Chunk gen happened!")
    fileContent = open(f'responses/{filename}').read()
    os.remove(f"responses/{filename}")
    return fileContent


if __name__ == '__main__':
    app.run()