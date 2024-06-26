# afd-appservices-postgres-redis-sample

A sample Bicep template to deploy Azure Front Door, App Services, Postgres, and
Redis on Azure. The deployment utilizes private networking, private endpoints,
and App Service access restrictions behind Azure Front Door. Additionally,
user-managed identities are used for secure access to the Postgres and Redis.

## Architecture Diagram

![Architecture Diagram](./images/architecture-diagram.drawio.png)

## Executing the Deployment

It is highly recommended to run this repo within the Dev Container that's
provided. This is done most easily by opening the repository folder in
[Visual Studio Code](https://code.visualstudio.com/docs/devcontainers/containers)
or by
[forking the repository](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/working-with-forks/fork-a-repo)
and using [GitHub Codespaces](https://github.com/features/codespaces).

### Environment Configuration

To get started, make a copy of the `.envsample` file to `.env`. Update the
`.env` file with the values for your sample deployment. Some notes on the values
to configure:

#### Azure Config

| Variable                | Description                                                                                       |
| ----------------------- | ------------------------------------------------------------------------------------------------- |
| AZURE_LOCATION          | The Azure region that resources will be deployed to - note the limitations below                  |
| AZURE_APPENV            | Short (_< 8 characters_), unique string to identify the deployed resources                        |
| AZURE_SUBSCRIPTIONID    | The GUID of the Azure subscription resources will be deployed into                                |
| AZURE_RESOURCE_USERNAME | Short username that will be used as a default login to deployed resources (e.g., Virtual Machine) |
| AZURE_RESOURCE_PASSWORD | Password to login to deployed resources for the `AZURE_RESOURCE_USERNAME`                         |

**NOTE:** As of today (April 2024), due to a limitation on Azure Front Door
Premium Private Link connections, only the following regions are supported:

| Americas         | Europe               | Africa             | Asia Pacific   |
| ---------------- | -------------------- | ------------------ | -------------- |
| Brazil South     | France Central       | South Africa North | Australia East |
| Canada Central   | Germany West Central |                    | Central India  |
| Central US       | North Europe         |                    | Japan East     |
| East US          | Norway East          |                    | Korea Central  |
| East US 2        | UK South             |                    | East Asia      |
| South Central US | West Europe          |                    |                |
| West US 3        | Sweden Central       |                    |                |
| US Gov Arizona   |                      |                    |                |
| US Gov Texas     |                      |                    |                |

For an up-to-date list, visit:
[Secure your Origin with Private Link in Azure Front Door Premium | Region availability](https://learn.microsoft.com/en-us/azure/frontdoor/private-link#region-availability)

#### Current User Config

| Variable          | Description                                                                               |
| ----------------- | ----------------------------------------------------------------------------------------- |
| PUBLIC_IP_ADDRESS | Your [public IP address](http://ifconfig.me/ip) that will be used for access restrictions |

#### Website Config

| Variable                  | Description                                                |
| ------------------------- | ---------------------------------------------------------- |
| ROOT_DOMAIN               | The root domain name for the website (e.g., `example.com`) |
| CERTIFICATE_BASE64_STRING | A Base 64 encoded PFX certificate to be used for HTTPS     |
| CERTIFICATE_PASSWORD      | The password of the PFX certificate                        |

If you are choosing to Bring Your Own Certificate (BYOC), you'll need to Base 64
encode a certificate; you can use the following command:

```sh
# For Linux:
base64 -w 0 FILE_NAME

# For macOS:
base64 -i FILE_NAME
```

#### Conditional Deployments (for debugging)

It's recommended to leave the following as `true` for the initial deployment. If
a redeployment is needed, these can be modified to reduce deployment times.
**Please** review the Bicep templates to understand what is actually going on
before setting to `false`.

| Variable                                | Description                                                                                                     |
| --------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| UPLOAD_CERTIFICATE                      | Should the PFX certificate be uploaded                                                                          |
| USE_MANAGED_CERTIFICATE                 | Should Front Door use the automatically provisioned certifate instead of the BYOC                               |
| DEPLOY_COMPUTE                          | Should the Compute Bicep module be deployed                                                                     |
| DEPLOY_COMPUTE_APPSERVICE_PEAPPROVAL    | Should the Compute App Services Bicep module deploy the Front Door Private Endpoint Approval (only needed once) |
| DEPLOY_DATA                             | Should the Data Bicep module be deployed                                                                        |
| DEPLOY_DATA_POSTGRES                    | Should the Data Bicep Postgres module be deployed                                                               |
| DEPLOY_DATA_REDIS                       | Should the Data Bicep Redis module be deployed                                                                  |
| DEPLOY_DATA_STORAGE                     | Should the Data Bicep Storage module be deployed                                                                |
| DEPLOY_DATA_STORAGE_PEAPPROVAL          | Should the Data Storage Bicep module deploy the Front Door Private Endpoint Approval (only needed once)         |
| DEPLOY_MANAGEMENT                       | Should the Management Bicep module be deployed                                                                  |
| DEPLOY_NETWORKING                       | Should the Networking Bicep module be deployed                                                                  |
| DEPLOY_NETWORKING_FRONTDOOR_DIAGNOSTICS | Should the Networking Front Door Diagnostics resource be deployed deployed                                      |
| DEPLOY_SECURITY                         | Should the Security Bicep module be deployed                                                                    |

### Run the Deployment Script

Once you've configured your `.env` file, you can now execute the deployment.
This is as simple as running this command within the terminal:

```sh
./deploy.sh
```

Output will be displayed in the terminal, as well as captured to the `logs`
folder. The initial run will take some time as it will deploy all resources
(approximately 15 - 30 minutes).

If there are any errors during the deployment, the output from ARM may not
always be clear. Go to the newly created resource group (which will be in the
format of `rg-<AZURE_APPENV>`) and look at the resources that were created. You
can also review the
[deployments blade](https://learn.microsoft.com/en-us/azure/azure-resource-manager/templates/deployment-history?tabs=azure-portal)
that will show the status of the deployment (which is broken down into
subdeployments to help with debugging). Note that each deployment will be
timestamped to help track down any potential issues.

> **Notes:** there may be instances where sub-deployments fail, specifically
> identity assignments on Postgres. Re-running the deployment _should_ resolve
> those issues.

### Connecting Domain to Sample

Once a deployment is successful, one last step needs to be done to access the
deployed site: pointing a custom domain to the Azure Front Door. This is done by
going to your registrar's DNS management tool and updating the nameservers to
Azure DNS. This can be found in your newly created DNS Zone in the Azure Portal.
For more information, visit
[this doc](https://learn.microsoft.com/en-us/azure/dns/dns-delegate-domain-azure-dns#retrieve-name-servers)

### Visiting the Sample Site

Once the domain is configured, you can visit the main site by going to
`https://www.YOURDOMAIN.tld`

## Removing the Sample

To remove all resources that have been deployed, run the removal script:

```sh
./remove.sh
```

This will remove the Log Analytics workspace (skipping soft-deletes) and then
remove the resource group that was created that contains all of the other
created resources.

If there are any issues deleteing the resource group, you can try re-running the
script, or manually deleting the resources and/or resource group from the Azure
Portal.

## Connecting to the Dev Container from a Local Terminal

The Dev Container has an SSH server running that allows you to use your local
terminal to connect to the running container. To do this, you'll first need to
set a password for the current user in the container (do this in a shell within
the Dev Container):

```sh
sudo passwd vscode
```

You can then connect from your local machine's terminal by executing this
command:

```sh
ssh -p 2222 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o GlobalKnownHostsFile=/dev/null vscode@localhost
```

You may need to `cd` to the workspace directory to run the deployment scripts:

```sh
cd /workspaces/afd-appservices-postgres-redis-sample/
```

## Additional Notes

The deployed application's repository can be found on
[GitHub](https://github.com/brandonmartinez/node-redis-postgres-azure-app).
There are additional instructions on how to utilize the Virtual Machine jumpbox
that gets deployed to access your secured resources from your local machine by
double-tunneling through the jumpbox.
