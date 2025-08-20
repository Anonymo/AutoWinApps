#!/usr/bin/env bash

# AutoWinApps Uninstallation Script
# This script removes all components installed by the AutoWinApps installation scripts

set -euo pipefail

# ANSI color codes for output formatting
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly BOLD='\033[1m'
readonly NC='\033[0m' # No Color

# Script configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly WINAPPS_CONFIG_DIR="$HOME/.config/winapps"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "\n${BOLD}${BLUE}$1${NC}\n"
}

# Function to detect the current distribution
detect_distribution() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        echo "$ID"
    else
        echo "unknown"
    fi
}

# Function to remove WinApps installation
remove_winapps() {
    print_header "Removing WinApps Installation"
    
    # Try both user and system uninstalls
    if command -v winapps-setup &>/dev/null; then
        print_status "Removing user WinApps installation..."
        winapps-setup --user --uninstall 2>/dev/null || true
        
        print_status "Removing system WinApps installation..."
        sudo winapps-setup --system --uninstall 2>/dev/null || true
    else
        print_warning "winapps-setup not found, manual cleanup will be performed"
    fi
    
    # Manual cleanup
    print_status "Performing manual cleanup..."
    
    # Remove user installations
    rm -rf "$HOME/.local/bin/winapps" 2>/dev/null || true
    rm -rf "$HOME/.local/bin/winapps-setup" 2>/dev/null || true
    rm -rf "$HOME/.local/bin/winapps-src" 2>/dev/null || true
    rm -rf "$HOME/.local/share/winapps" 2>/dev/null || true
    rm -rf "$HOME/.local/bin/windows" 2>/dev/null || true
    rm -rf "$HOME/.local/bin/winapps-kde-integration" 2>/dev/null || true
    
    # Remove desktop files
    find "$HOME/.local/share/applications" -name "*winapps*" -delete 2>/dev/null || true
    find "$HOME/.local/share/applications" -name "windows.desktop" -delete 2>/dev/null || true
    find "$HOME/.local/share/applications" -name "ms-office-protocol-handler.desktop" -delete 2>/dev/null || true
    
    # Remove system installations (requires sudo)
    sudo rm -rf "/usr/local/bin/winapps" 2>/dev/null || true
    sudo rm -rf "/usr/local/bin/winapps-setup" 2>/dev/null || true
    sudo rm -rf "/usr/local/bin/winapps-src" 2>/dev/null || true
    sudo rm -rf "/usr/local/share/winapps" 2>/dev/null || true
    sudo rm -rf "/usr/local/bin/windows" 2>/dev/null || true
    
    # Remove system desktop files
    sudo find "/usr/share/applications" -name "*winapps*" -delete 2>/dev/null || true
    sudo find "/usr/share/applications" -name "windows.desktop" -delete 2>/dev/null || true
    sudo find "/usr/share/applications" -name "ms-office-protocol-handler.desktop" -delete 2>/dev/null || true
    
    print_success "WinApps installation removed"
}

# Function to remove configuration files
remove_configurations() {
    print_header "Removing Configuration Files"
    
    # Ask user if they want to remove configurations
    read -p "Remove WinApps configuration files? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "Removing WinApps configuration..."
        rm -rf "$WINAPPS_CONFIG_DIR" 2>/dev/null || true
        print_success "Configuration files removed"
    else
        print_status "Configuration files preserved"
    fi
}

# Function to remove helper scripts
remove_helper_scripts() {
    print_header "Removing Helper Scripts"
    
    print_status "Removing VM creation helper script..."
    rm -f "$HOME/create-windows-vm.sh" 2>/dev/null || true
    
    print_success "Helper scripts removed"
}

# Function to remove container configurations
remove_container_configs() {
    print_header "Removing Container Configurations"
    
    read -p "Remove Docker/Podman configuration changes made by AutoWinApps? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Restore Docker config backups
        if [[ -d /etc/docker ]]; then
            print_status "Checking for Docker configuration backups..."
            local latest_backup=$(find /etc/docker -name "daemon.json.backup-*" -type f 2>/dev/null | sort | tail -1)
            if [[ -n "$latest_backup" ]]; then
                print_status "Restoring Docker configuration from backup..."
                sudo cp "$latest_backup" /etc/docker/daemon.json
                print_success "Docker configuration restored"
            else
                print_warning "No Docker configuration backup found"
            fi
        fi
        
        # Remove Podman storage configuration
        if [[ -f "$HOME/.config/containers/storage.conf" ]]; then
            print_status "Removing Podman storage configuration..."
            rm -f "$HOME/.config/containers/storage.conf"
            print_success "Podman configuration removed"
        fi
    else
        print_status "Container configurations preserved"
    fi
}

