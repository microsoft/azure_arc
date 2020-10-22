# Azure Arc enabled data services - Sample Scripts

This folder contains deployment samples for Azure Arc enabled data services.

## [Push images to private registry](./pull-and-push-arc-data-services-images-to-private-registry.py)

Azure Arc enabled data services deployment defaults to pulling container images from the public Microsoft Container Registry. If you are deploying in an environment that cannot access the Microsoft Container Registry then you push the images to a private registry in your environment that is accessible from the Kubernetes cluster. The python script ***pull-and-push-arc-data-services-images-to-private-registry.py*** can be used to pull images from the public Microsoft Container Registry to your private registry. The script can be used either in an interactive manner or in automated fashion by using environment variables to supply the parameters.