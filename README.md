# EZ-PS-Automations

## Overview

This repository hosts two main tools:

- **Bulk Intunewin Conversion Tool**: Automates the conversion of multiple files into the `.intunewin` format for Microsoft Intune deployments.
- **Auto System Context**: Provides a simple launcher to run commands in the system context with interactive or silent modes.

## Features

- **Bulk Intunewin Conversion Tool**: Batch converts files to `.intunewin` format for streamlined Intune deployments.
- **Auto System Context**: Easily run scripts or commands in the system context, interactively or silently.

## Prerequisites

- PowerShell 5.1 or later
- Administrative privileges for certain scripts
- Required dependencies (e.g., `psexec.exe`) must be present in the appropriate directories

## Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/MdAsifInIT/EZ-PS-Automations.git
   ```
2. Change to the repository directory:
   ```bash
   cd c:\Code\EZ-PS-Automations
   ```

## Usage

### Bulk Intunewin Conversion Tool

1. Configure settings in `Easy Intunewin\v1\config.xml`.
2. Place the files to be converted in the input folder specified in the configuration.
3. Run the conversion script:
   ```powershell
   .\Easy Intunewin\v1\intunewin3.ps1
   ```
4. The converted `.intunewin` files will be created in the output folder specified in the configuration.

### Auto System Context

1. Run the launcher script:
   ```bat
   .\Easy System Context\launcher.bat
   ```
2. Choose Interactive or Silent mode as prompted.

## Contributing

Contributions are welcome! Fork the repository and submit a pull request with your improvements.

## License

This project is licensed under the MIT License. See the `LICENSE` file for details.
