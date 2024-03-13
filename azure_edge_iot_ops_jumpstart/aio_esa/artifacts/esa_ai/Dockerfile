# Use an official Python runtime as a parent image
FROM python:3.8-slim-buster

# Set the working directory to /app
WORKDIR /app

RUN apt-get update --fix-missing
RUN apt-get install python3-opencv -y

# Copy the current directory contents into the container at /app
COPY . /app

# Install any needed packages specified in requirements.txt
RUN pip install -r requirements.txt

#Install torch and torchvision CPU only versions
RUN pip3 install torch==1.8.0+cpu torchvision==0.9.0+cpu -f https://download.pytorch.org/whl/cpu/torch_stable.html

#Explicitly install ultralytics without optional dependencies (like CUDA).
RUN pip3 install ultralytics==8.0.200 --no-deps

# Make port 80 available to the world outside this container
EXPOSE 8000

# Run main.py when the container launches
CMD ["python", "main.py"]