#!/usr/bin/env bash

# Universal AutoWinApps Installation Script
# Modular architecture supporting multiple Linux distributions

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
readonly LOG_FILE="$HOME/.cache/winapps-install.log"
readonly CONFIG_FILE="$HOME/.cache/winapps-install.conf"

# Global variables
DETECTED_OS=""
DETECTED_VERSION=""
SELECTED_BACKEND=""
WINDOWS_SETUP_METHOD=""
DRY_RUN=false
VERBOSE=false
SKIP_UPDATES=false

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

print_header() {
    echo -e "\n${BOLD}${BLUE}$1${NC}\n" | tee -a "$LOG_FILE"
}

print_verbose() {
    [[ "$VERBOSE" == true ]] && echo -e "${BLUE}[VERBOSE]${NC} $1" | tee -a "$LOG_FILE"
}

# Function to show progress bar
show_progress() {
    local current=$1
    local total=$2
    local message=$3
    local width=50
    local percentage=$((current * 100 / total))
    local filled=$((current * width / total))
    
    printf "\r${BLUE}[PROGRESS]${NC} $message ["
    printf "%*s" $filled | tr ' ' '█'
    printf "%*s" $((width - filled)) | tr ' ' '░'
    printf "] %d%%" $percentage
    
    if [[ $current -eq $total ]]; then
        echo
    fi
}

# Function to setup logging
setup_logging() {
    mkdir -p "$(dirname "$LOG_FILE")"
    echo "=== AutoWinApps Installation Log - $(date) ===" > "$LOG_FILE"
    print_verbose "Logging enabled: $LOG_FILE"
}

# Integrated Filesystem Detection and Configuration Functions
# Function to detect root filesystem type
detect_root_filesystem() {
    local root_fs=""
    root_fs=$(findmnt -n -o FSTYPE /)
    echo "$root_fs"
}

# Function to detect if ZFS is in use
is_zfs_root() {
    local root_fs=$(detect_root_filesystem)
    [[ "$root_fs" == "zfs" ]]
}

# Function to detect if Btrfs is in use
is_btrfs_root() {
    local root_fs=$(detect_root_filesystem)
    [[ "$root_fs" == "btrfs" ]]
}

# Function to configure filesystem for containers
configure_filesystem_for_containers() {
    local backend="$SELECTED_BACKEND"
    
    print_header "Configuring Filesystem for Containers"
    
    if [[ "$DRY_RUN" == true ]]; then
        print_verbose "DRY RUN: Would configure filesystem for $backend"
        return 0
    fi
    
    local root_fs=$(detect_root_filesystem)
    print_status "Detected root filesystem: $root_fs"
    
    case "$root_fs" in
        "zfs")
            print_status "ZFS detected - applying ZFS-specific configurations"
            configure_containers_for_zfs "$backend"
            ;;
        "btrfs")
            print_status "Btrfs detected - applying Btrfs-specific configurations"
            configure_containers_for_btrfs "$backend"
            ;;
        "ext4"|"ext3"|"ext2"|"xfs")
            print_status "Traditional filesystem detected - using standard configuration"
            ;;
        *)
            print_warning "Unknown filesystem: $root_fs - using standard configuration"
            ;;
    esac
}

# Function to configure containers for ZFS
configure_containers_for_zfs() {
    local backend="$1"
    
    if [[ "$backend" == "docker" ]]; then
        configure_docker_for_zfs
    elif [[ "$backend" == "podman" ]]; then
        configure_podman_for_zfs
    fi
}

# Function to configure containers for Btrfs
configure_containers_for_btrfs() {
    local backend="$1"
    
    if [[ "$backend" == "docker" ]]; then
        configure_docker_for_btrfs
    elif [[ "$backend" == "podman" ]]; then
        configure_podman_for_btrfs
    fi
}

# Function to configure Docker for ZFS
configure_docker_for_zfs() {
    local docker_config_dir="/etc/docker"
    local docker_config_file="$docker_config_dir/daemon.json"
    
    print_status "Configuring Docker for ZFS filesystem..."
    
    sudo mkdir -p "$docker_config_dir"
    
    if [[ -f "$docker_config_file" ]]; then
        sudo cp "$docker_config_file" "${docker_config_file}.backup-$(date +%Y%m%d_%H%M%S)"
    fi
    
    cat << 'EOF' | sudo tee "$docker_config_file" > /dev/null
{
    "storage-driver": "overlay2",
    "storage-opts": [
        "overlay2.override_kernel_check=true"
    ],
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "10m",
        "max-file": "3"
    }
}
EOF
    
    print_success "Docker configured for ZFS"
}

