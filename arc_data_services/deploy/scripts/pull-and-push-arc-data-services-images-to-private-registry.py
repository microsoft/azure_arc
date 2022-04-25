#This version of the script is for the "new" platform version in the July release

# requires installation of Docker: https://docs.docker.com/install/

from subprocess import check_output, CalledProcessError, STDOUT, Popen, PIPE
import os
import getpass

def execute_cmd (cmd):
    if os.name=="nt":
        process = Popen(cmd.split(),stdin=PIPE, shell=True)
    else:
        process = Popen(cmd.split(),stdin=PIPE)
    stdout, stderr = process.communicate()
    if (stderr is not None):
        raise Exception(stderr)

if (os.getenv("SOURCE_DOCKER_REGISTRY") is None):
    SOURCE_DOCKER_REGISTRY = input("Provide source container registry - press ENTER for using `mcr.microsoft.com`:") or "mcr.microsoft.com"
else:
    SOURCE_DOCKER_REGISTRY = os.environ["SOURCE_DOCKER_REGISTRY"]

if (os.getenv("SOURCE_DOCKER_REPOSITORY") is None):
    SOURCE_DOCKER_REPOSITORY = input("Provide source container registry repository - press ENTER for using `arcdata`:") or "arcdata"
else:
    SOURCE_DOCKER_REPOSITORY = os.environ["SOURCE_DOCKER_REPOSITORY"]

if (os.getenv("SOURCE_DOCKER_USERNAME") is None):
    SOURCE_DOCKER_USERNAME = input("Provide username for the source container registry - press ENTER for using none:")
else:
    SOURCE_DOCKER_USERNAME = os.environ["SOURCE_DOCKER_USERNAME"]

if (os.getenv("SOURCE_DOCKER_PASSWORD") is None):
    SOURCE_DOCKER_PASSWORD=getpass.getpass("Provide password for the source container registry - press ENTER for using none:")
else:
    SOURCE_DOCKER_PASSWORD = os.environ["SOURCE_DOCKER_PASSWORD"]

if (os.getenv("SOURCE_DOCKER_TAG") is None):
    SOURCE_DOCKER_TAG = input("Provide container image tag for the images at the source - press ENTER for using 'v1.5.0_2022-04-05': ") or "v1.5.0_2022-04-05"
else:
    SOURCE_DOCKER_TAG = os.environ["SOURCE_DOCKER_TAG"]

if (os.getenv("TARGET_DOCKER_REGISTRY") is None):
    TARGET_DOCKER_REGISTRY = input("Provide target container registry DNS name or IP address:")
else:
    TARGET_DOCKER_REGISTRY = os.environ["TARGET_DOCKER_REGISTRY"]

if (os.getenv("TARGET_DOCKER_REPOSITORY") is None):
    TARGET_DOCKER_REPOSITORY = input("Provide target container registry repository:")
else:
    TARGET_DOCKER_REPOSITORY = os.environ["TARGET_DOCKER_REPOSITORY"]

if (os.getenv("TARGET_DOCKER_USERNAME") is None):
    TARGET_DOCKER_USERNAME = input("Provide username for the target container registry - press enter for using none:")
else:
    TARGET_DOCKER_USERNAME = os.environ["TARGET_DOCKER_USERNAME"]

if (os.getenv("TARGET_DOCKER_PASSWORD") is None):
    TARGET_DOCKER_PASSWORD = getpass.getpass("Provide password for the target container registry - press enter for using none:")
else:
    TARGET_DOCKER_PASSWORD = os.environ["TARGET_DOCKER_PASSWORD"]

if (os.getenv("TARGET_DOCKER_TAG") is None):
    TARGET_DOCKER_TAG = input("Provide container image tag for the images at the target: ")
else:
    TARGET_DOCKER_TAG = os.environ["TARGET_DOCKER_TAG"]

images = [  'arc-bootstrapper',
            'arc-controller',
            'arc-controller-db',
            'arc-monitor-collectd',
            'arc-monitor-elasticsearch',
            'arc-monitor-fluentbit',
            'arc-monitor-grafana',
            'arc-monitor-influxdb',
            'arc-monitor-kibana',
            'arc-monitor-telegraf',
            'arc-service-proxy',
            'arc-sqlmi',
            'arc-ha-orchestrator',
            'arc-ha-supervisor',
            'arc-postgres-11',
            'arc-postgres-12'
        ]

taggedimages = [image + ":" + SOURCE_DOCKER_TAG for image in images]

print(taggedimages)
if ((SOURCE_DOCKER_PASSWORD is not None) and (SOURCE_DOCKER_USERNAME is not None)):
    print("Execute docker login to source registry: " + SOURCE_DOCKER_REGISTRY)

    cmd = "docker login " + SOURCE_DOCKER_REGISTRY + " -u " + SOURCE_DOCKER_USERNAME + " -p " + SOURCE_DOCKER_PASSWORD
    execute_cmd(cmd)

print("Pulling images from source registry: " + SOURCE_DOCKER_REGISTRY + "/" + SOURCE_DOCKER_REPOSITORY)
cmd = ""
for image in taggedimages:
    cmd += "docker pull " + SOURCE_DOCKER_REGISTRY + "/" + SOURCE_DOCKER_REPOSITORY + "/" + image +  " & "
cmd = cmd[:len(cmd)-3]
execute_cmd(cmd)

if ((TARGET_DOCKER_PASSWORD is not None) and (TARGET_DOCKER_USERNAME is not None)):
    print("Execute docker login to target registry:" + TARGET_DOCKER_REGISTRY)
    cmd = "docker login " + TARGET_DOCKER_REGISTRY + " -u " + TARGET_DOCKER_USERNAME + " -p " + TARGET_DOCKER_PASSWORD
    execute_cmd(cmd)

print("Tagging local images...")
cmd = ""
for image in taggedimages:
    cmd += "docker tag " + SOURCE_DOCKER_REGISTRY + "/" + SOURCE_DOCKER_REPOSITORY + "/" + image + " " + TARGET_DOCKER_REGISTRY + "/" + TARGET_DOCKER_REPOSITORY + "/" + image + " & "
cmd = cmd[:len(cmd)-3]
print(cmd)
execute_cmd(cmd)

print("Push images to target registry: " + TARGET_DOCKER_REGISTRY + "/" + TARGET_DOCKER_REPOSITORY)
cmd = ""
for image in taggedimages:
    cmd += "docker push " + TARGET_DOCKER_REGISTRY + "/" + TARGET_DOCKER_REPOSITORY + "/" + image + " & "
cmd = cmd[:len(cmd)-3]
execute_cmd(cmd)

print("Images are now pushed to the target registry.")
