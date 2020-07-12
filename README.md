<p align="center">
    <a href="https://www.asbuiltreport.com/" alt="AsBuiltReport"> 
            <img src='https://raw.githubusercontent.com/AsBuiltReport/AsBuiltReport/master/AsBuiltReport.png' width="8%" height="8%" /></a>
</p>
<p align="center">
    <a href="https://www.powershellgallery.com/packages/AsBuiltReport.Nutanix.PrismCentral/" alt="PowerShell Gallery Version">
        <img src="https://img.shields.io/powershellgallery/v/AsBuiltReport.Nutanix.PrismCentral.svg" /></a>
    <a href="https://www.powershellgallery.com/packages/AsBuiltReport.Nutanix.PrismCentral/" alt="PS Gallery Downloads">
        <img src="https://img.shields.io/powershellgallery/dt/AsBuiltReport.Nutanix.PrismCentral.svg" /></a>
    <a href="https://www.powershellgallery.com/packages/AsBuiltReport.Nutanix.PrismCentral/" alt="PS Platform">
        <img src="https://img.shields.io/powershellgallery/p/AsBuiltReport.Nutanix.PrismCentral.svg" /></a>
</p>
<p align="center">
    <a href="https://github.com/AsBuiltReport/AsBuiltReport.Nutanix.PrismCentral/graphs/commit-activity" alt="GitHub Last Commit">
        <img src="https://img.shields.io/github/last-commit/AsBuiltReport/AsBuiltReport.Nutanix.PrismCentral/master.svg" /></a>
    <a href="https://raw.githubusercontent.com/AsBuiltReport/AsBuiltReport.Nutanix.PrismCentral/master/LICENSE" alt="GitHub License">
        <img src="https://img.shields.io/github/license/AsBuiltReport/AsBuiltReport.Nutanix.PrismCentral.svg" /></a>
    <a href="https://github.com/AsBuiltReport/AsBuiltReport.Nutanix.PrismCentral/graphs/contributors" alt="GitHub Contributors">
        <img src="https://img.shields.io/github/contributors/AsBuiltReport/AsBuiltReport.Nutanix.PrismCentral.svg"/></a>
</p>
<p align="center">
    <a href="https://twitter.com/AsBuiltReport" alt="Twitter">
            <img src="https://img.shields.io/twitter/follow/AsBuiltReport.svg?style=social"/></a>
</p>

# Nutanix Prism Central As Built Report

# :beginner: Getting Started
Below are the instructions on how to install, configure and generate a Nutanix Prism Central As Built report.

## :hamburger: Supported Prism Central Versions
The Nutanix Prism Central As Built Report supports the following Prism Central versions;
- PC 5.x

## :wrench: Pre-requisites

### :closed_lock_with_key: Required Privileges
A user with `Prism Central Admin` privileges is required to generate a Nutanix Prism Central As Built Report.

## :package: Module Installation

Open a PowerShell terminal window and install the required modules as follows;
```powershell
install-module AsBuiltReport.Nutanix.PrismCentral
```

## :pencil2: Configuration
The Nutanix Prism Central As Built Report utilises a JSON file to allow configuration of the report. 

A Nutanix Prism Central report configuration file can be generated by executing the following command;
```powershell
New-AsBuiltReportConfig -Report Nutanix.PrismCentral -Path <User specified folder> -Name <Optional> 
```

Executing this command will copy the default Nutanix Prism Central report JSON configuration to a user specified folder. 

All report settings can then be configured via the JSON file.

The following provides information of how to configure each schema within the report's JSON file.

### Report
The **Report** schema provides configuration of the Nutanix Prism report information

| Sub-Schema | Description |
| ---------- | ----------- |
| Filename | The filename of the As Built Report (Optional)<br>If not specified, the filename will be the same as the report name
| Name | The name of the As Built Report
| Version | The report version
| Status | The report release status

### Options
The **Options** schema allows certain options within the report to be toggled on or off

| Sub-Schema | Setting | Default | Description |
| ---------- | ------- | ------- | ----------- |
| ShowCoverPageImage | true / false | true | Toggle to enable/disable the display of the cover page image
| ShowHeaderFooter | true / false | true | Toggle to enable/disable document headers & footers
| ShowTableCaptions | true / false | true | Toggle to enable/disable table captions/numbering