# Function to configure Docker for Btrfs
configure_docker_for_btrfs() {
    local docker_config_dir="/etc/docker"
    local docker_config_file="$docker_config_dir/daemon.json"
    
    print_status "Configuring Docker for Btrfs filesystem..."
    
    sudo mkdir -p "$docker_config_dir"
    
    if [[ -f "$docker_config_file" ]]; then
        sudo cp "$docker_config_file" "${docker_config_file}.backup-$(date +%Y%m%d_%H%M%S)"
    fi
    
    cat << 'EOF' | sudo tee "$docker_config_file" > /dev/null
{
    "storage-driver": "btrfs",
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "10m",
        "max-file": "3"
    }
}
EOF
    
    print_success "Docker configured for Btrfs"
}

# Function to configure Podman for ZFS
configure_podman_for_zfs() {
    local podman_config_dir="$HOME/.config/containers"
    local storage_conf="$podman_config_dir/storage.conf"
    
    print_status "Configuring Podman for ZFS filesystem..."
    
    mkdir -p "$podman_config_dir"
    
    cat << 'EOF' > "$storage_conf"
[storage]
driver = "overlay"
runroot = "/run/containers/storage"
graphroot = "$HOME/.local/share/containers/storage"

[storage.options]
additionalimagestores = []

[storage.options.overlay]
mountopt = "nodev,metacopy=on"
EOF
    
    print_success "Podman configured for ZFS"
}

# Function to configure Podman for Btrfs
configure_podman_for_btrfs() {
    local podman_config_dir="$HOME/.config/containers"
    local storage_conf="$podman_config_dir/storage.conf"
    
    print_status "Configuring Podman for Btrfs filesystem..."
    
    mkdir -p "$podman_config_dir"
    
    cat << 'EOF' > "$storage_conf"
[storage]
driver = "btrfs"
runroot = "/run/containers/storage"
graphroot = "$HOME/.local/share/containers/storage"

[storage.options]
additionalimagestores = []
EOF
    
    print_success "Podman configured for Btrfs"
}

# Function to display filesystem recommendations
show_filesystem_recommendations() {
    local root_fs=$(detect_root_filesystem)
    
    case "$root_fs" in
        "zfs")
            echo "💾 ZFS filesystem detected:"
            echo "   • Optimized Docker/Podman configuration will be applied"
            echo "   • Recommended for high-performance storage"
            ;;
        "btrfs")
            echo "💾 Btrfs filesystem detected:"
            echo "   • Optimized Docker/Podman configuration will be applied"
            echo "   • Snapshot-friendly configuration"
            ;;
        *)
            echo "💾 Standard filesystem detected: $root_fs"
            echo "   • Default container configuration will be used"
            ;;
    esac
}

# Function to save configuration
save_config() {
    cat > "$CONFIG_FILE" << EOF
DETECTED_OS="$DETECTED_OS"
DETECTED_VERSION="$DETECTED_VERSION"
SELECTED_BACKEND="$SELECTED_BACKEND"
WINDOWS_SETUP_METHOD="$WINDOWS_SETUP_METHOD"
INSTALL_TIMESTAMP="$(date -Iseconds)"
EOF
    print_verbose "Configuration saved to $CONFIG_FILE"
}

# Function to load configuration
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
        print_verbose "Previous configuration loaded"
        return 0
    fi
    return 1
}

# Function to show usage
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Universal AutoWinApps installer for multiple Linux distributions.

OPTIONS:
    -h, --help              Show this help message
    -v, --verbose           Enable verbose output
    -d, --dry-run          Preview changes without applying them
    -s, --skip-updates     Skip system package updates
    -r, --resume           Resume previous installation
    -u, --uninstall        Uninstall AutoWinApps
    -t, --test             Run system detection tests only
    --force                Force installation even with warnings

EXAMPLES:
    $0                      # Interactive installation
    $0 --dry-run           # Preview what would be installed
    $0 --test              # Test system detection only
    $0 --verbose           # Detailed output
    $0 --uninstall         # Remove AutoWinApps

SUPPORTED DISTRIBUTIONS:
    - CachyOS
    - Ubuntu 24.04/25.04
    - Linux Mint 22.2
    - Debian 13 (Trixie)

For more information: https://github.com/winapps-org/winapps
EOF
}

