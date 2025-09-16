# EZ-PS-Automations

A comprehensive collection of PowerShell automation tools designed to streamline Windows system administration, application deployment, and enterprise management tasks. These tools are built to enhance productivity for IT professionals working with SCCM, Intune, and PowerShell Desired State Configuration (DSC).

## 🚀 Overview

This repository provides a suite of enterprise-ready automation tools that simplify complex Windows administration tasks:

- **EZ Extension Installer**: Automated Chrome/Edge browser extension deployment via group policy
- **EZ Intunewin**: Bulk conversion tool for creating Microsoft Intune deployment packages  
- **EZ System Context**: Quick launcher for elevated system-level command prompt access
- **EZ PS Scripts**: Collection of PowerShell utilities for user profile management

## 📋 Tools & Features

### 🔧 EZ Extension Installer
**Purpose**: Automates browser extension deployment across enterprise environments

**Key Features**:
- **Dual Browser Support**: Manages both Chrome and Edge extensions simultaneously
- **Group Policy Integration**: Uses Windows registry policies for forced extension installation
- **ARP Management**: Automatically handles Add/Remove Programs entries for tracking
- **Flexible Operation Modes**: Supports both installation and uninstallation workflows
- **Comprehensive Logging**: Detailed logging with timestamps and error tracking
- **Variable Validation**: Built-in checks to prevent registry corruption

**Use Cases**:
- Enterprise browser extension rollouts
- Compliance-driven extension management
- Automated extension deployment via SCCM/Intune

### 📦 EZ Intunewin (v1)
**Purpose**: Bulk conversion utility for creating Microsoft Intune deployment packages

**Key Features**:
- **Batch Processing**: Converts multiple applications to .intunewin format simultaneously
- **Flexible Configuration**: XML-based configuration for customizable deployment settings
- **Smart Detection**: Automatically detects Deploy-Application.exe in both root and App subdirectories  
- **Output Organization**: Organizes converted packages in structured output directories
- **Verbose Logging**: Optional detailed logging for troubleshooting conversion issues
- **Error Handling**: Robust error handling with retry mechanisms

**Configuration Options** (config.xml):
- Custom parent folder paths for source applications
- Configurable app and output folder naming conventions
- Flexible deployment application naming
- Verbose logging toggle

**Workflow**:
1. Configure settings in `config.xml`
2. Place source applications in designated input folders
3. Run `intunewin3.ps1` for batch conversion
4. Retrieve converted .intunewin files from output directories

### 🔐 EZ System Context
**Purpose**: Simplified launcher for system-level administrative access

**Key Features**:
- **Dual Mode Operation**: Interactive and Silent command prompt modes
- **Automatic Elevation**: Built-in UAC elevation handling
- **PSExec Integration**: Leverages Microsoft PSExec for system context access
- **User-Friendly Interface**: Simple menu-driven selection system
- **Administrative Validation**: Verifies administrative privileges before execution

**Operating Modes**:
- **Interactive Mode** (`-i 1 -s cmd`): Full interactive system command prompt
- **Silent Mode** (`-s cmd`): Background system command prompt execution

**Requirements**:
- PSExec.exe in the same directory as the launcher
- Administrative privileges on the target system

### 📂 EZ PS Scripts
**Purpose**: Specialized PowerShell utilities for user profile and registry management

#### Registry Management Script (`ps_equivalent_rem_each_user_reg.ps1`)
**Features**:
- **Multi-User Registry Operations**: Processes registry changes across all user profiles
- **NTUSER.DAT Manipulation**: Direct registry hive loading and modification
- **Flexible Target Options**: Supports both key deletion and value-specific removal
- **System Account Filtering**: Automatically excludes system and service accounts
- **Cross-Platform Compatibility**: Supports Windows XP through Windows 11
- **Comprehensive Logging**: Detailed operation logging with success/failure tracking
- **Safe Hive Management**: Automatic registry hive loading and unloading with retry logic

**Parameters**:
- `RegistryPath`: Target registry path within user hives
- `ValueName`: Specific registry value to remove (optional)
- `DeleteEntireKey`: Switch to delete entire registry keys vs. individual values

#### File Cleanup Script (`rem_each_user_files.ps1`)
**Features**:
- **Bulk User File Removal**: Removes specified files/folders from all user profiles
- **Silent Operation**: Minimal output for script automation scenarios
- **Error Suppression**: Built-in error handling for missing directories
- **Configurable Targets**: Easy modification for different file/folder targets

## 🛠️ Prerequisites

### System Requirements
- **PowerShell**: Version 5.1 or later
- **Operating System**: Windows 7/Server 2008 R2 or newer
- **Permissions**: Administrative privileges for most operations
- **Additional Tools**: PSExec.exe (for EZ System Context)

### Enterprise Integration
- **SCCM Compatibility**: All scripts support SCCM deployment scenarios
- **Intune Ready**: Tools designed for Microsoft Intune application packaging
- **Group Policy Support**: Registry-based configurations work with GP preferences

## 🚀 Installation & Setup

