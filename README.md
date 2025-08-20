# AutoWinApps: Universal Automated Installation System

> **Seamlessly run Windows applications on Linux with automatic setup and native desktop integration**

AutoWinApps is a comprehensive automation system that makes installing and configuring [WinApps](https://github.com/winapps-org/winapps) effortless across multiple Linux distributions. With support for automatic Windows installation via [dockur/windows](https://github.com/dockur/windows), you can get Windows applications running on Linux without manually providing ISO files or complex VM configuration.

## 🚀 Quick Start

```bash
# Clone the repository
git clone https://github.com/Anonymo/AutoWinApps.git
cd AutoWinApps

# Run the universal installer (works in any shell)
bash install-winapps.sh

# Or preview changes first
bash install-winapps.sh --dry-run
```

<details>
<summary><strong>🐚 Shell Compatibility</strong></summary>

Our scripts work in any shell since they use `#!/usr/bin/env bash`. Choose your preferred method:

**Any shell (fish, zsh, bash, etc.):**
```bash
bash install-winapps.sh
```

**Bash/zsh users:**
```bash
./install-winapps.sh
```

**Fish users:**
```fish
bash install-winapps.sh
```

</details>

## ✨ Key Features

- 🎯 **Universal Installation**: Single script works across CachyOS, Ubuntu, Linux Mint, and Debian
- 🐚 **Shell Agnostic**: Works with bash, fish, zsh, and other shells
- 🔄 **Automatic Windows Setup**: Downloads and installs Windows automatically via dockur/windows
- 🖥️ **Universal Desktop Support**: Native integration with KDE, GNOME, XFCE, Cinnamon, MATE, and more
- 🏗️ **Modular Architecture**: OS-specific optimizations with shared core functionality
- 📊 **Progress Tracking**: Visual progress bars and comprehensive logging
- 🔍 **System Validation**: Hardware and software compatibility checking
- 💾 **Filesystem Optimization**: Automatic ZFS/Btrfs container configuration
- 🧪 **Dry Run Mode**: Preview changes before applying them

<details>
<summary><strong>📋 Supported Distributions</strong></summary>

### Officially Supported
- **CachyOS** - Full support with AUR helpers and performance optimizations (fish/zsh compatible)
- **Ubuntu 24.04/25.04** - Modern Ubuntu with AppArmor integration
- **Linux Mint 22.2** - Edition-specific optimizations (Cinnamon/MATE/XFCE)
- **Debian 13 (Trixie)** - Latest Debian with proper repository management

### Features by Distribution
- **CachyOS**: AUR integration, performance tuning, kernel optimizations
- **Ubuntu**: AppArmor configuration, repository management, snap integration
- **Linux Mint**: Edition detection, desktop environment optimizations
- **Debian**: Backports support, contrib/non-free repositories

</details>

<details>
<summary><strong>🛠️ Installation Options</strong></summary>

### Command Line Options
```bash
bash install-winapps.sh [OPTIONS]

OPTIONS:
    -h, --help              Show help message
    -v, --verbose           Enable verbose output
    -d, --dry-run          Preview changes without applying them
    -s, --skip-updates     Skip system package updates
    -r, --resume           Resume previous installation
    -u, --uninstall        Uninstall AutoWinApps
    --force                Force installation even with warnings
```

### Examples
```bash
# Interactive installation with progress tracking
bash install-winapps.sh

# Verbose installation with detailed output
bash install-winapps.sh --verbose

# Preview what would be installed
bash install-winapps.sh --dry-run

# Quick installation skipping system updates
bash install-winapps.sh --skip-updates

# Complete removal
bash install-winapps.sh --uninstall
```

</details>

<details>
<summary><strong>🎮 Windows Setup Methods</strong></summary>

### Method 1: Automatic Setup (Recommended) 
**Uses dockur/windows to download Windows automatically**
- No Windows ISO file needed
- Downloads Windows 11 automatically 
- Web interface at http://localhost:8006 to monitor installation
- Works with Docker or Podman

### Method 2: Manual Setup
**You provide your own Windows ISO file**
- Full control over Windows version
- Traditional VM approach using libvirt/QEMU
- More complex but flexible

### Container Backends
- **Docker**: Mature, well-tested (recommended for most users)
- **Podman**: Rootless containers, enhanced security
- **libvirt**: Traditional VMs (manual setup only)

</details>

## 📖 About WinApps

<details>
<summary><strong>🔍 What is WinApps?</strong></summary>

WinApps is an innovative open-source project that allows you to run Windows applications seamlessly on GNU/Linux systems. Instead of running Windows in a separate window, WinApps integrates Windows applications directly into your Linux desktop environment.

### How WinApps Works
1. **Virtual Machine**: Runs Windows in a VM (Docker, Podman, or libvirt)
2. **Application Scanning**: Detects installed Windows applications
3. **Desktop Integration**: Creates native Linux shortcuts and menu entries
4. **Remote Rendering**: Uses FreeRDP to display Windows apps as native Linux windows

### Key Capabilities
- **Native Integration**: Windows apps appear in your Linux application menu
- **File System Access**: Windows can access your Linux home directory
- **Multi-Desktop Support**: Works with KDE, GNOME, XFCE, Cinnamon, MATE, and more
- **Office Integration**: Seamless Microsoft Office document handling

</details>

<details>
<summary><strong>📱 Supported Applications</strong></summary>

WinApps officially supports hundreds of Windows applications, including:

### Microsoft Office Suite
- Word, Excel, PowerPoint, Outlook
- Microsoft Project, Visio
- Microsoft Teams

### Adobe Creative Cloud
- Photoshop, Illustrator, InDesign
- Premiere Pro, After Effects
- Acrobat Professional

### Development Tools
- Visual Studio, Visual Studio Code
- JetBrains IDEs
- Various Windows-specific development tools

### Gaming and Entertainment
- Steam (Windows games)
- Origin, Epic Games Store
- Media creation tools

### Professional Software
- CAD applications
- Accounting software
- Industry-specific tools

</details>

## 🏗️ Architecture

<details>
<summary><strong>📁 Project Structure</strong></summary>

```
AutoWinApps/
├── install-winapps.sh              # Universal installer (single entry point)
├── uninstall-autowinapps.sh        # Comprehensive uninstaller
├── filesystem-utils.sh             # Filesystem detection and optimization
├── test-cachyos-detection.sh       # Testing utility
├── core/                           # Core functionality modules
│   ├── winapps-core.sh            # WinApps setup and configuration
│   ├── dockur-integration.sh      # Automatic Windows installation
│   ├── desktop-integration.sh     # Universal desktop environment support
│   └── system-validation.sh       # Comprehensive system checking
└── os-modules/                     # Distribution-specific modules
    ├── cachyos.sh                 # CachyOS with AUR and performance tuning
    ├── ubuntu.sh                  # Ubuntu with AppArmor and repository management
    ├── debian.sh                  # Debian with backports and contrib/non-free
    └── linuxmint.sh               # Linux Mint with edition-specific optimizations
```

</details>

<details>
<summary><strong>🔧 Modular Design</strong></summary>

### Core Modules
- **winapps-core.sh**: Main WinApps installation and configuration logic
- **dockur-integration.sh**: Automatic Windows downloading and setup
- **desktop-integration.sh**: Universal desktop environment detection and integration
- **system-validation.sh**: Comprehensive hardware and software validation

### OS-Specific Modules
Each distribution has a dedicated module that provides:
- Package management (pacman, apt, etc.)
- Service configuration
- Performance optimizations
- Desktop environment integration
- Distribution-specific features

### Filesystem Utilities
- Automatic filesystem detection (ZFS, Btrfs, ext4)
- Container storage driver optimization
- Dataset/subvolume creation and management

</details>

## 🚀 Getting Started

<details>
<summary><strong>⚡ Quick Setup Guide</strong></summary>

### 1. System Requirements
- **CPU**: x86_64 with virtualization support (Intel VT-x or AMD-V)
- **Memory**: 8GB RAM recommended (4GB minimum)
- **Storage**: 50GB available space (80GB recommended)
- **Network**: Internet connection for downloads

### 2. Installation
```bash
# Clone the repository
git clone https://github.com/Anonymo/AutoWinApps.git
cd AutoWinApps

# Make scripts executable (if needed)
chmod +x *.sh

# Run installation (shell-agnostic)
bash install-winapps.sh
```

### 3. Setup Process
1. **System Detection**: Automatically detects your Linux distribution
2. **Backend Selection**: Choose between Docker, Podman, or libvirt
3. **Windows Method**: Select automatic (dockur) or manual setup
4. **Installation**: Automated package installation and configuration
5. **Windows Setup**: Download and install Windows (if using dockur)

### 4. Post-Installation

**For Automatic Setup (dockur method):**
```bash
# Reboot or log out/in for group permissions
sudo reboot

# Download and install Windows automatically
~/manage-windows.sh setup

# Start Windows
~/manage-windows.sh start

# Monitor installation progress
firefox http://localhost:8006

# Once Windows is installed, install your applications in the VM
# Then integrate them with Linux
winapps-setup --user
```

**For Manual Setup:**
```bash
# Reboot or log out/in for group permissions  
sudo reboot

# Create Windows VM with your ISO
~/create-windows-vm.sh

# Install Windows manually, enable Remote Desktop
# Configure credentials in ~/.config/winapps/winapps.conf
# Then integrate applications
winapps-setup --user
```

</details>

<details>
<summary><strong>🔧 Advanced Configuration</strong></summary>

### Filesystem Optimization
AutoWinApps automatically detects and optimizes for your filesystem:

- **ZFS**: Configures Docker with ZFS storage driver
- **Btrfs**: Creates optimized subvolumes for containers
- **ext4/xfs**: Standard configuration with performance tuning

### Desktop Environment Integration
Supports all major desktop environments with native integration:

- **KDE Plasma**: Taskbar integration, KRunner search, Activity support
- **GNOME**: Activities overview, search integration, dock support
- **XFCE**: Whisker menu, panel launcher integration
- **Cinnamon**: Menu integration, panel support
- **MATE**: Panel integration, menu support
- **Others**: Generic integration with fallback methods

### Performance Tuning
Each OS module includes distribution-specific optimizations:

- **CachyOS**: Kernel parameter tuning, CPU governor optimization
- **Ubuntu**: AppArmor configuration, systemd optimizations
- **Linux Mint**: Edition-specific desktop optimizations
- **Debian**: Swap optimization, network tuning

</details>

## 🛠️ Management and Maintenance

<details>
<summary><strong>📊 System Management</strong></summary>

### Windows Management (dockur method)
```bash
# Start Windows
~/manage-windows.sh start

# Stop Windows
~/manage-windows.sh stop

# Check status
~/manage-windows.sh status

# Setup initial Windows installation
~/manage-windows.sh setup

# Monitor installation
firefox http://localhost:8006
```

### Desktop Integration Management
```bash
# Refresh desktop integration
winapps-refresh-desktop

# Setup user applications
winapps-setup --user

# List integrated applications
winapps-list
```

### System Maintenance
```bash
# Check system status
systemctl status docker
systemctl status libvirtd

# View logs
tail -f ~/.cache/winapps-install.log

# Update WinApps configuration
winapps-setup --user --force
```

</details>

<details>
<summary><strong>🔍 Troubleshooting</strong></summary>

### Common Issues

#### Installation Problems
```bash
# Check system requirements
./install-winapps.sh --dry-run

# Force installation despite warnings
./install-winapps.sh --force

# Verbose installation for debugging
./install-winapps.sh --verbose
```

#### Permission Issues
```bash
# Add user to required groups
sudo usermod -aG docker,libvirt,kvm $USER

# Log out and back in, or reboot
sudo reboot
```

#### Container Issues
```bash
# Check Docker status
sudo systemctl status docker

# Check container logs
docker logs dockur-windows

# Restart services
sudo systemctl restart docker
```

#### Application Integration Issues
```bash
# Refresh desktop database
winapps-refresh-desktop

# Recreate application shortcuts
winapps-setup --user --force

# Check WinApps configuration
cat ~/.config/winapps/winapps.conf
```

### Log Files
- Installation log: `~/.cache/winapps-install.log`
- System report: `~/.cache/winapps-system-report.txt`
- Configuration: `~/.config/winapps/winapps.conf`

</details>

## 🗑️ Uninstallation

<details>
<summary><strong>🧹 Complete Removal</strong></summary>

### Automatic Uninstallation
```bash
# Run the uninstaller
./install-winapps.sh --uninstall

# Or use the dedicated uninstaller
./uninstall-autowinapps.sh
```

### Manual Cleanup (if needed)
```bash
# Remove containers
docker stop dockur-windows
docker rm dockur-windows

# Remove user from groups
sudo deluser $USER docker
sudo deluser $USER libvirt

# Remove configuration files
rm -rf ~/.config/winapps
rm -rf ~/.config/dockur-windows
rm -f ~/.cache/winapps-*

# Remove desktop files
rm -f ~/.local/share/applications/winapps-*
```

</details>

## 📚 Project History and Development

<details>
<summary><strong>🏛️ Background and Origins</strong></summary>

### WinApps Project
AutoWinApps is built upon the excellent [WinApps](https://github.com/winapps-org/winapps) project, which revolutionized running Windows applications on Linux by providing seamless desktop integration. The original WinApps project:

- Created by [Fmstrat](https://github.com/Fmstrat) and the WinApps community
- Introduced the concept of native Windows app integration on Linux
- Supports hundreds of Windows applications
- Works across multiple Linux desktop environments

### dockur/windows Integration
AutoWinApps integrates with [dockur/windows](https://github.com/dockur/windows), an innovative project that:

- Provides automatic Windows downloading and installation
- Eliminates the need for manual ISO file management
- Offers web-based installation monitoring
- Supports multiple Windows versions

### AutoWinApps Development
This automation project addresses the complexity of setting up WinApps across different Linux distributions by:

- Creating a universal installation system
- Providing distribution-specific optimizations
- Automating the entire setup process
- Adding comprehensive system validation

</details>

<details>
<summary><strong>🔄 Version History</strong></summary>

### Current Version: 2.0.0
- **Universal Installer**: Single script for all supported distributions
- **Modular Architecture**: OS-specific modules with shared core
- **Automatic Windows Setup**: dockur/windows integration
- **Universal Desktop Support**: All major desktop environments
- **Comprehensive Validation**: Hardware and software checking
- **Filesystem Optimization**: ZFS/Btrfs support

### Previous Versions
- **1.x**: Individual distribution scripts
- **0.x**: Initial proof-of-concept implementations

### Future Roadmap
- Support for additional Linux distributions
- Enhanced container backends
- Improved application detection
- Advanced automation features

</details>

## 🤝 Contributing

<details>
<summary><strong>🛠️ Development</strong></summary>

### Getting Involved
Contributions are welcome! Here's how you can help:

1. **Bug Reports**: Report issues with specific distributions or configurations
2. **Feature Requests**: Suggest improvements or new distribution support
3. **Code Contributions**: Submit pull requests for enhancements
4. **Documentation**: Improve README, guides, and code comments
5. **Testing**: Test on different distributions and hardware configurations

### Development Setup
```bash
# Fork the repository
git clone https://github.com/YOUR_USERNAME/AutoWinApps.git
cd AutoWinApps

# Test your changes (works in any shell)
bash install-winapps.sh --dry-run

# Run on test systems
bash install-winapps.sh --verbose
```

### Coding Standards
- Follow existing bash scripting conventions
- Add comprehensive error handling
- Include verbose logging for debugging
- Test on all supported distributions
- Update documentation for new features

</details>

## 📄 License and Credits

<details>
<summary><strong>⚖️ Legal Information</strong></summary>

### License
This project is licensed under the GPL-3.0 License - see the original [WinApps license](https://github.com/winapps-org/winapps/blob/main/LICENSE) for details.

### Credits and Acknowledgments
- **WinApps Team**: Original WinApps project and concept
- **dockur/windows**: Automatic Windows installation system
- **Linux Community**: Distribution maintainers and package developers
- **Contributors**: All users who have contributed code, testing, and feedback

### Third-Party Components
- **FreeRDP**: Remote desktop protocol implementation
- **Docker/Podman**: Container runtime environments
- **libvirt**: Virtualization management
- **Various Linux Distributions**: Package managers and system tools

</details>

---

**For questions, issues, or contributions, visit the [GitHub repository](https://github.com/Anonymo/AutoWinApps) or check out the original [WinApps project](https://github.com/winapps-org/winapps).**