# Function to parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -s|--skip-updates)
                SKIP_UPDATES=true
                shift
                ;;
            -r|--resume)
                if load_config; then
                    print_status "Resuming previous installation"
                else
                    print_error "No previous installation found to resume"
                    exit 1
                fi
                shift
                ;;
            -u|--uninstall)
                if [[ -f "$SCRIPT_DIR/uninstall-autowinapps.sh" ]]; then
                    exec "$SCRIPT_DIR/uninstall-autowinapps.sh"
                else
                    print_error "Uninstall script not found"
                    exit 1
                fi
                ;;
            -t|--test)
                run_system_tests
                exit 0
                ;;
            --force)
                export FORCE_INSTALL=true
                shift
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

# Function to detect operating system
detect_os() {
    print_header "Detecting Operating System"
    
    if [[ ! -f /etc/os-release ]]; then
        print_error "Cannot detect operating system - /etc/os-release not found"
        exit 1
    fi
    
    source /etc/os-release
    
    DETECTED_OS="$ID"
    DETECTED_VERSION="${VERSION_ID:-${VERSION:-unknown}}"
    
    print_status "Detected: $NAME ($DETECTED_VERSION)"
    print_verbose "OS ID: $ID, Version: $DETECTED_VERSION"
    
    # Validate supported OS
    case "$DETECTED_OS" in
        "cachyos"|"ubuntu"|"linuxmint"|"debian")
            print_success "Supported operating system detected"
            ;;
        *)
            print_error "Unsupported operating system: $DETECTED_OS"
            print_status "Supported: CachyOS, Ubuntu, Linux Mint, Debian"
            exit 1
            ;;
    esac
}

# Function to load OS-specific module
load_os_module() {
    local module_file="$SCRIPT_DIR/os-modules/${DETECTED_OS}.sh"
    
    print_verbose "Loading OS module: $module_file"
    
    if [[ ! -f "$module_file" ]]; then
        print_error "OS module not found: $module_file"
        exit 1
    fi
    
    source "$module_file"
    print_verbose "OS module loaded successfully"
}

# Function to load core modules
load_core_modules() {
    print_verbose "Loading core modules..."
    
    local core_modules=(
        "core/winapps-core.sh"
        "core/dockur-integration.sh"
        "core/desktop-integration.sh"
        "core/system-validation.sh"
    )
    
    for module in "${core_modules[@]}"; do
        local module_path="$SCRIPT_DIR/$module"
        if [[ -f "$module_path" ]]; then
            source "$module_path"
            print_verbose "Loaded: $module"
        else
            print_warning "Core module not found: $module_path"
        fi
    done
}

# Function to validate system requirements
validate_system() {
    print_header "Validating System Requirements"
    
    local validation_passed=true
    
    # Check available disk space (need at least 10GB)
    local available_space=$(df "$HOME" | awk 'NR==2 {print $4}')
    local required_space=$((10 * 1024 * 1024)) # 10GB in KB
    
    if [[ $available_space -lt $required_space ]]; then
        print_error "Insufficient disk space. Need 10GB, have $(($available_space / 1024 / 1024))GB"
        validation_passed=false
    else
        print_success "Disk space: $(($available_space / 1024 / 1024))GB available"
    fi
    
    # Check memory (need at least 4GB)
    local total_memory=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local required_memory=$((4 * 1024 * 1024)) # 4GB in KB
    
    if [[ $total_memory -lt $required_memory ]]; then
        print_warning "Low memory detected. Need 4GB, have $(($total_memory / 1024 / 1024))GB"
        print_status "Consider reducing VM memory allocation"
    else
        print_success "Memory: $(($total_memory / 1024 / 1024))GB available"
    fi
    
    # Check virtualization support
    if grep -q -E 'vmx|svm' /proc/cpuinfo; then
        print_success "CPU virtualization support detected"
    else
        print_error "CPU virtualization not supported or not enabled in BIOS"
        validation_passed=false
    fi
    
    # Check internet connectivity
    if ping -c 1 google.com &>/dev/null; then
        print_success "Internet connectivity verified"
    else
        print_error "No internet connection detected"
        validation_passed=false
    fi
    
    if [[ "$validation_passed" == false ]] && [[ "${FORCE_INSTALL:-false}" != true ]]; then
        print_error "System validation failed. Use --force to override."
        exit 1
    fi
}

