# PowerShell Utilities

## Overview

This repository hosts two main tools:

- **Bulk Intunewin Conversion Tool**: Automates the conversion of multiple files into the `.intunewin` format for Microsoft Intune deployments.
- **Auto System Context**: Provides a simple launcher to run commands in the system context with interactive or silent modes.

## Features

- **Bulk Intunewin Conversion Tool**: Automates the conversion of multiple files into `.intunewin` format for Microsoft Intune deployments.
- **Auto System Context**: Simplifies running scripts or commands in the system context without manual intervention.

## Prerequisites

- PowerShell 5.1 or later
- Administrative privileges for certain scripts
- Required dependencies (e.g., psexec.exe) must be present in the appropriate directories

## Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/your-username/PowerShell-Utilities.git
   ```
2. Change to the repository directory:
   ```bash
   cd C:\Users\Asif\Documents\Code\PowerShell-Utilities
   ```

## Usage

### Bulk Intunewin Conversion Tool

1. Configure settings in `Easy Intunewin\v1\config.xml`.
2. Place the files to be converted in the designated input folder (refer to the configuration).
3. Run the conversion script:
   ```powershell
   .\Easy Intunewin\v1\intunewin3.ps1
   ```
4. The converted `.intunewin` files will be created in the specified output folder.

### Auto System Context

1. Execute the launcher script:
   ```bat
   .\Easy System Context\launcher.bat
   ```
2. Follow the on-screen prompts to select either Interactive or Silent mode.

## Contributing

Contributions are welcome! Fork the repository and submit a pull request with improvements.

## License

This project is licensed under the MIT License. See the `LICENSE` file for details.
