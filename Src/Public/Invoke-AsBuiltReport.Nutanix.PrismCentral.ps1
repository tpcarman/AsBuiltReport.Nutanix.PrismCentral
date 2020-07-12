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

    # Import JSON Configuration for InfoLevel and Options
    $InfoLevel = $ReportConfig.InfoLevel
    $Options = $ReportConfig.Options
    # Used to set values to TitleCase where required
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

        #region Authentication to target system(s)
        $username = $Credential.UserName
        $password = $Credential.GetNetworkCredential().Password
        $api_v3 = "https://" + $NtnxPC + ":9440/api/nutanix/v3"
        $auth = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($username + ":" + $password ))
        $headers = @{
            'Accept'        = 'application/json'
            'Authorization' = "Basic $auth" 
            'Content-Type'  = 'application/json'
        }
        #endregion Authentication to target system(s)

        #region Prism Central
        Section -Style Heading1 $NtnxPC {
            #region Prism Central System Configuration
            if ($InfoLevel.PrismCentral.PSObject.Properties.Value -ne 0) {
                Section -Style Heading2 'System Configuration' {
                    $body = @{'kind'='cluster';'sort_order'='ASCENDING';'length'=10000} | ConvertTo-Json
                    $NtnxPCConfig = (Invoke-RestMethod -Uri ($api_v3 + '/clusters/list') -Method POST -Headers $headers -Body $body).entities | Where-Object {$_.spec.name -eq 'Unnamed'}
                    #region PC System Settings Information
                    if ($InfoLevel.PrismCentral.SystemSettings -ge 1) {
                        $PcSupportTerm = Switch ($NtnxPCConfig.status.resources.config.build.is_long_term_support) {
                            $true { 'LTS' }
                            $false { 'STS' }
                        }
                        $NtnxPCInfo = [PSCustomObject]@{
                            'IP Address' = Switch ($NtnxCluster.spec.resources.network.external_ip) {
                                $null { '--' }
                                default { $NtnxCluster.spec.resources.network.external_ip }
                                
                            }
                            'Subnet Mask' = ($NtnxPCConfig.spec.resources.network.external_subnet -split "/")[1]
                            'Default Gateway' = 'Undefined'
                            'PC Version' = $NtnxPCConfig.spec.resources.config.software_map.nos.version + " ($PcSupportTerm)"
                            'NCC Version' = ($NtnxPCConfig.spec.resources.config.software_map.ncc.version).Trim('ncc-')
                            'Name Server(s)' = $NtnxPCConfig.spec.resources.network.name_server_ip_list -join ', '
                            'NTP Server(s)' = ($NtnxPCConfig.spec.resources.network.ntp_server_ip_list | Sort-Object) -join ', '
                            #'Redundancy Factor' = $NtnxPCConfig.spec.resources.config.redundancy_factor
                            'Timezone' = $NtnxPCConfig.spec.resources.config.timezone
                        }
                        $TableParams = @{
                            Name = "System Configuration - $NtnxPC"
                            List = $true
                            ColumnWidths = 50, 50
                        }
                        if ($Options.ShowTableCaptions) {
                            $TableParams['Caption'] = "- $($TableParams.Name)"
                        }
                        $NtnxPCInfo | Table @TableParams
                    }
                    #endregion PC System Settings Information

                    #region PC SMTP Server Information
                    if ($NtnxPCConfig.spec.resources.network.smtp_server.server.address.fqdn -and ($InfoLevel.PrismCentral.SmtpServer -ge 1)) {
                        Section -Style Heading3 'SMTP Configuration' {
                            $NtnxPCSmtpInfo = [PSCustomObject]@{
                                'SMTP Server' = $NtnxPCConfig.spec.resources.network.smtp_server.server.address.fqdn
                                'SMTP Port' = $NtnxPCConfig.spec.resources.network.smtp_server.server.address.port
                                'From Email Address' = $NtnxPCConfig.spec.resources.network.smtp_server.email_address
                            }
                            $TableParams = @{
                                Name = "SMTP Configuration - $NtnxPC"
                            }
                            if ($Options.ShowTableCaptions) {
                                $TableParams['Caption'] = "- $($TableParams.Name)"
                            }
                            $NtnxPCSmtpInfo | Table @TableParams
                        }
                    }
                    #endregion PC SMTP Server Information

                    #region Identity Providers 
                    $body = @{'kind'='identity_provider';'sort_attribute'='name';'sort_order'='ASCENDING';'length'=10000} | ConvertTo-Json
                    $NtnxIdentityProviders = (Invoke-RestMethod -Uri ($api_v3 + '/identity_providers/list') -Method POST -Headers $headers -Body $body).entities
                    if ($NtnxIdentityProviders -and ($InfoLevel.PrismCentral.IdentityProviders -ge 1)) {
                        Section -Style Heading3 'Identity Providers' {
                            $NtnxIdentityProviderInfo = foreach ($NtnxIdentityProvider in $NtnxIdentityProviders) {
                                [PSCustomObject]@{
                                    'Identity Provider' = $NtnxIdentityProvider.spec.name
                                    'Identity Provider URL' = $NtnxIdentityProvider.spec.resources.idp_properties.idp_url  
                                    'Login URL' = $NtnxIdentityProvider.spec.resources.idp_properties.login_url
                                }
                            }
                            $TableParams = @{
                                Name = "Identity Providers - $NtnxPC"
                                ColumnWidths = 24, 38, 38
                            }
                            if ($Options.ShowTableCaptions) {
                                $TableParams['Caption'] = "- $($TableParams.Name)"
                            }
                            $NtnxIdentityProviderInfo | Sort-Object 'Identity Provider' | Table @TableParams
                        }
                    }
                    #endregion Identity Providers 

                    #region Directory Services
                    $body = @{'kind'='directory_service';'sort_attribute'='name';'sort_order'='ASCENDING';'length'=10000} | ConvertTo-Json
                    $NtnxDirectoryServices = (Invoke-RestMethod -Uri ($api_v3 + '/directory_services/list') -Method POST -Headers $headers -Body $body).entities
                    if ($NtnxDirectoryServices -and ($InfoLevel.PrismCentral.DirectoryServices -ge 1)) {
                        Section -Style Heading3 'Directory Services' {
                            $NtnxDirectoryServiceInfo = foreach ($NtnxDirectoryService in $NtnxDirectoryServices) {
                                [PSCustomObject]@{
                                    'Directory Name' = $NtnxDirectoryService.spec.name
                                    'Directory Type' = $TextInfo.ToTitleCase(($NtnxDirectoryService.spec.resources.directory_type).ToLower()).Replace("_"," ")
                                    'Domain' = $NtnxDirectoryService.spec.resources.domain_name 
                                    'URL' = $NtnxDirectoryService.spec.resources.url
                                }
                            }
                            $TableParams = @{
                                Name = "Directory Services - $NtnxPC"
                                ColumnWidths = 25, 25, 25, 25
                            }
                            if ($Options.ShowTableCaptions) {
                                $TableParams['Caption'] = "- $($TableParams.Name)"
                            }
                            $NtnxDirectoryServiceInfo | Sort-Object 'Directory Name' | Table @TableParams
                        }
                    }
                    #endregion Directory Services

                    #region Remote Syslog Servers
                    $body = @{'kind'='remote_syslog_server';'sort_attribute'='name';'sort_order'='ASCENDING';'length'=10000} | ConvertTo-Json
                    $NtnxSyslogServer = (Invoke-RestMethod -Uri ($api_v3 + '/remote_syslog_servers/list') -Method POST -Headers $headers -Body $body).entities
                    if ($NtnxSyslogServer -and ($InfoLevel.PrismCentral.SyslogServer -ge 1)) {
                        Section -Style Heading3 'Syslog Server' {
                            $NtnxSyslogServerInfo = [PSCustomObject]@{
                                    'Server Name' = $NtnxSyslogServer.spec.resources.server_name
                                    'IP Address' = $NtnxSyslogServer.spec.resources.ip_address
                                    'Port' = $NtnxSyslogServer.spec.resources.port
                                    'Protocol' = $NtnxSyslogServer.spec.resources.network_protocol
                                }
                            $TableParams = @{
                                Name = "Syslog Server - $NtnxPC"
                                ColumnWidths = 25, 25, 25, 25
                            }
                            if ($Options.ShowTableCaptions) {
                                $TableParams['Caption'] = "- $($TableParams.Name)"
                            }
                            $NtnxSyslogServerInfo | Table @TableParams
                        }
                    }
                    #endregion Remote Syslog Servers
                }
            }
            #endregion Prism Central System Configuration

            #region Virtual Infrastructure
            if ($InfoLevel.VirtualInfrastructure.PSObject.Properties.Value -ne 0) {
                Section -Style Heading2 'Virtual Infrastructure' {
                    #region VM Information
                    $body = @{'kind'='vm';'sort_attribute'='vmName';'sort_order'='ASCENDING';'length'=10000} | ConvertTo-Json
                    $NtnxVMs = (Invoke-RestMethod -Uri ($api_v3 + '/vms/list') -Method POST -Headers $headers -Body $body).entities
                    $NtnxVMs = $NtnxVMs | Sort-Object -Property @{Expression = {$_.spec.name; $_.spec.cluster_reference.name}}
                    if ($NtnxVMs -and ($InfoLevel.VirtualInfrastructure.VM -ge 1)) {
                        Section -Style Heading3 'Virtual Machines' {
                            if ($InfoLevel.VirtualInfrastructure.VM -eq 1) {
                                #region VM Summary Information
                                $NtnxVMInfo = foreach ($NtnxVM in $NtnxVMs) {
                                    [PSCustomObject]@{
                                        'VM' = $NtnxVM.spec.name
                                        'Power State' = $TextInfo.ToTitleCase(($NtnxVM.spec.resources.power_state).ToLower())
                                        'Cluster' = $NtnxVM.spec.cluster_reference.name
                                        #'Hypervisor' = $NtnxVM.status.resources.hypervisor_type
                                        'CPUs' = $NtnxVM.spec.resources.num_sockets
                                        'Memory' = $NtnxVM.spec.resources.memory_size_mib
                                        'Network Adapters' = ($NtnxVM.spec.resources.nic_list).Count
                                        'Disk Capacity GiB' = ((($NtnxVM.spec.resources.disk_list | Where-Object {$_.device_properties.device_type -eq 'DISK'}).disk_size_mib | Measure-Object -sum).Sum / 1024)
                                    }
                                }
                                $TableParams = @{
                                    Name = "Virtual Machines - $NtnxPC"
                                }
                                if ($Options.ShowTableCaptions) {
                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                }
                                if ($Healthcheck.VM.PowerState) {
                                    $NtnxVMInfo | Where-Object { $_.'Power State' -eq 'Off' } | Set-Style -Style Warning -Property 'Power State'
                                }
                                $NtnxVMInfo | Table @TableParams
                                #endregion VM Summary Information
                            }
                            else {
                                foreach ($NtnxVM in $NtnxVMs) {
                                    #region VM Detailed Information
                                    Section -Style Heading4 $($NtnxVM.spec.name) {
                                        $NtnxVMInfo = [PSCustomObject]@{
                                            'VM' = $NtnxVM.spec.name
                                            'Power State' = $TextInfo.ToTitleCase(($NtnxVM.spec.resources.power_state).ToLower())
                                            'Description' = $NtnxVM.spec.description
                                            'Cluster' = $NtnxVM.spec.cluster_reference.name
                                            #'Hypervisor' = $NtnxVM.status.resources.hypervisor_type
                                            'CPUs' = $NtnxVM.spec.resources.num_sockets
                                            'Memory' = $NtnxVM.spec.resources.memory_size_mib
                                            'Network Adapters' = ($NtnxVM.spec.resources.nic_list).Count
                                            'Disk Capacity' = "$(((($NtnxVM.spec.resources.disk_list | Where-Object {$_.device_properties.device_type -eq 'DISK'}).disk_size_mib | Measure-Object -sum).Sum / 1024)) GiB"
                                        }
                                        $TableParams = @{
                                            Name = "VM Configuration - $($NtnxVM.spec.name)"
                                            List = $true
                                            ColumnWidths = 50, 50
                                        }
                                        if ($Options.ShowTableCaptions) {
                                            $TableParams['Caption'] = "- $($TableParams.Name)"
                                        }
                                        if ($Healthcheck.VM.PowerState) {
                                            $NtnxVMInfo | Where-Object { $_.'Power State' -eq 'Off' } | Set-Style -Style Warning -Property 'Power State'
                                        }
                                        $NtnxVMInfo | Table @TableParams

                                        Section -Style Heading5 "Networks" {
                                            $NtnxVmNetworks = foreach ($VmNetwork in ($NtnxVM.spec.resources.nic_list | Sort-Object -Property @{Expression={$_.subnet_reference.name}})) {
                                                [PSCustomObject]@{
                                                    'Network' = $VmNetwork.subnet_reference.name
                                                    #'Type' = $VmNetwork.nic_type
                                                    'VLAN Mode' = $TextInfo.ToTitleCase(($VmNetwork.vlan_mode).ToLower())
                                                    'MAC Address' = $VmNetwork.mac_address
                                                    'Connected' = Switch ($VmNetwork.is_connected) {
                                                        $true { 'Yes' }
                                                        $false { 'No' }
                                                    }
                                                }
                                            }
                                            $TableParams = @{
                                                Name = "Network Configuration - $($NtnxVM.spec.name)"
                                            }
                                            if ($Options.ShowTableCaptions) {
                                                $TableParams['Caption'] = "- $($TableParams.Name)"
                                            }
                                            $NtnxVMNetworks | Table @TableParams
                                        }
                                    }
                                    #endregion VM Detailed Information
                                }
                            }
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
                    if ($NtnxImages -and ($InfoLevel.VirtualInfrastructure.Images -ge 1)) {
                        Section -Style Heading3 'Images' {
                            $NtnxImageInfo = foreach ($NtnxImage in $NtnxImages) {
                                [PSCustomObject]@{
                                    'Image' = $NtnxImage.spec.name
                                    'Description' = $NtnxImage.spec.description
                                    'Image Type' = Switch ($NtnxImage.spec.resources.image_type) {
                                        'DISK_IMAGE' { 'Disk' }
                                        'ISO_IMAGE' { 'ISO'}
                                    }
                                }
                            }
                            $TableParams = @{
                                Name = "Images - $NtnxPC"
                            }
                            if ($Options.ShowTableCaptions) {
                                $TableParams['Caption'] = "- $($TableParams.Name)"
                            } 
                            $NtnxImageInfo | Sort-Object 'Image' | Table @TableParams
                        }
                    }
                    #endregion Images information

                    #region Categories information
                    $body = @{'kind'='category';'sort_attribute'='name';'sort_order'='ASCENDING';'length'=10000} | ConvertTo-Json
                    $NtnxCategories = (Invoke-RestMethod -Uri ($api_v3 + '/categories/list') -Method POST -Headers $headers -Body $body).entities
                    if ($NtnxCategories -and ($InfoLevel.VirtualInfrastructure.Categories -ge 1)) {
                        Section -Style Heading3 'Categories' {
                            $NtnxCategoryInfo = foreach ($NtnxCategory in $NtnxCategories) {
                                [PSCustomObject]@{
                                    'Category' = $NtnxCategory.name
                                    'Description' = $NtnxCategory.description
                                    'System Defined' = Switch ($NtnxCategory.system_defined) {
                                        'True' { 'Yes' }
                                        'False' { 'No' }
                                    }
                                }
                            }
                            $TableParams = @{
                                Name = "Categories - $NtnxPC"
                                ColumnWidths = 30, 50, 20
                            }
                            if ($Options.ShowTableCaptions) {
                                $TableParams['Caption'] = "- $($TableParams.Name)"
                            } 
                            $NtnxCategoryInfo | Sort-Object 'Category' | Table @TableParams 
                        }
                    }
                    #endregion Categories information

                    #region VM Recovery Points information
                    #endregion VM Recovery Points information

                    #region Networks
                    $body = @{'kind'='subnet';'sort_attribute'='name';'sort_order'='ASCENDING';'length'=10000} | ConvertTo-Json
                    $NtnxNetworks = (Invoke-RestMethod -Uri ($api_v3 + '/subnets/list') -Method POST -Headers $headers -Body $body).entities
                    if ($NtnxNetworks -and ($InfoLevel.VirtualInfrastructure.Networks -ge 1)) {
                        Section -Style Heading3 'Networks' {
                            $NtnxNetworkInfo = foreach ($NtnxNetwork in $NtnxNetworks) {
                                [PSCustomObject]@{
                                    'Network' = $NtnxNetwork.spec.name
                                    #'Type' = $NtnxNetwork.spec.resources.subnet_type
                                    #'vSwitch' = $NtnxNetwork.spec.resources.vswitch_name
                                    'VLAN ID' = $NtnxNetwork.spec.resources.vlan_id
                                    'Cluster Name' = $NtnxNetwork.spec.cluster_reference.name
                                }
                            }
                            $TableParams = @{
                                Name = "Networks - $NtnxPC"
                            }
                            if ($Options.ShowTableCaptions) {
                                $TableParams['Caption'] = "- $($TableParams.Name)"
                            } 
                            $NtnxNetworkInfo | Sort-Object 'Network', 'VLAN ID','Cluster Name'  | Table @TableParams
                        }
                    }
                    #endregion Networks
                }
            }
            #endregion Virtual Infrastructure

            #region Hardware
            if ($InfoLevel.Hardware.PSObject.Properties.Value -ne 0) {
                Section -Style Heading2 'Hardware' {
                    #region Clusters
                    $body = @{'kind'='cluster';'sort_order'='ASCENDING';'length'=10000} | ConvertTo-Json
                    $NtnxClusters = (Invoke-RestMethod -Uri ($api_v3 + '/clusters/list') -Method POST -Headers $headers -Body $body).entities | Where-Object {$_.status.resources.nodes -ne $null}
                    $NtnxClusters = $NtnxClusters | Sort-Object -Property @{Expression = {$_.spec.name}}
                    if ($NtnxClusters -and ($InfoLevel.Hardware.Clusters -ge 1)) {
                        Section -Style Heading3 'Clusters' {
                            if ($InfoLevel.Hardware.Clusters -eq 1) {
                                #region Cluster Summary Information
                                $NtnxClusterInfo = foreach ($NtnxCluster in $NtnxClusters) {
                                    [PSCustomObject]@{
                                        'Cluster' = $NtnxCluster.spec.name
                                        'AOS Version' = $Ntnxcluster.spec.resources.config.software_map.nos.version
                                        'NCC Version' = ($Ntnxcluster.spec.resources.config.software_map.ncc.version).Trim('ncc-')
                                        'Host Count' = ($Ntnxcluster.status.resources.nodes.hypervisor_server_list | Where-Object {$_.ip -ne '127.0.0.1'}).Count
                                        #'VM Count'
                                        'Hypervisor' = ($Ntnxcluster.status.resources.nodes.hypervisor_server_list.type | Select-Object -Unique) -join ', '
                                        'Inefficient VMs' = $Ntnxcluster.status.resources.analysis.vm_efficiency_map.inefficient_vm_num
                                    }
                                }
                                $TableParams = @{
                                    Name = "Clusters - $NtnxPC"
                                }
                                if ($Options.ShowTableCaptions) {
                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                } 
                                $NtnxClusterInfo | Sort-Object Cluster | Table @TableParams
                                #endregion Cluster Summary Information
                            }
                            else {
                                foreach ($NtnxCluster in $NtnxClusters) {
                                    Section -Style Heading4 $($NtnxCluster.spec.name) {
                                        #region Cluster Detailed Information
                                        $AosSupportTerm = Switch ($NtnxCluster.status.resources.config.build.is_long_term_support) {
                                            $true { 'LTS' }
                                            $false { 'STS' }
                                        }
                                        $NtnxClusterInfo = [PSCustomObject]@{
                                            'Cluster' = $NtnxCluster.spec.name
                                            'External IP' = $NtnxCluster.spec.resources.network.external_ip
                                            'External Subnet' = $NtnxCluster.spec.resources.network.external_subnet
                                            'Internal Subnet' = $NtnxCluster.spec.resources.network.internal_subnet
                                            'Name Server(s)' = $NtnxCluster.spec.resources.network.name_server_ip_list -join ', '
                                            'NTP Server(s)' = ($NtnxCluster.spec.resources.network.ntp_server_ip_list | Sort-Object) -join ', '
                                            'AOS Version' = $Ntnxcluster.spec.resources.config.software_map.nos.version + " ($AosSupportTerm)"
                                            'NCC Version' = ($Ntnxcluster.spec.resources.config.software_map.ncc.version).Trim('ncc-')
                                            'Redundancy Factor' = $Ntnxcluster.spec.resources.config.redundancy_factor
                                            'Domain Awareness' = $TextInfo.ToTitleCase(($Ntnxcluster.spec.resources.config.domain_awareness_level).ToLower())
                                            'Encryption' = $TextInfo.ToTitleCase(($Ntnxcluster.spec.resources.config.encryption_status).ToLower()).Replace("_"," ")
                                            'Timezone' = $Ntnxcluster.spec.resources.config.timezone
                                            'Host Count' = ($Ntnxcluster.status.resources.nodes.hypervisor_server_list | Where-Object {$_.ip -ne '127.0.0.1'}).Count
                                            'Hypervisor' = ($Ntnxcluster.status.resources.nodes.hypervisor_server_list.type | Select-Object -Unique) -join ', '
                                            'Inefficient VMs' = $Ntnxcluster.status.resources.analysis.vm_efficiency_map.inefficient_vm_num
                                            'Inactive VMs' = $Ntnxcluster.status.resources.analysis.vm_efficiency_map.dead_vm_num 
                                            'Overprovisioned VMs' = $Ntnxcluster.status.resources.analysis.vm_efficiency_map.overprovisioned_vm_num
                                            'Constrained VMs' = $Ntnxcluster.status.resources.analysis.vm_efficiency_map.constrained_vm_num
                                            'Bully VMs' = $Ntnxcluster.status.resources.analysis.vm_efficiency_map.bully_vm_num 
                                        }
                                        $TableParams = @{
                                            Name = "Cluster Configuration - $($NtnxCluster.spec.name)"
                                            ColumnWidths = 50, 50
                                            List = $true
                                        }
                                        if ($Options.ShowTableCaptions) {
                                            $TableParams['Caption'] = "- $($TableParams.Name)"
                                        } 
                                        $NtnxClusterInfo | Sort-Object Cluster | Table @TableParams
                                        #endregion Cluster Detailed Information

                                        #region Cluster SMTP Configuration
                                        if ($NtnxCluster.spec.resources.network.smtp_server.server.address.fqdn) {
                                            Section -Style Heading4 'SMTP Configuration' {
                                                $NtnxClusterSmtpInfo = [PSCustomObject]@{
                                                    'SMTP Server' = $NtnxCluster.spec.resources.network.smtp_server.server.address.fqdn
                                                    'SMTP Port' = $NtnxCluster.spec.resources.network.smtp_server.server.address.port
                                                    'From Email Address' = $NtnxCluster.spec.resources.network.smtp_server.email_address
                                                }
                                                $TableParams = @{
                                                    Name = "SMTP Configuration - $($NtnxCluster.spec.name)"
                                                }
                                                if ($Options.ShowTableCaptions) {
                                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                                }
                                                $NtnxClusterSmtpInfo | Table @TableParams
                                            }
                                        }
                                        #endregion Cluster SMTP Configuration
                                    }
                                }
                            }
                        }
                    }
                    #endregion Clusters

                    #region Hosts
                    $body = @{'kind'='host';'sort_order'='ASCENDING';'length'=10000} | ConvertTo-Json
                    $NtnxHosts = (Invoke-RestMethod -Uri ($api_v3 + '/hosts/list') -Method POST -Headers $headers -Body $body).entities | Where-Object {$_.status.name -ne $null}
                    $NtnxHosts = $NtnxHosts | Sort-Object -Property @{Expression = {$_.status.name}}
                    if ($NtnxHosts -and ($InfoLevel.Hardware.Hosts -ge 1)) {
                        Section -Style Heading3 'Hosts' {
                            if ($InfoLevel.Hardware.Hosts -eq 1){
                                $NtnxHostInfo = foreach ($NtnxHost in $NtnxHosts) {
                                    [PSCustomObject]@{
                                        'Host' = $NtnxHost.status.name
                                        'Hypervisor IP' = $NtnxHost.status.resources.hypervisor.ip
                                        'CVM IP' = $NtnxHost.status.resources.controller_vm.ip
                                        'Hypervisor' = $NtnxHost.status.resources.hypervisor.hypervisor_full_name
                                        'Memory GiB' = [math]::Round($NtnxHost.status.resources.memory_capacity_mib / 1024, 2)
                                        #'Cluster'
                                        'VM Count' = $NtnxHost.status.resources.hypervisor.num_vms
                                    }
                                }
                                $TableParams = @{
                                    Name = "Hosts - $NtnxPC"
                                    ColumnWidths = 26, 18, 18, 20, 10, 8
                                }
                                if ($Options.ShowTableCaptions) {
                                    $TableParams['Caption'] = "- $($TableParams.Name)"
                                } 
                                $NtnxHostInfo | Sort-Object Host | Table @TableParams
                            }
                            else {
                                foreach ($NtnxHost in $NtnxHosts) {
                                    Section -Style Heading4 $($NtnxHost.status.name) {
                                        $NtnxHostInfo = [PSCustomObject]@{
                                            'Host' = $NtnxHost.status.name
                                            'Block Model' = $NtnxHost.status.resources.block.block_model
                                            'Block Serial Number' = $NtnxHost.status.resources.block.block_serial_number
                                            'Node Serial Number' = $NtnxHost.status.resources.serial_number
                                            'IPMI IP' = $NtnxHost.status.resources.ipmi.ip
                                            'Hypervisor IP' = $NtnxHost.status.resources.hypervisor.ip
                                            'CVM IP' = $NtnxHost.status.resources.controller_vm.ip
                                            'Hypervisor' = $NtnxHost.status.resources.hypervisor.hypervisor_full_name
                                            'Host Type' = $TextInfo.ToTitleCase(($NtnxHost.status.resources.host_type).ToLower()).Replace("_"," ")
                                            'Memory Capacity' = "$([math]::Round($NtnxHost.status.resources.memory_capacity_mib / 1024, 2)) GiB"
                                        }
                                        $TableParams = @{
                                            Name = "Host Configuration - $($NtnxHost.status.name)"
                                            ColumnWidths = 50, 50
                                            List = $true
                                        }
                                        if ($Options.ShowTableCaptions) {
                                            $TableParams['Caption'] = "- $($TableParams.Name)"
                                        }
                                        $NtnxHostInfo | Sort-Object Host | Table @TableParams
                                    }
                                }
                            }
                        }
                    }
                    #endregion Hosts

                    #region Disks
                    #endregion Disks

                    #region GPUs
                    #endregion GPUs
                }
            }
            #endregion Hardware

            #region Policies
            if ($InfoLevel.Policies.PSObject.Properties.Value -ne 0) {
                Section -Style Heading2 'Policies' {
                    #region Security Policies
                    #endregion Security Policies 

                    #region Protection Policies
                    #endregion Protection Policies 

                    #region Recovery Plans
                    #$body = @{'kind'='recovery_plan';'sort_attribute'='name';'sort_order'='ASCENDING';'length'=10000} | ConvertTo-Json
                    #$NtnxRecoveryPlans = (Invoke-RestMethod -Uri ($api_v3 + '/recovery_plans/list') -Method POST -Headers $headers -Body $body).entities
                    #endregion Recovery Plans 

                    #region NGT Policies
                    $body = @{'kind'='ngt_policy';'sort_attribute'='name';'sort_order'='ASCENDING';'length'=10000} | ConvertTo-Json
                    $NtnxNgtPolicies = (Invoke-RestMethod -Uri ($api_v3 + '/ngt_policies/list') -Method POST -Headers $headers -Body $body).entities
                    if ($NtnxNgtPolicies -and ($InfoLevel.Policies.NGT -ge 1)) {
                        Section -Style Heading3 'NGT Policies' {
                            $NtnxNgtPolicyInfo = foreach ($NtnxNgtPolicy in $NtnxNgtPolicies) {
                                [PSCustomObject]@{
                                    'Policy' = $NtnxNgtPolicy.spec.name
                                    'Description' = $NtnxNgtPolicy.spec.description
                                    'Policy Type' = $NtnxNgtPolicy.spec.resources.type
                                }
                            }
                            $TableParams = @{
                                Name = "NGT Policies - $NtnxPC"
                            }
                            if ($Options.ShowTableCaptions) {
                                $TableParams['Caption'] = "- $($TableParams.Name)"
                            } 
                            $NtnxNgtPolicyInfo | Sort-Object 'Policy' | Table @TableParams
                        }
                    }
                    #endregion NGT Policies

                    #region Image Placement Policies
                    $body = @{'kind'='image_placement_policy';'sort_attribute'='name';'sort_order'='ASCENDING';'length'=10000} | ConvertTo-Json
                    $NtnxImagePolicies = (Invoke-RestMethod -Uri ($api_v3 + '/images/placement_policies/list') -Method POST -Headers $headers -Body $body).entities
                    if ($NtnxImagePolicies -and ($InfoLevel.Policies.ImagePlacement -ge 1)) {
                        Section -Style Heading3 'Image Placement Policies' {
                            $NtnxImagePolicyInfo = foreach ($NtnxImagePolicy in $NtnxImagePolicies) {
                                [PSCustomObject]@{
                                    'Policy' = $NtnxImagePolicy.spec.name
                                    'Description' = $NtnxImagePolicy.spec.description
                                }
                            }
                            $TableParams = @{
                                Name = "Image Placement Policies - $NtnxPC"
                                ColumnWidths = 50, 50
                            }
                            if ($Options.ShowTableCaptions) {
                                $TableParams['Caption'] = "- $($TableParams.Name)"
                            } 
                            $NtnxImagePolicyInfo | Sort-Object 'Policy' | Table @TableParams
                        }
                    }
                    #endregion Image Placement Policies
                }
            }
            #endregion Policies

            #region Administration
            if ($InfoLevel.Administration.PSObject.Properties.Value -ne 0) {
                Section -Style Heading2 'Administration' {
                    #region Projects
                    #endregion Projects

                    #region Roles
                    $body = @{'kind'='role';'sort_attribute'='name';'sort_order'='ASCENDING';'length'=10000} | ConvertTo-Json
                    $NtnxRoles = (Invoke-RestMethod -Uri ($api_v3 + '/roles/list') -Method POST -Headers $headers -Body $body).entities
                    if ($NtnxRoles -and ($InfoLevel.Administration.Roles -ge 1)) {
                        Section -Style Heading3 'Roles' {
                            $NtnxRoleInfo = foreach ($NtnxRole in $NtnxRoles) {
                                [PSCustomObject]@{
                                    'Role' = $NtnxRole.spec.name
                                    'Description' = $NtnxRole.spec.description
                                }
                            }
                            $TableParams = @{
                                Name = "Roles - $NtnxPC"
                                ColumnWidths = 25, 75
                            }
                            if ($Options.ShowTableCaptions) {
                                $TableParams['Caption'] = "- $($TableParams.Name)"
                            }
                            $NtnxRoleInfo | Sort-Object Role | Table @TableParams
                        }
                    }
                    #endregion Roles

                    #region Users
                    $body = @{'kind'='user';'sort_attribute'='name';'sort_order'='ASCENDING';'length'=10000} | ConvertTo-Json
                    $NtnxLocalUsers = (Invoke-RestMethod -Uri ($api_v3 + '/users/list') -Method POST -Headers $headers -Body $body).entities
                    if ($NtnxLocalUsers -and ($InfoLevel.Administration.LocalUsers -ge 1)) {
                        Section -Style Heading3 'Local Users' {
                            $NtnxLocalUserInfo = foreach ($NtnxLocalUser in $NtnxLocalUsers) {
                                [PSCustomObject]@{
                                    'Local User' = $NtnxLocalUser.status.name
                                }
                            }
                            $TableParams = @{
                                Name = "Local Users - $NtnxPC"
                            }
                            if ($Options.ShowTableCaptions) {
                                $TableParams['Caption'] = "- $($TableParams.Name)"
                            }
                            $NtnxLocalUserInfo | Sort-Object 'Local User' | Table @TableParams
                        }
                    }
                    #endregion Users

                    #region User Groups
                    #$body = @{'kind'='user_group';'sort_attribute'='name';'sort_order'='ASCENDING';'length'=10000} | ConvertTo-Json
                    #$NtnxUserGroups = (Invoke-RestMethod -Uri ($api_v3 + '/user_groups/list') -Method POST -Headers $headers -Body $body).entities
                    #endregion Users

                    #region Availability Zones
                    #endregion Availability Zones
                }
            }
            #endregion Administration
        }
        #endregion Prism Central
    }
}