# Function to show welcome screen
show_welcome() {
    clear
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║                          AutoWinApps Universal Installer                     ║
║                                                                              ║
║  Run Windows applications seamlessly on Linux with native desktop           ║
║  integration. Supports automatic Windows installation via dockur/windows.   ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
    echo
    print_status "System: $DETECTED_OS $(detect_root_filesystem) filesystem"
    print_status "Desktop: ${XDG_CURRENT_DESKTOP:-Unknown}"
    echo
}

# Function to choose setup method
choose_setup_method() {
    print_header "Choose Windows Setup Method"
    
    echo "How would you like to set up Windows?"
    echo
    echo "1. ${BOLD}Automatic Setup${NC} (Recommended)"
    echo "   🚀 Uses dockur/windows - downloads Windows automatically"
    echo "   ✅ No ISO file needed"
    echo "   ✅ Web-based installation monitoring"
    echo "   ✅ Pre-configured credentials"
    echo "   ✅ Supports Windows 11, 10, Server versions"
    echo
    echo "2. ${BOLD}Manual Setup${NC}"
    echo "   📁 You provide Windows ISO file"
    echo "   🛠️  Full control over VM configuration"
    echo "   🔧 Traditional virtualization approach"
    echo
    
    while true; do
        read -p "Choose method (1-2, default: 1): " choice
        case "$choice" in
            2)
                WINDOWS_SETUP_METHOD="manual"
                print_status "Selected: Manual setup"
                break
                ;;
            1|"")
                WINDOWS_SETUP_METHOD="dockur"
                print_status "Selected: Automatic dockur/windows setup"
                break
                ;;
            *)
                print_warning "Invalid choice. Please enter 1 or 2."
                ;;
        esac
    done
}

# Function to choose backend
choose_backend() {
    print_header "Choose WinApps Backend"
    
    show_filesystem_recommendations
    echo
    
    if [[ "$WINDOWS_SETUP_METHOD" == "dockur" ]]; then
        echo "Available backends for dockur/windows:"
        echo "1. ${BOLD}Docker${NC} (Recommended)"
        echo "   🐳 Mature container runtime"
        echo "   🚀 Excellent dockur/windows integration"
        echo
        echo "2. ${BOLD}Podman${NC}"
        echo "   🔒 Rootless containers"
        echo "   🛡️  Enhanced security"
        echo
        
        while true; do
            read -p "Choose backend (1-2, default: 1): " choice
            case "$choice" in
                2)
                    SELECTED_BACKEND="podman"
                    break
                    ;;
                1|"")
                    SELECTED_BACKEND="docker"
                    break
                    ;;
                *)
                    print_warning "Invalid choice. Please enter 1 or 2."
                    ;;
            esac
        done
    else
        echo "Available backends for manual setup:"
        echo "1. ${BOLD}libvirt${NC} (Recommended for $(detect_root_filesystem))"
        echo "   🖥️  Full virtual machine"
        echo "   ⚡ Best performance and compatibility"
        echo
        echo "2. ${BOLD}Docker${NC}"
        echo "   🐳 Container-based approach"
        echo "   💾 Lower resource usage"
        echo
        echo "3. ${BOLD}Podman${NC}"
        echo "   🔒 Rootless containers"
        echo "   🛡️  Enhanced security"
        echo
        
        while true; do
            read -p "Choose backend (1-3, default: 1): " choice
            case "$choice" in
                2)
                    SELECTED_BACKEND="docker"
                    break
                    ;;
                3)
                    SELECTED_BACKEND="podman"
                    break
                    ;;
                1|"")
                    SELECTED_BACKEND="libvirt"
                    break
                    ;;
                *)
                    print_warning "Invalid choice. Please enter 1, 2, or 3."
                    ;;
            esac
        done
    fi
    
    print_status "Selected backend: $SELECTED_BACKEND"
}

