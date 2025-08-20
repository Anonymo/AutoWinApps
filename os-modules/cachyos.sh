#!/usr/bin/env bash

# CachyOS-specific module
# This module contains CachyOS-specific package management and configuration

# Function to check CachyOS-specific requirements
check_os_requirements() {
    print_verbose "Checking CachyOS-specific requirements..."
    
    # Verify this is actually CachyOS
    if [[ "$DETECTED_OS" != "cachyos" ]]; then
        print_error "This module is for CachyOS, detected: $DETECTED_OS"
        return 1
    fi
    
    # Check for pacman
    if ! command -v pacman &>/dev/null; then
        print_error "pacman package manager not found"
        return 1
    fi
    
    print_success "CachyOS environment verified"
    return 0
}

# Function to setup AUR helper
setup_aur_helper() {
    print_status "Setting up AUR helper..."
    
    if command -v yay &>/dev/null; then
        AUR_HELPER="yay"
        print_success "yay already installed"
        return 0
    elif command -v paru &>/dev/null; then
        AUR_HELPER="paru"
        print_success "paru already installed"
        return 0
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        print_verbose "DRY RUN: Would install yay AUR helper"
        AUR_HELPER="yay"
        return 0
    fi
    
    print_status "Installing yay AUR helper..."
    
    # Install build dependencies
    sudo pacman -S --needed --noconfirm base-devel git
    
    # Clone and build yay
    local temp_dir
    temp_dir=$(mktemp -d)
    
    git clone https://aur.archlinux.org/yay.git "$temp_dir/yay"
    cd "$temp_dir/yay"
    makepkg -si --noconfirm
    cd "$SCRIPT_DIR"
    
    # Cleanup
    rm -rf "$temp_dir"
    
    AUR_HELPER="yay"
    print_success "yay installed successfully"
}

# Function to update system packages
update_system() {
    if [[ "$SKIP_UPDATES" == true ]]; then
        print_status "Skipping system updates (--skip-updates specified)"
        return 0
    fi
    
    print_header "Updating System Packages"
    
    if [[ "$DRY_RUN" == true ]]; then
        print_verbose "DRY RUN: Would update system packages"
        return 0
    fi
    
    print_status "Updating package databases..."
    sudo pacman -Sy --noconfirm
    
    print_status "Upgrading installed packages..."
    sudo pacman -Su --noconfirm
    
    print_success "System packages updated"
}

# Function to get required packages based on backend
get_required_packages() {
    local base_packages=(
        "curl"
        "dialog"
        "freerdp"
        "git"
        "iproute2"
        "libnotify"
        "openbsd-netcat"
    )
    
    local backend_packages=()
    
    case "$SELECTED_BACKEND" in
        "libvirt")
            backend_packages=(
                "qemu-desktop"
                "libvirt"
                "virt-manager"
                "edk2-ovmf"
                "bridge-utils"
                "dnsmasq"
                "iptables-nft"
            )
            ;;
        "docker")
            backend_packages=(
                "docker"
                "docker-compose"
            )
            ;;
        "podman")
            backend_packages=(
                "podman"
                "podman-compose"
            )
            ;;
    esac
    
    # Combine arrays
    local all_packages=("${base_packages[@]}" "${backend_packages[@]}")
    
    # Display packages
    echo "📦 Packages to install:"
    printf "   • %s\n" "${all_packages[@]}"
}

# Function to install dependencies
install_dependencies() {
    print_header "Installing Dependencies"
    
    # Setup AUR helper first
    setup_aur_helper
    
    local base_packages=(
        "curl"
        "dialog"
        "freerdp"
        "git"
        "iproute2"
        "libnotify"
        "openbsd-netcat"
    )
    
    local backend_packages=()
    
    case "$SELECTED_BACKEND" in
        "libvirt")
            backend_packages=(
                "qemu-desktop"
                "libvirt"
                "virt-manager"
                "edk2-ovmf"
                "bridge-utils"
                "dnsmasq"
                "iptables-nft"
            )
            ;;
        "docker")
            backend_packages=(
                "docker"
                "docker-compose"
            )
            ;;
        "podman")
            backend_packages=(
                "podman"
                "podman-compose"
            )
            ;;
    esac
    
    local all_packages=("${base_packages[@]}" "${backend_packages[@]}")
    
    if [[ "$DRY_RUN" == true ]]; then
        print_verbose "DRY RUN: Would install ${#all_packages[@]} packages"
        return 0
    fi
    
    print_status "Installing packages with pacman..."
    
    # Install packages with error handling
    if ! sudo pacman -S --needed --noconfirm "${all_packages[@]}"; then
        print_error "Failed to install some packages"
        
        # Try installing packages individually to identify problematic ones
        print_status "Attempting individual package installation..."
        local failed_packages=()
        
        for package in "${all_packages[@]}"; do
            if sudo pacman -S --needed --noconfirm "$package"; then
                print_verbose "✓ Installed: $package"
            else
                print_warning "✗ Failed: $package"
                failed_packages+=("$package")
            fi
        done
        
        if [[ ${#failed_packages[@]} -gt 0 ]]; then
            print_warning "Some packages failed to install: ${failed_packages[*]}"
            print_status "Checking AUR for missing packages..."
            
            # Try AUR for failed packages
            for package in "${failed_packages[@]}"; do
                if $AUR_HELPER -S --noconfirm "$package"; then
                    print_verbose "✓ Installed from AUR: $package"
                else
                    print_error "✗ Failed even from AUR: $package"
                fi
            done
        fi
    else
        print_success "All packages installed successfully"
    fi
}

# Function to configure services based on backend
configure_services() {
    print_header "Configuring Services"
    
    if [[ "$DRY_RUN" == true ]]; then
        print_verbose "DRY RUN: Would configure $SELECTED_BACKEND services"
        return 0
    fi
    
    case "$SELECTED_BACKEND" in
        "libvirt")
            configure_libvirt_services
            ;;
        "docker")
            configure_docker_services
            ;;
        "podman")
            configure_podman_services
            ;;
    esac
}

