function Invoke-AsBuiltReport.Nutanix.PrismCentral {
    <#
    .SYNOPSIS  
        PowerShell script to document the configuration of Nutanix Prism Central infrastucture in Word/HTML/XML/Text formats
    .DESCRIPTION
        Documents the configuration of Nutanix Prism Central infrastucture in Word/HTML/XML/Text formats using PScribo.
    .NOTES
        Version:        0.1.0
        Author:         Tim Carman
        Twitter:        @tpcarman
        Github:         tpcarman
        Credits:        Iain Brighton (@iainbrighton) - PScribo module
                        
    .LINK
        https://github.com/AsBuiltReport/AsBuiltReport.Nutanix.PrismCentral
    #>

    param (
        [String[]] $Target,
        [PSCredential] $Credential,
        [String]$StylePath
    )

    # Import JSON Configuration for Section
    $Section = $ReportConfig.Section

    $TextInfo = (Get-Culture).TextInfo

    # If custom style not set, use default style
    if (!$StylePath) {
        & "$PSScriptRoot\..\..\AsBuiltReport.Nutanix.PrismCentral.Style.ps1"
    }

    #region Workaround for SelfSigned Cert an force TLS 1.2
    if (-not ([System.Management.Automation.PSTypeName]'ServerCertificateValidationCallback').Type) {
        $certCallback = @"
        using System;
        using System.Net;
        using System.Net.Security;
        using System.Security.Cryptography.X509Certificates;
        public class ServerCertificateValidationCallback
        {
            public static void Ignore()
            {
                if(ServicePointManager.ServerCertificateValidationCallback ==null)
                {
                    ServicePointManager.ServerCertificateValidationCallback += 
                        delegate
                        (
                            Object obj, 
                            X509Certificate certificate, 
                            X509Chain chain, 
                            SslPolicyErrors errors
                        )
                        {
                            return true;
                        };
                }
            }
        }
"@
        Add-Type $certCallback
    }
    [ServerCertificateValidationCallback]::Ignore()
    [Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls"
    #endregion Workaround for SelfSigned Cert an force TLS 1.2

    foreach ($NtnxPC in $Target) {

        $username = $Credential.UserName
        $password = $Credential.GetNetworkCredential().Password
        $api_v3 = "https://" + $NtnxPC + ":9440/api/nutanix/v3"
        $auth = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($username + ":" + $password ))
        $headers = @{
        'Accept'        = 'application/json'
        'Authorization' = "Basic $auth" 
        'Content-Type'  = 'application/json'
        }

        Section -Style Heading1 'Prism Central' {
            #region Virtual Infrastructure

            #region VM information
            $body = @{'kind'='vm';'sort_attribute'='vmName';'sort_order'='ASCENDING';'length'=10000} | ConvertTo-Json
            $NtnxVMs = (Invoke-RestMethod -Uri ($api_v3 + '/vms/list') -Method POST -Headers $headers -Body $body).entities
            if ($NtnxVMs) {
                Section -Style Heading2 'Virtual Machines' {
                    $NtnxVMInfo = foreach ($NtnxVM in $NtnxVMs) {
                        [PSCustomObject]@{
                            'VM' = $NtnxVM.spec.name
                            'Power State' = $NtnxVM.spec.resources.power_state
                            #'Description' = $NtnxVM.spec.description
                            'Cluster' = $NtnxVM.spec.cluster_reference.name
                            #'Host'
                            #'Host IP'
                            'Hypervisor' = $NtnxVM.status.resources.hypervisor_type
                            'CPUs' = $NtnxVM.spec.resources.num_sockets
                            'Memory' = $NtnxVM.spec.resources.memory_size_mib
                            #'Network Adapters'
                            #'IP Addresses'
                            #'Disk Capacity'
                        }
                    }
                    $NtnxVMInfo | Sort-Object VM | Table -Name 'Virtual Machines'
                }
            }
            #endregion VM information

            #region Storage Container information
            #endregion Storage Container information

            #region Catalog Item information
            #endregion Catalog Item information

            #region Images information
            $body = @{'kind'='image';'sort_attribute'='name';'sort_order'='ASCENDING';'length'=10000} | ConvertTo-Json
            $NtnxImages = (Invoke-RestMethod -Uri ($api_v3 + '/images/list') -Method POST -Headers $headers -Body $body).entities
            if ($NtnxImages) {
                Section -Style Heading2 'Images' {
                    $NtnxImageInfo = foreach ($NtnxImage in $NtnxImages) {
                        [PSCustomObject]@{
                            'Name' = $NtnxImage.spec.name
                            'Description' = $NtnxImage.spec.description
                            'Image Type' = Switch ($NtnxImage.spec.resources.image_type) {
                                'DISK_IMAGE' { 'Disk' }
                                'ISO_IMAGE' { 'ISO'}
                            }
                        }
                    }
                    $NtnxImageInfo | Sort-Object Name | Table -Name 'Images'
                }
            }
            #endregion Images information

            #region Categories information
            $body = @{'kind'='category';'sort_attribute'='name';'sort_order'='ASCENDING';'length'=10000} | ConvertTo-Json
            $NtnxCategories = (Invoke-RestMethod -Uri ($api_v3 + '/categories/list') -Method POST -Headers $headers -Body $body).entities
            if ($NtnxCategories) {
                Section -Style Heading2 'Categories' {
                    $NtnxCategoryInfo = foreach ($NtnxCategory in $NtnxCategories) {
                        [PSCustomObject]@{
                            'Name' = $NtnxCategory.name
                            'Description' = $NtnxCategory.description
                            'System Defined' = Switch ($NtnxCategory.system_defined) {
                                'True' { 'Yes' }
                                'False' { 'No' }
                            }
                        }
                    }
                    $NtnxCategoryInfo | Sort-Object Name | Table -Name 'Categories'
                }
            }
            #endregion Categories information

            #region VM Recovery Points information
            #endregion VM Recovery Points information

            #region Networks
            $body = @{'kind'='subnet';'sort_attribute'='name';'sort_order'='ASCENDING';'length'=10000} | ConvertTo-Json
            $NtnxNetworks = (Invoke-RestMethod -Uri ($api_v3 + '/subnets/list') -Method POST -Headers $headers -Body $body).entities
            if ($NtnxNetworks) {
                Section -Style Heading2 'Networks' {
                    $NtnxNetworkInfo = foreach ($NtnxNetwork in $NtnxNetworks) {
                        [PSCustomObject]@{
                            'Name' = $NtnxNetwork.spec.name
                            #'Type' = $NtnxNetwork.spec.resources.subnet_type
                            #'vSwitch' = $NtnxNetwork.spec.resources.vswitch_name
                            'VLAN ID' = $NtnxNetwork.spec.resources.vlan_id
                            'Cluster Name' = $NtnxNetwork.spec.cluster_reference.name
                        }
                    }
                    $NtnxNetworkInfo | Sort-Object 'Name', 'VLAN ID','Cluster Name'  | Table -Name 'Networks'
                }
            }
            #endregion Networks

            #endregion Virtual Infrastructure

            #region Policies

            #region Security Policies
            #endregion Security Policies 

            #region Protection Policies
            #endregion Protection Policies 

            #region Recovery Plans
            #$body = @{'kind'='recovery_plan';'sort_attribute'='name';'sort_order'='ASCENDING';'length'=10000} | ConvertTo-Json
            #$NtnxRecoveryPlans = (Invoke-RestMethod -Uri ($api_v3 + '/recovery_plans/list') -Method POST -Headers $headers -Body $body).entities
            #endregion Recovery Plans 

            #region NGT Policies
            #$body = @{'kind'='ngt_policy';'sort_attribute'='name';'sort_order'='ASCENDING';'length'=10000} | ConvertTo-Json
            #$NtnxNgtPolicies = (Invoke-RestMethod -Uri ($api_v3 + '/ngt_policies/list') -Method POST -Headers $headers -Body $body).entities
            #endregion NGT Policies

            #region Image Placement Policies
            $body = @{'kind'='image_placement_policy';'sort_attribute'='name';'sort_order'='ASCENDING';'length'=10000} | ConvertTo-Json
            $NtnxImagePolicies = (Invoke-RestMethod -Uri ($api_v3 + '/images/placement_policies/list') -Method POST -Headers $headers -Body $body).entities
            if ($NtnxImagePolicies) {
                Section -Style Heading2 'Image Policies' {
                    $NtnxImagePolicyInfo = foreach ($NtnxImagePolicy in $NtnxImagePolicies) {
                        [PSCustomObject]@{
                            'Name' = $NtnxImagePolicy.spec.name
                            'Description' = $NtnxImagePolicy.spec.description
                        }
                    }
                    $NtnxImagePolicyInfo | Sort-Object Name | Table -Name 'Image Policies'
                }
            }
            #endregion Image Placement Policies

            #endregion Policies

            #region Hardware

            #region Clusters
            $body = @{'kind'='cluster';'sort_order'='ASCENDING';'length'=10000} | ConvertTo-Json
            $NtnxClusters = (Invoke-RestMethod -Uri ($api_v3 + '/clusters/list') -Method POST -Headers $headers -Body $body).entities | Where-Object {$_.status.resources.nodes -ne $null}
            if ($NtnxClusters) {
                foreach ($NtnxCluster in $NtnxClusters) {
                    Section -Style Heading2 $($NtnxCluster.spec.name) {
                        $AosSupportTerm = Switch ($Ntnxcluster.status.resources.config.build.is_long_term_support) {
                            $true { 'LTS' }
                            $false { 'STS' }
                        }
                        $NtnxClusterInfo = [PSCustomObject]@{
                            'Cluster' = $NtnxCluster.spec.name
                            'External IP' = $NtnxCluster.spec.resources.network.external_ip
                            'External Subnet' = $NtnxCluster.spec.resources.network.external_subnet
                            'Internal Subnet' = $NtnxCluster.spec.resources.network.internal_subnet
                            'Name Server(s)' = $NtnxCluster.spec.resources.network.name_server_ip_list -join ', '
                            'AOS Version' = $Ntnxcluster.spec.resources.config.software_map.nos.version + " ($AosSupportTerm)"
                            'NCC Version' = ($Ntnxcluster.spec.resources.config.software_map.ncc.version).Trim('ncc-')
                            'Redundancy Factor' = $Ntnxcluster.spec.resources.config.redundancy_factor
                            'Domain Awareness' = $Ntnxcluster.spec.resources.config.domain_awareness_level
                            'Encryption' = $Ntnxcluster.spec.resources.config.encryption_status
                            'Timezone' = $Ntnxcluster.spec.resources.config.timezone
                            '# of Nodes' = ($Ntnxcluster.status.resources.nodes.hypervisor_server_list | Where-Object {$_.ip -ne '127.0.0.1'}).Count
                            'Hypervisor(s)' = ($Ntnxcluster.status.resources.nodes.hypervisor_server_list.type | Select-Object -Unique) -join ', '
                        }
                        $NtnxClusterInfo | Sort-Object Cluster | Table -List "Cluster $($NtnxCluster.spec.name)"
                    }
                }
            }
            #endregion Clusters

            #region Hosts
            $body = @{'kind'='host';'sort_order'='ASCENDING';'length'=10000} | ConvertTo-Json
            $NtnxHosts = (Invoke-RestMethod -Uri ($api_v3 + '/hosts/list') -Method POST -Headers $headers -Body $body).entities | Where-Object {$_.status.name -ne $null}
            if ($NtnxHosts) {
                Section -Style Heading2 'Hosts' {
                    $NtnxHostInfo = foreach ($NtnxHost in $NtnxHosts) {
                        [PSCustomObject]@{
                            'Hostname' = $NtnxHost.status.name
                            'Model' = $NtnxHost.status.resources.block.block_model
                            'Block Serial Number' = $NtnxHost.status.resources.block.block_serial_number
                            'Node Serial Number' = $NtnxHost.status.resources.serial_number
                            'IPMI IP' = $NtnxHost.status.resources.ipmi.ip
                            'Hypervisor IP' = $NtnxHost.status.resources.hypervisor.ip
                            'CVM IP' = $NtnxHost.status.resources.controller_vm.ip
                            'Hypervisor' = $NtnxHost.status.resources.hypervisor.hypervisor_full_name
                        }
                    }
                    $NtnxHostInfo | Sort-Object Hostname | Table -Name 'Hosts'
                }
            }
            #endregion Hosts

            #region Disks
            #endregion Disks

            #region GPUs
            #endregion GPUs

            #endregion Hardware

            #region Administration

            #region Projects
            #endregion Projects

            #region Roles
            $body = @{'kind'='role';'sort_attribute'='name';'sort_order'='ASCENDING';'length'=10000} | ConvertTo-Json
            $NtnxRoles = (Invoke-RestMethod -Uri ($api_v3 + '/roles/list') -Method POST -Headers $headers -Body $body).entities
            if ($NtnxRoles) {
                Section -Style Heading2 'Roles' {
                    $NtnxRoleInfo = foreach ($NtnxRole in $NtnxRoles) {
                        [PSCustomObject]@{
                            'Name' = $NtnxRole.spec.name
                            'Description' = $NtnxRole.spec.description
                        }
                    }
                    $NtnxRoleInfo | Sort-Object Name | Table -Name 'Roles'
                }
            }
            #endregion Roles

            #region Users
            $body = @{'kind'='user';'sort_attribute'='name';'sort_order'='ASCENDING';'length'=10000} | ConvertTo-Json
            $NtnxUsers = (Invoke-RestMethod -Uri ($api_v3 + '/users/list') -Method POST -Headers $headers -Body $body).entities
            if ($NtnxUsers) {
                Section -Style Heading2 'Users' {
                    $NtnxUserInfo = foreach ($NtnxUser in $NtnxUsers) {
                        [PSCustomObject]@{
                            'Name' = $NtnxUser.status.name
                        }
                    }
                    $NtnxUserInfo | Sort-Object Name | Table -Name 'Users'
                }
            }
            #endregion Users

            #region User Groups
            #$body = @{'kind'='user_group';'sort_attribute'='name';'sort_order'='ASCENDING';'length'=10000} | ConvertTo-Json
            #$NtnxUserGroups = (Invoke-RestMethod -Uri ($api_v3 + '/user_groups/list') -Method POST -Headers $headers -Body $body).entities
            #endregion Users

            #region Availability Zones
            #endregion Availability Zones

            #endregion Administration

            #region Settings

            #region Identity Providers 
            $body = @{'kind'='identity_provider';'sort_attribute'='name';'sort_order'='ASCENDING';'length'=10000} | ConvertTo-Json
            $NtnxIdentityProviders = (Invoke-RestMethod -Uri ($api_v3 + '/identity_providers/list') -Method POST -Headers $headers -Body $body).entities
            if ($NtnxIdentityProviders) {
                Section -Style Heading2 'Identity Providers' {
                    $NtnxIdentityProviderInfo = foreach ($NtnxIdentityProvider in $NtnxIdentityProviders) {
                        [PSCustomObject]@{
                            'Name' = $NtnxIdentityProvider.spec.name
                            'Identity Provider URL' = $NtnxIdentityProvider.spec.resources.idp_properties.idp_url  
                            'Login URL' = $NtnxIdentityProvider.spec.resources.idp_properties.login_url
                        }
                    }
                    $NtnxIdentityProviderInfo | Sort-Object Name | Table -Name 'Identity Providers'
                }
            }
            #endregion Identity Providers 

            #region Directory Services
            $body = @{'kind'='directory_service';'sort_attribute'='name';'sort_order'='ASCENDING';'length'=10000} | ConvertTo-Json
            $NtnxDirectoryServices = (Invoke-RestMethod -Uri ($api_v3 + '/directory_services/list') -Method POST -Headers $headers -Body $body).entities
            if ($NtnxDirectoryServices) {
                Section -Style Heading2 'Directory Services' {
                    $NtnxDirectoryServiceInfo = foreach ($NtnxDirectoryService in $NtnxDirectoryServices) {
                        [PSCustomObject]@{
                            'Name' = $NtnxDirectoryService.spec.name
                            'Directory Type' = $NtnxDirectoryService.spec.resources.directory_type
                            'Domain' = $NtnxDirectoryService.spec.resources.domain_name 
                            'URL' = $NtnxDirectoryService.spec.resources.url
                        }
                    }
                    $NtnxDirectoryServiceInfo | Sort-Object Name | Table -Name 'Directory Services'
                }
            }
            #endregion Directory Services

            #region Remote Syslog Servers
            #$body = @{'kind'='remote_syslog_server';'sort_attribute'='name';'sort_order'='ASCENDING';'length'=10000} | ConvertTo-Json
            #$NtnxRemoteSyslogServers = (Invoke-RestMethod -Uri ($api_v3 + '/remote_syslog_servers/list') -Method POST -Headers $headers -Body $body).entities
            #endregion Remote Syslog Servers

            #endregion Settings
        }
    }
}