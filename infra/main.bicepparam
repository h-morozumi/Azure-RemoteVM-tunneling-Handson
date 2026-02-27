using './main.bicep'

param environmentName = readEnvironmentVariable('AZURE_ENV_NAME', 'dev')
param adminUsername = 'azureuser'
param adminPassword = readEnvironmentVariable('AZURE_VM_ADMIN_PASSWORD', '')