### InfoLevel
The **InfoLevel** schema allows configuration of each section of the report at a granular level. 

There are 3 levels (0-2) of detail granularity for each section as follows;

| Setting | InfoLevel | Description |
| :-----: | --------- | ----------- |
| 0 | Disabled | Does not collect or display any information
| 1 | Enabled / Summary | Provides summarised information for a collection of objects
| 2 | Detailed | Provides detailed information for a collection of objects

The table below outlines the default and maximum **InfoLevel** settings for each section.

| Sub-Schema | Sub-Schema | Default Setting | Maximum Setting |
| ---------- | ---------- | :-------------: | :-------------: |
| PrismCentral 
| | SystemSettings | 1 | 1
| | SmtpServer | 1 | 1
| | SyslogServer | 1 | 1
| | IdentityProviders | 1 | 1
| | DirectoryServices | 1 | 1
| VirtualInfrastructure 
| | VM | 1 | 2 
| | Images | 1 | 1
| | Categories | 1 | 1
| | Networks | 1 | 1
| Policies 
| | NGT | 1 | 1
| | ImagePlacement | 1 | 1
| Hardware
| | Clusters  | 1 | 2
| | Hosts | 1 | 2
| Administration
| | Roles | 1 | 1
| | Users | 1 | 1

### Healthcheck
The **Healthcheck** schema is used to toggle health checks on or off.

#### VM
The **VM** schema is used to configure health checks for virtual machines.

| Sub-Schema | Setting | Default | Description | Highlight |
| ---------- | ------- | ------- | ----------- | --------- |
| PowerState | true / false | true | Highlights VMs which are powered off | ![Warning](https://placehold.it/15/FFE860/000000?text=+) VM is powered off

## :computer: Examples 

```powershell
# Generate a Nutanix Prism Central As Built Report for Nutanix Prism Central instance '172.16.30.110' using specified credentials. Export report to HTML & DOCX formats. Use default report style. Append timestamp to report filename. Save reports to 'C:\Users\Tim\Documents'
PS C:\> New-AsBuiltReport -Report Nutanix.PrismCentral -Target '172.16.30.110' -Username 'admin' -Password 'nutanix/4u' -Format Html,Word -OutputPath 'C:\Users\Tim\Documents' -Timestamp

# Generate a Nutanix Prism Central As Built Report for Nutanix Prism Central instance '172.16.30.110' using specified credentials and report configuration file. Export report to Text, HTML & DOCX formats. Use default report style. Save reports to 'C:\Users\Tim\Documents'. Display verbose messages to the console.
PS C:\> New-AsBuiltReport -Report Nutanix.PrismCentral -Target '172.16.30.110' -Username 'admin' -Password 'nutanix/4u' -Format Text,Html,Word -OutputPath 'C:\Users\Tim\Documents' -Verbose

# Generate a Nutanix Prism Central As Built Report for Nutanix Prism Central instance '172.16.30.110' using stored credentials. Export report to HTML & Text formats. Use default report style. Highlight environment issues within the report. Save reports to 'C:\Users\Tim\Documents'.
PS C:\> $Creds = Get-Credential
PS C:\> New-AsBuiltReport -Report Nutanix.PrismCentral -Target '172.16.30.110' -Credential $Creds -Format Html,Text -OutputPath 'C:\Users\Tim\Documents' -EnableHealthCheck

# Generate a single Nutanix Prism Central As Built Report for Nutanix Prism Central instances '172.16.30.110' and '172.16.30.130' using specified credentials. Report exports to WORD format by default. Apply custom style to the report. Reports are saved to the user profile folder by default.
PS C:\> New-AsBuiltReport -Report Nutanix.PrismCentral -Target '172.16.30.110','172.16.30.130' -Username 'admin' -Password 'nutanix/4u' -StylePath 'C:\Scripts\Styles\MyCustomStyle.ps1'

# Generate a Nutanix Prism Central As Built Report for Nutanix Prism Central instance '172.16.30.110' using specified credentials. Export report to HTML & DOCX formats. Use default report style. Reports are saved to the user profile folder by default. Attach and send reports via e-mail.
PS C:\> New-AsBuiltReport -Report VMware.vSphere -Target '172.16.30.110' -Username 'admin' -Password 'nutanix/4u' -Format Html,Word -OutputPath 'C:\Users\Tim\Documents' -SendEmail
```