# Function to show installation summary
show_installation_summary() {
    print_header "Installation Summary"
    
    echo "The following will be installed/configured:"
    echo
    echo "📋 System Information:"
    echo "   • OS: $DETECTED_OS $DETECTED_VERSION"
    echo "   • Filesystem: $(detect_root_filesystem)"
    echo "   • Desktop: ${XDG_CURRENT_DESKTOP:-Unknown}"
    echo
    echo "🚀 Setup Configuration:"
    echo "   • Windows Method: $WINDOWS_SETUP_METHOD"
    echo "   • Backend: $SELECTED_BACKEND"
    echo
    echo "📦 Components to Install:"
    get_required_packages
    echo
    
    if [[ "$DRY_RUN" == true ]]; then
        print_warning "DRY RUN MODE - No changes will be made"
        return 0
    fi
    
    echo "⚠️  This installation will:"
    echo "   • Install system packages with sudo"
    echo "   • Add user to required groups"
    echo "   • Configure container/virtualization services"
    echo "   • Download and setup WinApps"
    if [[ "$WINDOWS_SETUP_METHOD" == "dockur" ]]; then
        echo "   • Download Windows automatically (may take 15-30 minutes)"
    fi
    echo
    
    while true; do
        read -p "Continue with installation? (y/N): " confirm
        case "$confirm" in
            [Yy]*)
                break
                ;;
            [Nn]*|"")
                print_status "Installation cancelled"
                exit 0
                ;;
            *)
                print_warning "Please enter y or n"
                ;;
        esac
    done
}

