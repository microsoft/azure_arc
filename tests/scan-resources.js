const fs = require('fs');
const path = require('path');
const glob = require('glob');
const axios = require('axios');

const folderPath = process.argv[2];
const excludedFolders = process.argv[3] ? process.argv[3].split(',') : [];

async function getAzureResourceTypes() {
  const response = await axios.get('https://management.azure.com/providers?api-version=2021-01-01');
  const providers = response.data.value;

  const resourceTypes = [];

  for (const provider of providers) {
    const namespace = provider.namespace;
    const response = await axios.get(`https://management.azure.com/providers/${namespace}/?api-version=2021-01-01`);
    const types = response.data.resourceTypes.map((t) => `${namespace}/${t.resourceType}`);
    resourceTypes.push(...types);
  }

  return resourceTypes;
}

async function getAzureApiVersions() {
  const response = await axios.get('https://management.azure.com/providers?api-version=2021-01-01');
  const providers = response.data.value;

  const apiVersions = {};

  for (const provider of providers) {
    const namespace = provider.namespace;
    const response = await axios.get(`https://management.azure.com/providers/${namespace}/?api-version=2021-01-01`);
    const resourceTypes = response.data.resourceTypes;

    for (const resourceType of resourceTypes) {
      const resourceTypeName = `${namespace}/${resourceType.resourceType}`;

      if (azureResourceTypes.includes(resourceTypeName)) {
        const apiVersion = resourceType.apiVersions[0];
        apiVersions[resourceTypeName] = apiVersion;
      }
    }
  }

  return apiVersions;
}

const files = glob.sync(`${folderPath}/**/*.{json,bicep,tf}`, {
  ignore: excludedFolders.map((folder) => `${folderPath}/${folder}/**`),
});

const report = [];

(async function () {
  const azureResourceTypes = await getAzureResourceTypes();
  const azureApiVersions = await getAzureApiVersions();

  for (const file of files) {
    const extension = path.extname(file);

    if (extension === '.yml' || extension === '.yaml') {
      // Skip YAML files
      continue;
    }

    const contents = fs.readFileSync(file, 'utf8');
    const obj = JSON.parse(contents);
    const apiVersions = {};

    for (const resourceType of azureResourceTypes) {
      const regex = new RegExp(`^${resourceType}/`, 'i');
      const resources = obj.resources.filter((r) => r.type.match(regex));
      const versions = new Set(resources.map((r) => r.apiVersion));
      const latestVersion = azureApiVersions[resourceType];

      if (latestVersion && !versions.has(latestVersion)) {
        apiVersions[resourceType] = latestVersion;
      }
    }

    if (Object.keys(apiVersions).length > 0) {
      report.push({
        file,
        apiVersions,
      });
    }
  }

  console.log(JSON.stringify(report, null, 2));
})();
