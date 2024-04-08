# Use an official Python runtime as a parent image
FROM python:3.8-slim-buster

# Set the working directory to /app
WORKDIR /app

# Install necessary dependencies
USER root
RUN apt-get update --fix-missing && \
    apt-get install -y python3-opencv && \
    rm -rf /var/lib/apt/lists/*

# Copy the current directory contents into the container at /app
COPY . /app

# Install any needed packages specified in requirements.txt
RUN pip install -r requirements.txt

#Install torch and torchvision CPU only versions
RUN pip3 install torch==1.8.0+cpu torchvision==0.9.0+cpu -f https://download.pytorch.org/whl/cpu/torch_stable.html

# Make port 80 available to the world outside this container
EXPOSE 8000

# Run main.py when the container launches
CMD ["python", "main.py"]

