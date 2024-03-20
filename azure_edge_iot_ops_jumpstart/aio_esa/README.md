Run locally

1. First download sample videos under **samples** folder
1. Create RTSP feed base on sample video
    ```bash
    docker run -p 554:8554 -e SOURCE_URL=file:///samples/bolt-detection.mp4 -v C:\\Users\\lakshitdabas\\Downloads\\samples:/samples -d --restart=always kerberos/virtual-rtsp:1.0.6
    ```
1. Using VLC, check that the RTSP is working (Media -> Open Network Stream -> Use the following RTSP: rtsp://127.0.0.1:554/stream)
1. Install the Python3
1. Using the `requirements.txt` file, install the Python requirements using `pip`
    ```bash
    pip install -r requirements.txt
    ```
1. Run the `main.py`
    ```bash
    python .\main.py
    ```
1. Open the browser and navigate to the Flask URL -> Generally this is the http://localhost:8000
1. If you want to run it with Docker, first build the container
    ```bash
    cd artifacts\esa_ai
    docker build -t esa-webserver .
    ```
1. Run the container
    ```bash
    docker run -p 8000:8000 -e RTSP_URL=rtsp://192.168.50.216:554/stream -e LOCAL_STORAGE=/tmp -e INFERENCE_CLASS_DETECTION="hola" -e CLASS_NAMES="bottle, person, cup, fork, knife" -d --restart=always esa-webserver
    ```