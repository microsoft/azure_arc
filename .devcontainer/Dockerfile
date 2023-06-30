# See here for image contents: https://github.com/microsoft/vscode-dev-containers/tree/v0.163.1/containers/alpine/.devcontainer/base.Dockerfile

FROM mcr.microsoft.com/dotnet/sdk:7.0-jammy

RUN apt-get update && apt-get -y upgrade

RUN apt-get update && apt-get install -y \
    wget \
    unzip \
    ca-certificates \
    apt-transport-https \
    lsb-release \
    gnupg \
	curl \
    && rm -rf /var/lib/apt/lists/*


RUN useradd --create-home vscode

# Install oh-my-posh (https://ohmyposh.dev/)
RUN wget https://github.com/JanDeDobbeleer/oh-my-posh/releases/download/v17.5.2/posh-linux-amd64 -O /usr/local/bin/oh-my-posh
RUN chmod +x /usr/local/bin/oh-my-posh

# Switch to non-root user:
WORKDIR /home/vscode
USER vscode

# Install Azure Developer CLI (https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/)
RUN curl -fsSL https://aka.ms/install-azd.sh | bash

# Install Azure PowerShell modules (https://docs.microsoft.com/en-us/powershell/azure/install-az-ps)
RUN pwsh Install-Module -Name Az -Force