### Quick Start
```bash
# Clone the repository
git clone https://github.com/MdAsifInIT/EZ-PS-Automations.git

# Navigate to repository directory  
cd EZ-PS-Automations

# Set PowerShell execution policy (if needed)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Tool-Specific Setup

#### EZ Extension Installer
1. Edit the extension automation script variables:
   ```powershell
   $appName = 'YourExtensionName'
   $chromeExtensionId = 'chrome-extension-id'  
   $edgeExtensionId = 'edge-extension-id'
   ```
2. Run with desired action: `.\Extension Automation.ps1 -Action Install`

#### EZ Intunewin  
1. Configure `config.xml` with your specific paths and naming conventions
2. Place source applications in the designated input directory
3. Execute: `.\EZ Intunewin\v1\intunewin3.ps1`

#### EZ System Context
1. Download PSExec.exe and place it in the `EZ System Context` directory
2. Run: `.\EZ System Context\launcher.bat`
3. Select your preferred mode (Interactive/Silent)

## 📖 Usage Examples

### Extension Deployment
```powershell
# Install browser extensions across enterprise
.\Extension Automation.ps1 -Action Install -LogPath "C:\Logs\Extension-Install.log"

# Remove extensions during software retirement
.\Extension Automation.ps1 -Action Uninstall
```

### Bulk Intunewin Conversion
```powershell
# Convert all applications in specified parent directory
.\intunewin3.ps1 -parentFolderPath "C:\Applications\ToConvert"

# Use default config.xml settings
.\intunewin3.ps1
```

### User Profile Registry Cleanup
```powershell
# Remove specific application registry keys from all users
.\ps_equivalent_rem_each_user_reg.ps1 -RegistryPath "SOFTWARE\MyApp" -DeleteEntireKey

# Remove specific registry values across user profiles  
.\ps_equivalent_rem_each_user_reg.ps1 -RegistryPath "SOFTWARE\MyApp\Settings" -ValueName "UserPreference"
```

### File Cleanup Across User Profiles
```powershell
# Remove application files from all user directories
.\rem_each_user_files.ps1
```

## 🔧 Configuration Reference

### EZ Intunewin Config.xml Structure
```xml
<?xml version="1.0" encoding="UTF-8"?>
<Configuration>
  <Settings>
    <Paths>
      <ParentFolderPath>C:\Temp\Package</ParentFolderPath>
      <AppFolderName>App</AppFolderName>
      <OutputFolderName>Intune</OutputFolderName>
    </Paths>
    <Files>
      <DeployApplicationName>Deploy-Application.exe</DeployApplicationName>
      <IntuneWinUtilPath>intunewin.exe</IntuneWinUtilPath>
      <NamingConvention>{FolderName}.intunewin</NamingConvention>
    </Files>
    <Logging>
      <Verbose>true</Verbose>
    </Logging>
  </Settings>
</Configuration>
```

## 🏢 Enterprise Integration

### SCCM Deployment
- Package scripts as SCCM applications
- Use provided exit codes for deployment status tracking
- Leverage configuration files for environment-specific settings

### Microsoft Intune
- Deploy scripts as Win32 applications  
- Use EZ Intunewin for packaging preparation
- Implement detection rules based on registry/file presence

### PowerShell DSC
- Scripts are compatible with DSC resource implementation
- Use for configuration drift remediation
- Integrate with DSC reporting for compliance tracking

## 🛡️ Security Considerations

### Execution Policy
- Scripts require `RemoteSigned` or `Unrestricted` execution policy
- Consider signing scripts for production environments
- Use `Set-ExecutionPolicy` with appropriate scope

### Administrative Privileges  
- Most tools require local administrator rights
- EZ System Context specifically needs elevated permissions
- Registry manipulation tools require administrator access

### Network Security
- Review scripts before deployment in secure environments
- Consider code signing for enterprise distribution
- Test in isolated environments before production deployment

## 🤝 Contributing

Contributions are welcome! Please follow these guidelines:

1. **Fork** the repository
2. **Create** a feature branch (`git checkout -b feature/amazing-feature`)  
3. **Commit** your changes (`git commit -m 'Add amazing feature'`)
4. **Push** to the branch (`git push origin feature/amazing-feature`)
5. **Open** a Pull Request

### Development Standards
- Follow PowerShell best practices and style guidelines
- Include comprehensive error handling and logging
- Document parameters and functions with comment-based help
- Test across different Windows versions when possible

## 📄 License

This project is licensed under the **MIT License**. See the [LICENSE](LICENSE) file for complete details.

## 🔄 Version History

- **Current Version**: Active development with regular updates
- **Focus Areas**: Enhanced error handling, expanded enterprise integration, and improved logging capabilities

## 📞 Support & Resources

### Documentation
- Each tool includes inline documentation and help comments
- Configuration examples provided for common deployment scenarios
- Error codes documented for troubleshooting

### Community  
- **Issues**: Report bugs and request features via GitHub Issues
- **Discussions**: Share usage examples and best practices
- **Wiki**: Additional documentation and advanced usage scenarios

---

**Built for IT Professionals** | **Enterprise Ready** | **Open Source**