# Function to run installation
run_installation() {
    print_header "Starting Installation"
    
    local steps=(
        "update_system"
        "install_dependencies" 
        "configure_services"
        "configure_filesystem_for_containers"
        "create_dockur_config"
        "create_winapps_config"
        "setup_winapps"
        "create_management_scripts"
        "configure_desktop_integration"
    )
    
    local current_step=0
    local total_steps=${#steps[@]}
    
    for step in "${steps[@]}"; do
        ((current_step++))
        show_progress $current_step $total_steps "Executing: $step"
        
        if [[ "$DRY_RUN" == true ]]; then
            print_verbose "DRY RUN: Would execute $step"
            sleep 0.5
        else
            if declare -f "$step" >/dev/null; then
                "$step" || {
                    print_error "Failed during: $step"
                    print_status "Check log: $LOG_FILE"
                    exit 1
                }
            else
                print_warning "Function not found: $step"
            fi
        fi
    done
    
    show_progress $total_steps $total_steps "Installation completed"
}

# Function to show completion
show_completion() {
    print_header "🎉 Installation Complete!"
    
    save_config
    
    if [[ "$DRY_RUN" == true ]]; then
        print_success "Dry run completed successfully!"
        print_status "Run without --dry-run to perform actual installation"
        return 0
    fi
    
    echo -e "${GREEN}AutoWinApps successfully installed!${NC}"
    echo
    print_status "Next steps:"
    
    if [[ "$WINDOWS_SETUP_METHOD" == "dockur" ]]; then
        echo "1. ${BOLD}Reboot or log out/in${NC} (for group permissions)"
        echo "2. ${BOLD}~/manage-windows.sh setup${NC} (download & install Windows)"
        echo "3. ${BOLD}http://localhost:8006${NC} (monitor installation)"
        echo "4. Install Windows applications"
        echo "5. ${BOLD}winapps-setup --user${NC} (integrate apps)"
        echo
        echo "🎮 Management Commands:"
        echo "   • ${BOLD}~/manage-windows.sh start${NC} - Start Windows"
        echo "   • ${BOLD}~/manage-windows.sh stop${NC} - Stop Windows"
        echo "   • ${BOLD}~/manage-windows.sh status${NC} - Check status"
    else
        echo "1. ${BOLD}Reboot or log out/in${NC} (for group permissions)"
        echo "2. ${BOLD}~/create-windows-vm.sh${NC} (create Windows VM)"
        echo "3. Install Windows & configure Remote Desktop"
        echo "4. ${BOLD}winapps-setup --user${NC} (integrate apps)"
    fi
    
    echo
    echo "🔧 Utility Commands:"
    echo "   • ${BOLD}winapps-refresh-desktop${NC} - Refresh desktop integration"
    echo "   • ${BOLD}$0 --uninstall${NC} - Remove AutoWinApps"
    echo
    echo "📁 Files Created:"
    echo "   • Configuration: ~/.config/winapps/winapps.conf"
    echo "   • Install log: $LOG_FILE"
    if [[ "$WINDOWS_SETUP_METHOD" == "dockur" ]]; then
        echo "   • Docker config: ~/.config/dockur-windows/docker-compose.yml"
        echo "   • Management: ~/manage-windows.sh"
    else
        echo "   • VM helper: ~/create-windows-vm.sh"
    fi
    echo
    print_status "For help and documentation: https://github.com/winapps-org/winapps"
}

# Function to run system tests
run_system_tests() {
    print_header "🧪 AutoWinApps System Detection Tests"
    
    # Setup logging for tests
    setup_logging
    
    print_status "Running comprehensive system tests..."
    echo
    
    # Test OS detection
    print_header "Operating System Detection"
    detect_os
    print_success "OS: $DETECTED_OS $DETECTED_VERSION"
    echo
    
    # Test filesystem detection
    print_header "Filesystem Detection"
    local root_fs=$(detect_root_filesystem)
    print_status "Root filesystem: $root_fs"
    
    if is_zfs_root; then
        print_success "ZFS filesystem detected"
    elif is_btrfs_root; then
        print_success "Btrfs filesystem detected"
    else
        print_success "Standard filesystem detected"
    fi
    echo
    
    # Test hardware validation
    print_header "Hardware Validation"
    
    # Check CPU architecture
    local arch=$(uname -m)
    print_status "CPU architecture: $arch"
    
    # Check virtualization support
    if grep -q -E 'vmx|svm' /proc/cpuinfo; then
        local virt_type
        if grep -q 'vmx' /proc/cpuinfo; then
            virt_type="Intel VT-x"
        else
            virt_type="AMD-V"
        fi
        print_success "CPU virtualization: $virt_type detected"
    else
        print_error "CPU virtualization not detected"
    fi
    
    # Check memory
    local total_memory_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local total_memory_gb=$((total_memory_kb / 1024 / 1024))
    print_status "Total memory: ${total_memory_gb}GB"
    
    if [[ $total_memory_gb -ge 8 ]]; then
        print_success "Memory: Excellent (${total_memory_gb}GB)"
    elif [[ $total_memory_gb -ge 4 ]]; then
        print_success "Memory: Good (${total_memory_gb}GB)"
    else
        print_warning "Memory: Low (${total_memory_gb}GB) - consider 8GB+"
    fi
    
    # Check disk space
    local home_available_kb=$(df "$HOME" | awk 'NR==2 {print $4}')
    local home_available_gb=$((home_available_kb / 1024 / 1024))
    print_status "Available space in $HOME: ${home_available_gb}GB"
    
    if [[ $home_available_gb -ge 80 ]]; then
        print_success "Disk space: Excellent (${home_available_gb}GB)"
    elif [[ $home_available_gb -ge 50 ]]; then
        print_success "Disk space: Good (${home_available_gb}GB)"
    else
        print_warning "Disk space: Low (${home_available_gb}GB) - consider 80GB+"
    fi
    echo
    
    # Test desktop environment detection  
    print_header "Desktop Environment Detection"
    local desktop_env="${XDG_CURRENT_DESKTOP:-Unknown}"
    print_status "Desktop environment: $desktop_env"
    
    if [[ "$desktop_env" != "Unknown" ]]; then
        print_success "Desktop environment detected and supported"
    else
        print_warning "Desktop environment not detected - manual configuration may be needed"
    fi
    echo
    
    # Test network connectivity
    print_header "Network Connectivity"
    if ping -c 1 -W 5 8.8.8.8 &>/dev/null; then
        print_success "Internet connectivity verified"
    else
        print_error "No internet connectivity detected"
    fi
    echo
    
    # Load and test OS module
    print_header "OS Module Testing"
    local module_file="$SCRIPT_DIR/os-modules/${DETECTED_OS}.sh"
    
    if [[ -f "$module_file" ]]; then
        print_success "OS module found: $module_file"
        source "$module_file"
        
        if declare -f check_os_requirements >/dev/null; then
            print_status "Testing OS-specific requirements..."
            if check_os_requirements; then
                print_success "OS requirements check passed"
            else
                print_error "OS requirements check failed"
            fi
        fi
    else
        print_error "OS module not found: $module_file"
    fi
    echo
    
    # Summary
    print_header "🎯 Test Summary"
    print_success "System detection tests completed!"
    print_status "Review the results above to ensure your system is ready for AutoWinApps"
    print_status "Run 'bash install-winapps.sh --dry-run' to preview the full installation"
    echo
}

# Main function
main() {
    # Parse command line arguments
    parse_arguments "$@"
    
    # Setup logging
    setup_logging
    
    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        print_error "This script should not be run as root"
        exit 1
    fi
    
    # Detect operating system
    detect_os
    
    # Load modules
    load_core_modules
    load_os_module
    
    # Validate system requirements  
    validate_system
    
    # Show welcome screen
    show_welcome
    
    # Get user choices
    choose_setup_method
    choose_backend
    
    # Show installation summary
    show_installation_summary
    
    # Run installation
    run_installation
    
    # Show completion
    show_completion
}

# Run main function
main "$@"