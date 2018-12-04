#############################################
# Constants
$demofolderpath = "C:\Users\dsebban\OneDrive - NELITE\Documents\Ignite Tour\demoberlin"
$AzureRGName = "IgniteTourBerlin"
$dnsPrefix = "igniteberlink8sdemo"
$windowsUser = "igniteuser"
$windowsPassword = "Gut3nT4gBerlin!"
$deploymentName = "berlindeployment"
$AzureRegion = "WestEurope"
$SampleJSON = "C:\Users\dsebban\OneDrive - NELITE\Documents\Ignite Tour\kubernetes-windows.json"
$MasterFQDN = "$dnsPrefix.$AzureRegion.cloudapp.azure.com"

#############################################
# Initialization

# Create working folder
if(Test-Path $demofolderpath ) {
    Remove-Item $demofolderpath -Recurse -Force
}
New-Item $demofolderpath -ItemType Directory
push-Location $demofolderpath

# login to Azure
az login 

# Create a resource Group
az group create --location $AzureRegion --name $AzureRGName 

# Get the group id
$groupId = (az group show --resource-group $AzureRGName --query id).Replace("""","") 

# Create an Azure service principal that will be used in the API Model
$sp = az ad sp create-for-rbac --role="Contributor" --scopes=$groupId | ConvertFrom-JSON 

#############################################
# Create ACS-engine APIModel

# Download template
#Invoke-WebRequest -UseBasicParsing https://raw.githubusercontent.com/Azure/acs-engine/master/examples/windows/kubernetes.json -OutFile kubernetes-windows.json

# Load template
$inJson = Get-Content $SampleJSON | ConvertFrom-Json

# Set dnsPrefix
$inJson.properties.masterProfile.dnsPrefix = $dnsPrefix

# Set Windows username & password
$inJson.properties.windowsProfile.adminPassword = $windowsPassword
$inJson.properties.windowsProfile.adminUsername = $windowsUser

# Copy in your SSH public key from `~/.ssh/id_rsa.pub` to linuxProfile.ssh.publicKeys.keyData
$inJson.properties.linuxProfile.ssh.publicKeys[0].keyData = [string](Get-Content "~/.ssh/id_rsa.pub")

# Set servicePrincipalProfile
$inJson.properties.servicePrincipalProfile.clientId = $sp.appId
$inJson.properties.servicePrincipalProfile.secret = $sp.password

# Save file
$inJson | ConvertTo-Json -Depth 5 | Out-File -Encoding ascii -FilePath "kubernetes-windows-complete.json"

#############################################
# Generate Azure Resource Manager template
acs-engine.exe generate kubernetes-windows-complete.json

#############################################
# Deploy the cluster
$AzureDeployJSON = "$demofolderpath\_output\$dnsPrefix\azuredeploy.json"
$AzureDeployParamJSON = "$demofolderpath\_output\$dnsPrefix\azuredeploy.parameters.json"
az group deployment create --name $deploymentName --resource-group $AzureRGName --template-file $AzureDeployJSON --parameters $AzureDeployParamJSON

#############################################
# Manage the cluster

# SSH login to Linux master node using the Master FQDN 
# ssh azureuser@$MasterFQDN

# Set KubeConfig environment variable
$ENV:KUBECONFIG="$demofolderpath\_output\$dnsPrefix\kubeconfig\kubeconfig.$AzureRegion.json"

# show cluster nodes using kubectl
kubectl get nodes
kubectl get pod
kubectl get pod

# manage cluster using dashboard
start kubectl proxy
# http://localhost:8001/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:/proxy/


#############################################
# cleanup

#az group delete -n $AzureRGName
#Pop-Location