from azureml.core import Dataset
from azureml.opendatasets import MNIST
from azureml.core import Workspace
import os

ws = Workspace.from_config()

data_folder = "C:\Temp\data"
os.makedirs(data_folder, exist_ok=True)

mnist_file_dataset = MNIST.get_file_dataset()
mnist_file_dataset.download(data_folder, overwrite=True)

mnist_file_dataset = mnist_file_dataset.register(workspace=ws,
                                                 name='mnist_opendataset',
                                                 description='training and test dataset',
                                                 create_new_version=True)