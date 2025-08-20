#!/usr/bin/env bash

# Debian-specific module
# This module contains Debian-specific package management and configuration

# Function to check Debian-specific requirements
check_os_requirements() {
    print_verbose "Checking Debian-specific requirements..."
    
    # Verify this is actually Debian
    if [[ "$DETECTED_OS" != "debian" ]]; then
        print_error "This module is for Debian, detected: $DETECTED_OS"
        return 1
    fi
    
    # Check for apt
    if ! command -v apt &>/dev/null; then
        print_error "apt package manager not found"
        return 1
    fi
    
    # Check Debian version
    local version_major
    version_major=$(echo "$DETECTED_VERSION" | cut -d. -f1)
    
    if [[ "$version_major" -lt 11 ]]; then
        print_warning "Debian version $DETECTED_VERSION is quite old. Consider upgrading."
    elif [[ "$version_major" -ge 12 ]]; then
        print_success "Modern Debian version detected"
    else
        print_status "Debian version $DETECTED_VERSION is supported"
    fi
    
    print_success "Debian environment verified"
    return 0
}

# Function to enable required repositories
enable_repositories() {
    print_status "Checking repository configuration..."
    
    if [[ "$DRY_RUN" == true ]]; then
        print_verbose "DRY RUN: Would check and enable repositories"
        return 0
    fi
    
    # Check if contrib and non-free are enabled
    local sources_updated=false
    
    if ! grep -q "contrib" /etc/apt/sources.list /etc/apt/sources.list.d/* 2>/dev/null; then
        print_status "Enabling contrib repository..."
        sudo sed -i 's/main$/main contrib/' /etc/apt/sources.list
        sources_updated=true
    else
        print_verbose "contrib repository already enabled"
    fi
    
    # For Debian 12+, use non-free-firmware
    local version_major
    version_major=$(echo "$DETECTED_VERSION" | cut -d. -f1)
    
    if [[ "$version_major" -ge 12 ]]; then
        if ! grep -q "non-free-firmware" /etc/apt/sources.list /etc/apt/sources.list.d/* 2>/dev/null; then
            print_status "Enabling non-free-firmware repository..."
            sudo sed -i 's/contrib$/contrib non-free-firmware/' /etc/apt/sources.list
            sources_updated=true
        fi
    else
        if ! grep -q "non-free" /etc/apt/sources.list /etc/apt/sources.list.d/* 2>/dev/null; then
            print_status "Enabling non-free repository..."
            sudo sed -i 's/contrib$/contrib non-free/' /etc/apt/sources.list
            sources_updated=true
        fi
    fi
    
    # Check for backports (useful for newer packages)
    local codename
    codename=$(lsb_release -sc 2>/dev/null || grep VERSION_CODENAME /etc/os-release | cut -d= -f2)
    
    if [[ -n "$codename" ]] && ! grep -q "$codename-backports" /etc/apt/sources.list /etc/apt/sources.list.d/* 2>/dev/null; then
        print_status "Enabling backports repository..."
        echo "deb http://deb.debian.org/debian $codename-backports main contrib non-free" | \
            sudo tee /etc/apt/sources.list.d/debian-backports.list > /dev/null
        sources_updated=true
    fi
    
    if [[ "$sources_updated" == true ]]; then
        print_status "Updating package lists after repository changes..."
        sudo apt update
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
    
    # Try to determine best FreeRDP package for Debian
    local freerdp_package="freerdp2-x11"
    local version_major
    version_major=$(echo "$DETECTED_VERSION" | cut -d. -f1)
    
    if [[ "$version_major" -ge 12 ]]; then
        # Debian 12+ should have FreeRDP3
        freerdp_package="freerdp2-x11"  # Start with FreeRDP2, check for 3 during install
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
    printf "   • %s\\n" "${all_packages[@]}"
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
        freerdp_package="freerdp2-x11"
        print_verbose "DRY RUN: Would use freerdp2-x11"
    else
        # Check for FreeRDP3 first (newer Debian versions)
        if apt-cache show freerdp3-x11 &>/dev/null; then
            freerdp_package="freerdp3-x11"
            print_status "Using FreeRDP3"
        else
            freerdp_package="freerdp2-x11"
            print_status "Using FreeRDP2"
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
            # Check if podman is available (Debian 11+)
            if [[ "$DRY_RUN" == true ]] || apt-cache show podman &>/dev/null; then
                backend_packages=(
                    "podman"
                    "podman-compose"
                )
            else
                print_warning "Podman not available in main repositories. Installing from backports..."
                # Try backports first
                if apt-cache -t *-backports show podman &>/dev/null; then
                    backend_packages=(
                        "podman/$(lsb_release -sc)-backports"
                        "podman-compose"
                    )
                else
                    print_warning "Installing alternative container tools..."
                    backend_packages=(
                        "containers-common"
                        "crun"
                    )
                fi
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
                print_status "Attempting to install FreeRDP2 as fallback..."
                if DEBIAN_FRONTEND=noninteractive sudo apt install -y freerdp2-x11; then
                    print_success "Installed FreeRDP2 as fallback"
                else
                    print_error "Failed to install any FreeRDP version"
                fi
                ;;
            "podman"|"podman-compose"|"podman/"*)
                print_status "Will install podman from alternative source..."
                ;;
            "docker-compose")
                print_status "Attempting to install docker-compose from backports..."
                DEBIAN_FRONTEND=noninteractive sudo apt install -y docker-compose/$(lsb_release -sc)-backports 2>/dev/null || \
                print_warning "docker-compose not available from backports"
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
    
    local version_major
    version_major=$(echo "$DETECTED_VERSION" | cut -d. -f1)
    
    if [[ "$version_major" -ge 11 ]]; then
        # Try installing from official Debian repositories first
        if ! apt-cache show podman &>/dev/null; then
            # Add Kubic repository for older Debian versions
            local debian_version="Debian_${version_major}"
            
            curl -fsSL https://download.opensuse.org/repositories/devel:kubic:libcontainers:stable/${debian_version}/Release.key | \
                sudo gpg --dearmor -o /etc/apt/keyrings/devel_kubic_libcontainers_stable.gpg
            
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/devel_kubic_libcontainers_stable.gpg] \
                https://download.opensuse.org/repositories/devel:kubic:libcontainers:stable/${debian_version}/ /" | \
                sudo tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list > /dev/null
            
            sudo apt update
            sudo apt install -y podman
            
            # Install podman-compose via pip3
            if command -v pip3 &>/dev/null || DEBIAN_FRONTEND=noninteractive sudo apt install -y python3-pip; then
                pip3 install --user podman-compose
            fi
            
            print_success "Podman installed from kubic repository"
        fi
    else
        print_error "Podman installation failed and no alternative available for Debian $version_major"
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

# Function to optimize for Debian
optimize_for_debian() {
    print_header "Applying Debian-Specific Optimizations"
    
    if [[ "$DRY_RUN" == true ]]; then
        print_verbose "DRY RUN: Would apply Debian optimizations"
        return 0
    fi
    
    # Debian-specific optimizations
    print_status "Applying Debian optimizations..."
    
    # Configure AppArmor if present
    configure_apparmor_optimizations
    
    # Optimize systemd settings
    configure_systemd_optimizations
    
    # Configure swap settings for better VM performance
    configure_swap_optimizations
    
    print_success "Debian optimizations applied"
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
    local sysctl_file="/etc/sysctl.d/99-winapps-debian.conf"
    
    if [[ ! -f "$sysctl_file" ]]; then
        sudo tee "$sysctl_file" > /dev/null << EOF
# Debian WinApps optimizations
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

# Function to check Debian-specific features
check_debian_features() {
    print_status "Checking Debian-specific features..."
    
    # Check Debian version and features
    local version_major
    version_major=$(echo "$DETECTED_VERSION" | cut -d. -f1)
    
    case "$version_major" in
        "13"|"14")
            print_success "Modern Debian with full feature support"
            ;;
        "12")
            print_success "Recent Debian with good feature support"
            ;;
        "11")
            print_status "Older Debian - some features may be limited"
            ;;
        *)
            print_warning "Debian version not specifically tested"
            ;;
    esac
    
    # Check for snap (usually not available on Debian)
    if command -v snap &>/dev/null; then
        print_verbose "Snap package manager available"
    else
        print_verbose "Snap not available (normal for Debian)"
    fi
    
    # Check for flatpak
    if command -v flatpak &>/dev/null; then
        print_verbose "Flatpak package manager available"
    fi
}

# Function to handle Debian-specific cleanup
cleanup_debian() {
    print_verbose "Performing Debian-specific cleanup..."
    
    if [[ "$DRY_RUN" != true ]]; then
        # Clean package cache
        sudo apt autoremove -y >/dev/null 2>&1 || true
        sudo apt autoclean >/dev/null 2>&1 || true
    fi
    
    print_verbose "Debian cleanup completed"
}

# Debian module loaded - functions are available for use