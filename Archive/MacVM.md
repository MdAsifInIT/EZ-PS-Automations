# Virtualizing macOS on Windows/Linux Hosts

A comprehensive guide for running macOS virtual machines on non-Apple hardware.
**Note**: This guide is for educational purposes only.

## Prerequisites

### Hardware Requirements

- CPU: Intel/AMD with virtualization support (VT-x/AMD-V)
- RAM: 16GB minimum recommended
- Storage: 60GB+ SSD space
- GPU: Optional - dedicated GPU for better performance

### Software Requirements

- Windows: VMware Workstation Pro/Player
- Linux: QEMU/KVM with virt-manager
- macOS recovery image

## Setup Instructions

### Windows Setup (VMware)

1. Install VMware Workstation
2. Apply VMware patch:

```powershell
git clone https://github.com/DrDonk/unlocker.git
cd unlocker
.\win-install.cmd
```

3. VM Configuration:
   - OS: macOS
   - CPU: 4+ cores
   - RAM: 8GB minimum
   - Disk: 60GB+ fixed size

### Linux Setup (QEMU/KVM)

1. Base installation:

```bash
sudo apt install qemu-kvm libvirt-daemon-system virt-manager
```

2. Setup OSX-KVM:

```bash
git clone https://github.com/kholia/OSX-KVM.git
cd OSX-KVM
./fetch-macOS.py
```

## Optimization Tips

1. Performance:

   - Use fixed-size disk allocation
   - Enable 3D acceleration
   - Allocate at least 50% of host RAM

2. Troubleshooting:
   - Check BIOS virtualization settings
   - Update VM tools regularly
   - Monitor resource usage

## Common Issues

1. Graphics:

   - Limited acceleration
   - Screen resolution issues
   - Display lag

2. Network/Audio:
   - Intermittent connectivity
   - Audio crackling
   - Bluetooth limitations

## Resources

- Documentation:

  - [VMware Guides](https://docs.vmware.com)
  - [QEMU Documentation](https://www.qemu.org/docs/master)
  - [OpenCore Guide](https://dortania.github.io/OpenCore-Install-Guide/)

- Support:
  - GitHub Issues
  - Community Forums
  - Stack Overflow

## Legal Notice

This project is intended for educational purposes only. Users must comply with
Apple's EULA and applicable laws.

## License

MIT License - See LICENSE file for details
