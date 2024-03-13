# Original code taken from: https://gist.github.com/raiever/df5b6c48217df521094cbe2d12c32c66
# import the necessary packages
from flask import Response, Flask, render_template, jsonify
import threading
import argparse 
import datetime, time
import cv2
import os
import time
import math

from ultralytics import YOLO
model = YOLO("yolo-Weights/yolov8n.pt")

classNames = classNames = os.environ.get('CLASS_NAMES').split(',')
print("Class names read from CLASS_NAMES variable: ", classNames)

source = "rtsp://127.0.0.1:554/stream"
if 'RTSP_URL' in os.environ:
    source = os.environ.get('RTSP_URL')
print("Incoming video feed read from RTSP_URL: ", source)

esa_storage = "/home/aksedge-user/"
if 'LOCAL_STORAGE' in os.environ:
    esa_storage = os.environ.get('LOCAL_STORAGE')
print("Storing video frames read from LOCAL_STORAGE: ", esa_storage)

inference_class_detection = "handbag"
if 'INFERENCE_CLASS_DETECTION' in os.environ:
    inference_class_detection = os.environ.get('INFERENCE_CLASS_DETECTION')
print("Looking for frames read from INFERENCE_CLASS_DETECTION with: ", inference_class_detection)

# initialize the output frame and a lock used to ensure thread-safe
# exchanges of the output frames (useful when multiple browsers/tabs are viewing the stream)
outputFrame = None
lock = threading.Lock()
 
# initialize a flask object
app = Flask(__name__)
 
cap = cv2.VideoCapture(source)
time.sleep(2.0)

@app.route("/")
def index():
    # return the rendered template
    return render_template("index.html")

def stream(frameCount):
    global outputFrame, lock
    if cap.isOpened():
        count = 0
        while True:
            ret_val, frame = cap.read()
            if not None and frame.shape:
                if count % 3 != 2:
                    frame = cv2.resize(frame, (640,360))
                    with lock:
                        outputFrame = frame.copy()
                count += 1
            else:
                continue 
    else:
        print('Camera open failed')

def generate():
    # grab global references to the output frame and lock variables
    global outputFrame, lock
 
    # loop over frames from the output stream
    while True:
        with lock:
            # check if the output frame is available, otherwise skip
            # the iteration of the loop
            if outputFrame is None:
                continue
 
            results = model(outputFrame, stream=True)

            contains_class = False

            # coordinates
            for r in results:
                boxes = r.boxes

                for box in boxes:
                    # bounding box
                    x1, y1, x2, y2 = box.xyxy[0]
                    x1, y1, x2, y2 = int(x1), int(y1), int(x2), int(y2) # convert to int values

                    # put box in cam
                    cv2.rectangle(outputFrame, (x1, y1), (x2, y2), (139, 163, 255), 2)

                    # confidence
                    confidence = math.ceil((box.conf[0]*100))/100

                    # class name
                    cls = int(box.cls[0])
                    
                    if(confidence > 0.6 and classNames[cls] == inference_class_detection):
                        contains_class = True

                    # object detailscla
                    org = [x1, y1]
                    font = cv2.FONT_HERSHEY_SIMPLEX
                    fontScale = 1
                    color = (255, 0, 0)
                    thickness = 2

                    cv2.putText(outputFrame, classNames[cls], org, font, fontScale, color, thickness)

            # encode the frame in JPEG format
            (flag, encodedImage) = cv2.imencode(".jpg", outputFrame)

            if contains_class:
                store_jpg_frame(encodedImage)
 
            # ensure the frame was successfully encoded
            if not flag:
                continue
 
        # yield the output frame in the byte format
        yield(b'--frame\r\n' b'Content-Type: image/jpeg\r\n\r\n' + bytearray(encodedImage) + b'\r\n')

def store_jpg_frame(frame_data):
    current_time = datetime.datetime.now()
    file_name = current_time.strftime("%Y-%m-%d_%H-%M-%S")
    file_name = file_name + ".jpg"
    with open(f"{esa_storage}/{file_name}", "wb") as f:
        f.write(frame_data)

@app.route("/video_feed")
def video_feed():
    # return the response generated along with the specific media
    # type (mime type)
    return Response(generate(), mimetype = "multipart/x-mixed-replace; boundary=frame")

@app.route('/data')
def data():
    files = []
    for filename in os.listdir(esa_storage):
        file_path = os.path.join(esa_storage, filename)
        if os.path.isfile(file_path):
            size = os.path.getsize(file_path)
            modified = os.path.getmtime(file_path)
            files.append({'name': filename, 'size': size, 'modified': modified})
    files.sort(key=lambda f: f['modified'], reverse=True)
    return jsonify({'files': files})

# check to see if this is the main thread of execution
if __name__ == '__main__':
    # construct the argument parser and parse command line arguments
    ap = argparse.ArgumentParser()
    ap.add_argument("-i", "--ip", type=str, required=False, default='0.0.0.0',
        help="ip address of the device")
    ap.add_argument("-o", "--port", type=int, required=False, default=8000, 
        help="ephemeral port number of the server (1024 to 65535)")
    ap.add_argument("-f", "--frame-count", type=int, default=32,
        help="# of frames used to construct the background model")
    args = vars(ap.parse_args())

    t = threading.Thread(target=stream, args=(args["frame_count"],))
    t.daemon = True
    t.start()
 
    # start the flask app
    app.run(host=args["ip"], port=args["port"], debug=True,
        threaded=True, use_reloader=False)
 
# release the video stream pointer
cap.release()
cv2.destroyAllWindows()