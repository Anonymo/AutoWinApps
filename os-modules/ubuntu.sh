#!/usr/bin/env bash

# Ubuntu-specific module
# This module contains Ubuntu-specific package management and configuration

# Function to check Ubuntu-specific requirements
check_os_requirements() {
    print_verbose "Checking Ubuntu-specific requirements..."
    
    # Verify this is actually Ubuntu
    if [[ "$DETECTED_OS" != "ubuntu" ]]; then
        print_error "This module is for Ubuntu, detected: $DETECTED_OS"
        return 1
    fi
    
    # Check for apt
    if ! command -v apt &>/dev/null; then
        print_error "apt package manager not found"
        return 1
    fi
    
    # Check Ubuntu version
    local version_major
    version_major=$(echo "$DETECTED_VERSION" | cut -d. -f1)
    
    if [[ "$version_major" -lt 20 ]]; then
        print_warning "Ubuntu version $DETECTED_VERSION is quite old. Consider upgrading."
    elif [[ "$version_major" -ge 24 ]]; then
        print_success "Modern Ubuntu version detected"
    else
        print_status "Ubuntu version $DETECTED_VERSION is supported"
    fi
    
    print_success "Ubuntu environment verified"
    return 0
}

# Function to enable required repositories
enable_repositories() {
    print_status "Checking repository configuration..."
    
    if [[ "$DRY_RUN" == true ]]; then
        print_verbose "DRY RUN: Would check and enable repositories"
        return 0
    fi
    
    # Check if universe repository is enabled
    if ! grep -q "^deb.*universe" /etc/apt/sources.list /etc/apt/sources.list.d/* 2>/dev/null; then
        print_status "Enabling universe repository..."
        sudo add-apt-repository universe -y
    else
        print_verbose "Universe repository already enabled"
    fi
    
    # For Ubuntu 24.04+, check if we need backports for FreeRDP3
    local version_major
    version_major=$(echo "$DETECTED_VERSION" | cut -d. -f1)
    
    if [[ "$version_major" -ge 24 ]]; then
        print_verbose "Ubuntu 24.04+ detected - FreeRDP3 should be available"
    else
        print_status "Checking for FreeRDP3 availability..."
        if ! apt-cache show freerdp3-x11 &>/dev/null; then
            print_warning "FreeRDP3 not available. Will use FreeRDP2 or enable backports."
            
            # Try to enable backports for older versions
            local codename
            codename=$(lsb_release -sc 2>/dev/null || echo "unknown")
            
            if [[ "$codename" != "unknown" ]]; then
                echo "deb http://archive.ubuntu.com/ubuntu $codename-backports main universe" | \
                    sudo tee /etc/apt/sources.list.d/ubuntu-backports.list > /dev/null
                print_status "Enabled backports repository"
            fi
        fi
    fi
    
    print_success "Repository configuration verified"
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
    
    print_status "Updating package lists..."
    sudo apt update
    
    print_status "Upgrading installed packages..."
    # Use DEBIAN_FRONTEND=noninteractive to avoid prompts
    DEBIAN_FRONTEND=noninteractive sudo apt upgrade -y
    
    print_success "System packages updated"
}

# Function to get required packages based on backend
get_required_packages() {
    local base_packages=(
        "curl"
        "dialog"
        "git"
        "iproute2"
        "libnotify-bin"
        "netcat-openbsd"
        "whois"
    )
    
    # Try to determine best FreeRDP package
    local freerdp_package="freerdp2-x11"
    if apt-cache show freerdp3-x11 &>/dev/null; then
        freerdp_package="freerdp3-x11"
    fi
    base_packages+=("$freerdp_package")
    
    local backend_packages=()
    
    case "$SELECTED_BACKEND" in
        "libvirt")
            backend_packages=(
                "qemu-kvm"
                "libvirt-daemon-system"
                "libvirt-clients"
                "bridge-utils"
                "virt-manager"
                "ovmf"
            )
            ;;
        "docker")
            backend_packages=(
                "docker.io"
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
    
    # Enable repositories first
    enable_repositories
    
    # Update package cache after repository changes
    if [[ "$DRY_RUN" != true ]]; then
        sudo apt update
    fi
    
    local base_packages=(
        "curl"
        "dialog"
        "git"
        "iproute2"
        "libnotify-bin"
        "netcat-openbsd"
        "whois"
    )
    
    # Determine best FreeRDP package
    local freerdp_package=""
    if [[ "$DRY_RUN" == true ]]; then
        freerdp_package="freerdp3-x11"
        print_verbose "DRY RUN: Would use freerdp3-x11"
    else
        if apt-cache show freerdp3-x11 &>/dev/null; then
            freerdp_package="freerdp3-x11"
            print_status "Using FreeRDP3"
        else
            freerdp_package="freerdp2-x11"
            print_warning "FreeRDP3 not available, using FreeRDP2"
        fi
    fi
    base_packages+=("$freerdp_package")
    
    local backend_packages=()
    
    case "$SELECTED_BACKEND" in
        "libvirt")
            backend_packages=(
                "qemu-kvm"
                "libvirt-daemon-system"
                "libvirt-clients"
                "bridge-utils"
                "virt-manager"
                "ovmf"
            )
            ;;
        "docker")
            backend_packages=(
                "docker.io"
                "docker-compose"
            )
            ;;
        "podman")
            # Check if podman is available (newer Ubuntu versions)
            if [[ "$DRY_RUN" == true ]] || apt-cache show podman &>/dev/null; then
                backend_packages=(
                    "podman"
                    "podman-compose"
                )
            else
                print_warning "Podman not available in repositories. Installing from alternative sources..."
                backend_packages=(
                    "containers-common"
                    "crun"
                )
                # We'll install podman via other means
            fi
            ;;
    esac
    
    local all_packages=("${base_packages[@]}" "${backend_packages[@]}")
    
    if [[ "$DRY_RUN" == true ]]; then
        print_verbose "DRY RUN: Would install ${#all_packages[@]} packages"
        return 0
    fi
    
    print_status "Installing packages with apt..."
    
    # Install packages with error handling
    if ! DEBIAN_FRONTEND=noninteractive sudo apt install -y "${all_packages[@]}"; then
        print_warning "Some packages failed to install, attempting individual installation..."
        
        local failed_packages=()
        for package in "${all_packages[@]}"; do
            if DEBIAN_FRONTEND=noninteractive sudo apt install -y "$package"; then
                print_verbose "✓ Installed: $package"
            else
                print_warning "✗ Failed: $package"
                failed_packages+=("$package")
            fi
        done
        
        if [[ ${#failed_packages[@]} -gt 0 ]]; then
            print_warning "Failed packages: ${failed_packages[*]}"
            # Try alternative installation methods for critical packages
            install_alternative_packages "${failed_packages[@]}"
        fi
    else
        print_success "All packages installed successfully"
    fi
    
    # Special handling for podman if it wasn't available
    if [[ "$SELECTED_BACKEND" == "podman" ]] && ! command -v podman &>/dev/null; then
        install_podman_alternative
    fi
}

# Function to install alternative packages
install_alternative_packages() {
    local failed_packages=("$@")
    
    for package in "${failed_packages[@]}"; do
        case "$package" in
            "freerdp3-x11")
                print_status "Attempting to install FreeRDP3 from alternative source..."
                if DEBIAN_FRONTEND=noninteractive sudo apt install -y freerdp2-x11; then
                    print_success "Installed FreeRDP2 as fallback"
                else
                    print_error "Failed to install any FreeRDP version"
                fi
                ;;
            "podman"|"podman-compose")
                print_status "Will install podman from alternative source..."
                ;;
            *)
                print_warning "No alternative available for: $package"
                ;;
        esac
    done
}

# Function to install podman from alternative source
install_podman_alternative() {
    print_status "Installing Podman from alternative source..."
    
    # Add kubic repository for older Ubuntu versions
    local version_major
    version_major=$(echo "$DETECTED_VERSION" | cut -d. -f1)
    
    if [[ "$version_major" -lt 22 ]]; then
        . /etc/os-release
        curl -fsSL https://download.opensuse.org/repositories/devel:kubic:libcontainers:stable/xUbuntu_${VERSION_ID}/Release.key | \
            sudo gpg --dearmor -o /etc/apt/keyrings/devel_kubic_libcontainers_stable.gpg
        
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/devel_kubic_libcontainers_stable.gpg] \
            https://download.opensuse.org/repositories/devel:kubic:libcontainers:stable/xUbuntu_${VERSION_ID}/ /" | \
            sudo tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list > /dev/null
        
        sudo apt update
        sudo apt install -y podman
        
        # Install podman-compose via pip
        if command -v pip3 &>/dev/null; then
            pip3 install --user podman-compose
        fi
        
        print_success "Podman installed from kubic repository"
    else
        print_error "Podman installation failed and no alternative available"
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

# Function to optimize for Ubuntu
optimize_for_ubuntu() {
    print_header "Applying Ubuntu-Specific Optimizations"
    
    if [[ "$DRY_RUN" == true ]]; then
        print_verbose "DRY RUN: Would apply Ubuntu optimizations"
        return 0
    fi
    
    # Ubuntu-specific optimizations
    print_status "Applying Ubuntu optimizations..."
    
    # Configure AppArmor for better container support
    configure_apparmor_optimizations
    
    # Optimize systemd settings
    configure_systemd_optimizations
    
    # Configure swap settings for better VM performance
    configure_swap_optimizations
    
    print_success "Ubuntu optimizations applied"
}

# Function to configure AppArmor optimizations
configure_apparmor_optimizations() {
    if systemctl is-active --quiet apparmor; then
        print_status "Configuring AppArmor for container support..."
        
        # Create AppArmor profile for containers if needed
        local apparmor_dir="/etc/apparmor.d"
        if [[ -d "$apparmor_dir" ]] && [[ ! -f "$apparmor_dir/containers" ]]; then
            sudo tee "$apparmor_dir/containers" > /dev/null << 'EOF'
# AppArmor profile for container support
# Generated by AutoWinApps installer

profile containers flags=(attach_disconnected,mediate_deleted) {
  #include <abstractions/base>
  
  capability,
  file,
  umount,
  
  deny @{PROC}/* w,
  deny /sys/[^f]** wklx,
  deny /sys/f[^s]** wklx,
  deny /sys/fs/[^c]** wklx,
  deny /sys/fs/c[^g]** wklx,
  deny /sys/fs/cg[^r]** wklx,
  deny /sys/firmware/** rwklx,
  deny /sys/kernel/security/** rwklx,
}
EOF
            sudo apparmor_parser -r "$apparmor_dir/containers" 2>/dev/null || true
            print_verbose "Created AppArmor container profile"
        fi
    fi
}

# Function to configure systemd optimizations
configure_systemd_optimizations() {
    print_status "Configuring systemd optimizations..."
    
    # Create systemd user configuration for better service management
    local systemd_user_dir="$HOME/.config/systemd/user"
    mkdir -p "$systemd_user_dir"
    
    # Enable user services
    systemctl --user daemon-reload 2>/dev/null || true
    
    print_verbose "Systemd optimizations configured"
}

# Function to configure swap optimizations
configure_swap_optimizations() {
    print_status "Configuring swap optimizations for VM workloads..."
    
    # Create sysctl configuration for VM optimization
    local sysctl_file="/etc/sysctl.d/99-winapps-ubuntu.conf"
    
    if [[ ! -f "$sysctl_file" ]]; then
        sudo tee "$sysctl_file" > /dev/null << EOF
# Ubuntu WinApps optimizations
# Generated by AutoWinApps installer

# Reduce swappiness for VM workloads
vm.swappiness = 10

# Optimize dirty page handling
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5

# Network optimizations
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
EOF
        
        # Apply settings immediately
        sudo sysctl -p "$sysctl_file" >/dev/null 2>&1 || true
        
        print_verbose "Created sysctl configuration: $sysctl_file"
    fi
}

# Function to check Ubuntu-specific features
check_ubuntu_features() {
    print_status "Checking Ubuntu-specific features..."
    
    # Check Ubuntu version and features
    local version_major
    version_major=$(echo "$DETECTED_VERSION" | cut -d. -f1)
    
    case "$version_major" in
        "24"|"25")
            print_success "Modern Ubuntu with full feature support"
            ;;
        "22"|"23")
            print_success "Recent Ubuntu with good feature support"
            ;;
        "20"|"21")
            print_status "Older Ubuntu - some features may be limited"
            ;;
        *)
            print_warning "Ubuntu version not specifically tested"
            ;;
    esac
    
    # Check for snap
    if command -v snap &>/dev/null; then
        print_verbose "Snap package manager available"
    fi
    
    # Check for flatpak
    if command -v flatpak &>/dev/null; then
        print_verbose "Flatpak package manager available"
    fi
}

# Function to handle Ubuntu-specific cleanup
cleanup_ubuntu() {
    print_verbose "Performing Ubuntu-specific cleanup..."
    
    if [[ "$DRY_RUN" != true ]]; then
        # Clean package cache
        sudo apt autoremove -y >/dev/null 2>&1 || true
        sudo apt autoclean >/dev/null 2>&1 || true
    fi
    
    print_verbose "Ubuntu cleanup completed"
}

# Initialize Ubuntu module
print_verbose "Ubuntu module loaded"
check_os_requirements