# Function to configure libvirt services
configure_libvirt_services() {
    print_status "Configuring libvirt services..."
    
    # Add user to required groups
    sudo usermod -aG libvirt,kvm "$USER"
    print_verbose "Added user to libvirt and kvm groups"
    
    # Enable and start libvirt service
    sudo systemctl enable libvirtd.service
    sudo systemctl start libvirtd.service
    
    # Configure default network
    if ! virsh net-list --all | grep -q "default.*active"; then
        print_status "Starting default libvirt network..."
        virsh net-autostart default 2>/dev/null || true
        virsh net-start default 2>/dev/null || true
    fi
    
    # Load KVM modules if not loaded
    if ! lsmod | grep -q "^kvm"; then
        print_status "Loading KVM modules..."
        sudo modprobe kvm
        if grep -q "vmx" /proc/cpuinfo; then
            sudo modprobe kvm-intel
        elif grep -q "svm" /proc/cpuinfo; then
            sudo modprobe kvm-amd
        fi
    fi
    
    print_success "libvirt services configured"
}

# Function to configure Docker services
configure_docker_services() {
    print_status "Configuring Docker services..."
    
    # Add user to docker group
    sudo usermod -aG docker "$USER"
    print_verbose "Added user to docker group"
    
    # Enable and start Docker service
    sudo systemctl enable docker.service
    sudo systemctl start docker.service
    
    # Test Docker installation
    if docker --version &>/dev/null; then
        print_success "Docker configured and running"
    else
        print_warning "Docker may not be properly configured"
    fi
}

# Function to configure Podman services
configure_podman_services() {
    print_status "Configuring Podman services..."
    
    # Enable user services for rootless podman
    systemctl --user enable podman.socket 2>/dev/null || true
    
    # Create podman configuration directory
    mkdir -p "$HOME/.config/containers"
    
    print_success "Podman services configured"
}

# Function to optimize for CachyOS
optimize_for_cachyos() {
    print_header "Applying CachyOS-Specific Optimizations"
    
    if [[ "$DRY_RUN" == true ]]; then
        print_verbose "DRY RUN: Would apply CachyOS optimizations"
        return 0
    fi
    
    # CachyOS-specific kernel optimizations
    print_status "Checking for CachyOS kernel optimizations..."
    
    # Check if using CachyOS kernel
    if uname -r | grep -q "cachyos"; then
        print_success "CachyOS kernel detected - optimizations already applied"
        
        # Additional optimizations for CachyOS kernel
        configure_cachyos_kernel_parameters
    else
        print_warning "Standard kernel detected - consider using CachyOS kernel for better performance"
    fi
    
    # Optimize for gaming/performance (CachyOS focus)
    configure_performance_optimizations
    
    print_success "CachyOS optimizations applied"
}

# Function to configure CachyOS kernel parameters
configure_cachyos_kernel_parameters() {
    print_status "Configuring CachyOS kernel parameters..."
    
    local sysctl_file="/etc/sysctl.d/99-winapps-cachyos.conf"
    
    if [[ ! -f "$sysctl_file" ]]; then
        sudo tee "$sysctl_file" > /dev/null << EOF
# CachyOS WinApps optimizations
# Generated by AutoWinApps installer

# Virtual memory optimizations
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5
vm.swappiness = 10

# Network optimizations
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728

# KVM optimizations
# (Applied automatically by CachyOS kernel)
EOF
        
        print_verbose "Created sysctl configuration: $sysctl_file"
    fi
}

# Function to configure performance optimizations
configure_performance_optimizations() {
    print_status "Configuring performance optimizations..."
    
    # Set CPU governor to performance if available
    if [[ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]]; then
        echo "performance" | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null 2>&1 || true
        print_verbose "Set CPU governor to performance mode"
    fi
    
    # Optimize I/O scheduler for SSDs
    for device in /sys/block/nvme* /sys/block/sd*; do
        if [[ -f "$device/queue/scheduler" ]]; then
            echo "none" | sudo tee "$device/queue/scheduler" >/dev/null 2>&1 || true
        fi
    done
    
    print_verbose "Performance optimizations applied"
}

# Function to check CachyOS-specific features
check_cachyos_features() {
    print_status "Checking CachyOS-specific features..."
    
    # Check for CachyOS repositories
    if grep -q "cachyos" /etc/pacman.conf; then
        print_success "CachyOS repositories configured"
    else
        print_warning "CachyOS repositories not found in pacman.conf"
    fi
    
    # Check for CachyOS kernel
    if uname -r | grep -q "cachyos"; then
        print_success "CachyOS kernel in use"
    else
        print_status "Standard kernel in use"
    fi
    
    # Check for bore scheduler
    if grep -q "BORE\|bore" /proc/version 2>/dev/null; then
        print_success "BORE scheduler detected"
    else
        print_verbose "BORE scheduler not detected"
    fi
}

# Function to handle CachyOS-specific cleanup
cleanup_cachyos() {
    print_verbose "Performing CachyOS-specific cleanup..."
    
    # Clean package cache
    if [[ "$DRY_RUN" != true ]]; then
        sudo pacman -Sc --noconfirm || true
        
        # Clean AUR helper cache
        if command -v "$AUR_HELPER" &>/dev/null; then
            $AUR_HELPER -Sc --noconfirm || true
        fi
    fi
    
    print_verbose "CachyOS cleanup completed"
}

# Initialize CachyOS module
print_verbose "CachyOS module loaded"
check_os_requirements