# Function to remove packages (optional)
remove_packages() {
    print_header "Package Removal Options"
    
    local distro=$(detect_distribution)
    
    echo "The following packages were installed for WinApps:"
    case "$distro" in
        "ubuntu"|"debian"|"linuxmint")
            echo "- curl, dialog, freerdp3-x11, git, iproute2, libnotify-bin"
            echo "- netcat-openbsd, qemu-kvm, libvirt-daemon-system, libvirt-clients"
            echo "- bridge-utils, virt-manager, ovmf, whois"
            ;;
        "cachyos"|"arch")
            echo "- curl, dialog, freerdp, git, iproute2, libnotify"
            echo "- openbsd-netcat, qemu-desktop, libvirt, virt-manager"
            echo "- edk2-ovmf, bridge-utils, dnsmasq, iptables-nft"
            ;;
        *)
            echo "- Various packages depending on your distribution"
            ;;
    esac
    
    echo
    read -p "Do you want to remove these packages? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        case "$distro" in
            "ubuntu"|"debian"|"linuxmint")
                print_status "Removing packages with apt..."
                sudo apt remove --purge -y curl dialog freerdp3-x11 git iproute2 libnotify-bin netcat-openbsd qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virt-manager ovmf whois 2>/dev/null || \
                sudo apt remove --purge -y curl dialog freerdp2-x11 git iproute2 libnotify-bin netcat-openbsd qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virt-manager ovmf whois 2>/dev/null || \
                print_warning "Some packages could not be removed (they may not have been installed by this script)"
                sudo apt autoremove -y
                ;;
            "cachyos"|"arch")
                print_status "Removing packages with pacman..."
                sudo pacman -Rns --noconfirm curl dialog freerdp git iproute2 libnotify openbsd-netcat qemu-desktop libvirt virt-manager edk2-ovmf bridge-utils dnsmasq iptables-nft 2>/dev/null || \
                print_warning "Some packages could not be removed (they may not have been installed by this script)"
                ;;
            *)
                print_warning "Automatic package removal not supported for this distribution"
                ;;
        esac
        print_success "Package removal completed"
    else
        print_status "Packages preserved"
    fi
}

# Function to remove user from groups
remove_user_from_groups() {
    print_header "Removing User from Virtualization Groups"
    
    read -p "Remove user from libvirt and kvm groups? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "Removing user from libvirt and kvm groups..."
        sudo gpasswd -d "$USER" libvirt 2>/dev/null || print_warning "User not in libvirt group"
        sudo gpasswd -d "$USER" kvm 2>/dev/null || print_warning "User not in kvm group"
        print_success "User removed from groups"
        print_warning "You need to log out and log back in for group changes to take effect"
    else
        print_status "Group membership preserved"
    fi
}

# Function to stop and disable services
stop_services() {
    print_header "Stopping Virtualization Services"
    
    read -p "Stop and disable libvirt services? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "Stopping libvirt services..."
        sudo systemctl stop libvirtd 2>/dev/null || true
        sudo systemctl disable libvirtd 2>/dev/null || true
        print_success "Services stopped and disabled"
    else
        print_status "Services left running"
    fi
}

# Function to clean up desktop integration
cleanup_desktop_integration() {
    print_header "Cleaning Up Desktop Integration"
    
    # Update desktop database
    if command -v update-desktop-database &>/dev/null; then
        print_status "Updating desktop database..."
        update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
    fi
    
    # KDE-specific cleanup
    if [[ "$XDG_CURRENT_DESKTOP" == *"KDE"* ]] || [[ "$DESKTOP_SESSION" == *"plasma"* ]]; then
        print_status "Refreshing KDE menus..."
        qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.refreshCurrentShell 2>/dev/null || true
        kbuildsycoca5 2>/dev/null || kbuildsycoca6 2>/dev/null || true
    fi
    
    print_success "Desktop integration cleaned up"
}

# Function to show summary
show_summary() {
    print_header "Uninstallation Summary"
    
    echo -e "${GREEN}AutoWinApps uninstallation completed!${NC}"
    echo
    echo "What was removed:"
    echo "- WinApps binaries and scripts"
    echo "- Desktop application entries"
    echo "- Helper scripts"
    echo
    echo "What you may need to do manually:"
    echo "- Remove any Windows VMs you created"
    echo "- Clean up VM disk images in /var/lib/libvirt/images/"
    echo "- Remove any custom ZFS datasets or Btrfs subvolumes created for containers"
    echo
    echo "Configuration files and packages were only removed if you chose to remove them."
}

# Main execution
main() {
    print_header "AutoWinApps Uninstallation Script"
    
    echo "This script will help you remove AutoWinApps and its components."
    echo "You will be prompted before removing each component."
    echo
    read -p "Continue with uninstallation? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Uninstallation cancelled."
        exit 0
    fi
    
    # Remove WinApps
    remove_winapps
    
    # Remove configurations
    remove_configurations
    
    # Remove helper scripts
    remove_helper_scripts
    
    # Remove container configurations
    remove_container_configs
    
    # Stop services
    stop_services
    
    # Remove user from groups
    remove_user_from_groups
    
    # Remove packages
    remove_packages
    
    # Clean up desktop integration
    cleanup_desktop_integration
    
    # Show summary
    show_summary
}

# Run main function
main "$@"