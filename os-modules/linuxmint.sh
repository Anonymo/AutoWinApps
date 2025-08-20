#!/usr/bin/env bash

# Linux Mint-specific module
# This module contains Linux Mint-specific package management and configuration

# Function to check Linux Mint-specific requirements
check_os_requirements() {
    print_verbose "Checking Linux Mint-specific requirements..."
    
    # Verify this is actually Linux Mint
    if [[ "$DETECTED_OS" != "linuxmint" ]]; then
        print_error "This module is for Linux Mint, detected: $DETECTED_OS"
        return 1
    fi
    
    # Check for apt
    if ! command -v apt &>/dev/null; then
        print_error "apt package manager not found"
        return 1
    fi
    
    # Check Linux Mint version
    local version_major
    version_major=$(echo "$DETECTED_VERSION" | cut -d. -f1)
    
    case "$version_major" in
        "22"|"23")
            print_success "Modern Linux Mint version detected"
            ;;
        "21")
            print_status "Linux Mint version $DETECTED_VERSION is supported"
            ;;
        "20")
            print_warning "Linux Mint version $DETECTED_VERSION is quite old. Consider upgrading."
            ;;
        *)
            print_warning "Linux Mint version not specifically tested"
            ;;
    esac
    
    # Check Mint edition
    local mint_edition=""
    if [[ -f /etc/linuxmint/info ]]; then
        mint_edition=$(grep EDITION /etc/linuxmint/info | cut -d= -f2)
        print_status "Linux Mint edition: $mint_edition"
    fi
    
    print_success "Linux Mint environment verified"
    return 0
}

# Function to enable required repositories
enable_repositories() {
    print_status "Checking repository configuration..."
    
    if [[ "$DRY_RUN" == true ]]; then
        print_verbose "DRY RUN: Would check and enable repositories"
        return 0
    fi
    
    # Linux Mint already has universe enabled by default, but double check
    if ! grep -q "^deb.*universe" /etc/apt/sources.list /etc/apt/sources.list.d/* 2>/dev/null; then
        print_status "Enabling universe repository..."
        sudo add-apt-repository universe -y
    else
        print_verbose "Universe repository already enabled"
    fi
    
    # Check for multiverse (for additional codec support)
    if ! grep -q "multiverse" /etc/apt/sources.list /etc/apt/sources.list.d/* 2>/dev/null; then
        print_status "Enabling multiverse repository..."
        sudo add-apt-repository multiverse -y
    else
        print_verbose "Multiverse repository already enabled"
    fi
    
    # Linux Mint 22+ should have good FreeRDP3 support
    local version_major
    version_major=$(echo "$DETECTED_VERSION" | cut -d. -f1)
    
    if [[ "$version_major" -ge 22 ]]; then
        print_verbose "Linux Mint 22+ detected - FreeRDP3 should be available"
    else
        print_status "Checking for FreeRDP3 availability..."
        if ! apt-cache show freerdp3-x11 &>/dev/null; then
            print_warning "FreeRDP3 not available. Will use FreeRDP2."
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
    
    # Try to determine best FreeRDP package for Linux Mint
    local freerdp_package="freerdp2-x11"
    local version_major
    version_major=$(echo "$DETECTED_VERSION" | cut -d. -f1)
    
    if [[ "$version_major" -ge 22 ]]; then
        freerdp_package="freerdp3-x11"  # Linux Mint 22+ should have FreeRDP3
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
            # Check if podman is available (Linux Mint 22+ should have it)
            if [[ "$DRY_RUN" == true ]] || apt-cache show podman &>/dev/null; then
                backend_packages=(
                    "podman"
                    "podman-compose"
                )
            else
                print_warning "Podman not available in repositories. Installing alternative tools..."
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
                print_status "Attempting to install FreeRDP2 as fallback..."
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
    
    # Try Ubuntu PPA for older Linux Mint versions
    local version_major
    version_major=$(echo "$DETECTED_VERSION" | cut -d. -f1)
    
    if [[ "$version_major" -lt 22 ]]; then
        # Add Kubic repository (similar to Ubuntu approach)
        # First, determine Ubuntu base version
        local ubuntu_version=""
        if [[ -f /etc/upstream-release/lsb-release ]]; then
            ubuntu_version=$(grep DISTRIB_RELEASE /etc/upstream-release/lsb-release | cut -d= -f2)
        fi
        
        if [[ -n "$ubuntu_version" ]]; then
            curl -fsSL https://download.opensuse.org/repositories/devel:kubic:libcontainers:stable/xUbuntu_${ubuntu_version}/Release.key | \
                sudo gpg --dearmor -o /etc/apt/keyrings/devel_kubic_libcontainers_stable.gpg
            
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/devel_kubic_libcontainers_stable.gpg] \
                https://download.opensuse.org/repositories/devel:kubic:libcontainers:stable/xUbuntu_${ubuntu_version}/ /" | \
                sudo tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list > /dev/null
            
            sudo apt update
            sudo apt install -y podman
            
            # Install podman-compose via pip
            if command -v pip3 &>/dev/null; then
                pip3 install --user podman-compose
            fi
            
            print_success "Podman installed from kubic repository"
        else
            print_error "Could not determine Ubuntu base version for repository setup"
        fi
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

# Function to optimize for Linux Mint
optimize_for_linuxmint() {
    print_header "Applying Linux Mint-Specific Optimizations"
    
    if [[ "$DRY_RUN" == true ]]; then
        print_verbose "DRY RUN: Would apply Linux Mint optimizations"
        return 0
    fi
    
    # Linux Mint-specific optimizations
    print_status "Applying Linux Mint optimizations..."
    
    # Configure for specific Mint editions
    configure_mint_edition_optimizations
    
    # Configure update manager settings
    configure_mint_update_settings
    
    # Optimize Cinnamon/MATE/XFCE specific settings
    configure_mint_desktop_optimizations
    
    # Configure system settings for VM performance
    configure_mint_system_optimizations
    
    print_success "Linux Mint optimizations applied"
}

# Function to configure Mint edition optimizations
configure_mint_edition_optimizations() {
    local mint_edition=""
    if [[ -f /etc/linuxmint/info ]]; then
        mint_edition=$(grep EDITION /etc/linuxmint/info | cut -d= -f2)
    fi
    
    case "$mint_edition" in
        "Cinnamon")
            print_status "Optimizing for Cinnamon edition..."
            configure_cinnamon_optimizations
            ;;
        "MATE")
            print_status "Optimizing for MATE edition..."
            configure_mate_optimizations
            ;;
        "XFCE")
            print_status "Optimizing for XFCE edition..."
            configure_xfce_optimizations
            ;;
        *)
            print_status "Using generic Linux Mint optimizations..."
            ;;
    esac
}

# Function to configure Cinnamon optimizations
configure_cinnamon_optimizations() {
    # Cinnamon-specific optimizations for VM performance
    print_verbose "Applying Cinnamon desktop optimizations..."
    
    # Reduce visual effects for better VM performance
    if command -v gsettings &>/dev/null; then
        gsettings set org.cinnamon desktop-effects false 2>/dev/null || true
        gsettings set org.cinnamon.settings-daemon.plugins.power idle-dim-battery false 2>/dev/null || true
    fi
}

# Function to configure MATE optimizations
configure_mate_optimizations() {
    print_verbose "Applying MATE desktop optimizations..."
    
    # MATE-specific optimizations for VM performance
    if command -v gsettings &>/dev/null; then
        gsettings set org.mate.interface enable-animations false 2>/dev/null || true
    fi
}

# Function to configure XFCE optimizations
configure_xfce_optimizations() {
    print_verbose "Applying XFCE desktop optimizations..."
    
    # XFCE optimization - disable compositor for better VM performance
    if command -v xfconf-query &>/dev/null; then
        xfconf-query -c xfwm4 -p /general/use_compositing -s false 2>/dev/null || true
    fi
}

# Function to configure Mint update settings
configure_mint_update_settings() {
    print_status "Configuring Linux Mint update settings..."
    
    # Ensure automatic updates don't interfere with VM operations
    if [[ -f /etc/apt/apt.conf.d/20auto-upgrades ]]; then
        # Disable automatic updates during VM operations
        sudo tee /etc/apt/apt.conf.d/99-winapps-updates > /dev/null << 'EOF'
// WinApps update configuration
// Prevent automatic updates during VM operations
APT::Periodic::Update-Package-Lists "0";
APT::Periodic::Unattended-Upgrade "0";
EOF
        print_verbose "Configured automatic update settings"
    fi
}

# Function to configure Mint desktop optimizations
configure_mint_desktop_optimizations() {
    print_status "Configuring desktop environment optimizations..."
    
    # Create Linux Mint specific desktop configuration
    local mint_config_dir="$HOME/.config/winapps"
    mkdir -p "$mint_config_dir"
    
    cat > "$mint_config_dir/linuxmint-integration.conf" << EOF
# Linux Mint integration settings
ENABLE_MINT_MENU_INTEGRATION=true
ENABLE_PANEL_INTEGRATION=true
OPTIMIZE_FOR_VM_WORKLOAD=true
EOF
    
    print_verbose "Linux Mint desktop integration configured"
}

# Function to configure Mint system optimizations
configure_mint_system_optimizations() {
    print_status "Configuring system optimizations for VM workloads..."
    
    # Create sysctl configuration for VM optimization
    local sysctl_file="/etc/sysctl.d/99-winapps-linuxmint.conf"
    
    if [[ ! -f "$sysctl_file" ]]; then
        sudo tee "$sysctl_file" > /dev/null << EOF
# Linux Mint WinApps optimizations
# Generated by AutoWinApps installer

# Reduce swappiness for VM workloads
vm.swappiness = 10

# Optimize dirty page handling
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5

# Network optimizations
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216

# Improve responsiveness during high memory usage
vm.vfs_cache_pressure = 50
EOF
        
        # Apply settings immediately
        sudo sysctl -p "$sysctl_file" >/dev/null 2>&1 || true
        
        print_verbose "Created sysctl configuration: $sysctl_file"
    fi
}

# Function to check Linux Mint-specific features
check_linuxmint_features() {
    print_status "Checking Linux Mint-specific features..."
    
    # Check Linux Mint version and edition
    local version_major
    version_major=$(echo "$DETECTED_VERSION" | cut -d. -f1)
    
    case "$version_major" in
        "22"|"23")
            print_success "Modern Linux Mint with full feature support"
            ;;
        "21")
            print_success "Recent Linux Mint with good feature support"
            ;;
        "20")
            print_status "Older Linux Mint - some features may be limited"
            ;;
        *)
            print_warning "Linux Mint version not specifically tested"
            ;;
    esac
    
    # Check for Mint-specific tools
    if command -v mintupdate &>/dev/null; then
        print_verbose "Mint Update Manager available"
    fi
    
    if command -v mintstick &>/dev/null; then
        print_verbose "Mint USB Image Writer available"
    fi
    
    # Check for snap (disabled by default in Mint)
    if command -v snap &>/dev/null; then
        print_verbose "Snap package manager available (unusual for Mint)"
    else
        print_verbose "Snap disabled (normal for Linux Mint)"
    fi
    
    # Check for flatpak (enabled by default in modern Mint)
    if command -v flatpak &>/dev/null; then
        print_success "Flatpak package manager available"
    fi
}

# Function to handle Linux Mint-specific cleanup
cleanup_linuxmint() {
    print_verbose "Performing Linux Mint-specific cleanup..."
    
    if [[ "$DRY_RUN" != true ]]; then
        # Clean package cache
        sudo apt autoremove -y >/dev/null 2>&1 || true
        sudo apt autoclean >/dev/null 2>&1 || true
        
        # Clean Flatpak cache if available
        if command -v flatpak &>/dev/null; then
            flatpak uninstall --unused -y >/dev/null 2>&1 || true
        fi
    fi
    
    print_verbose "Linux Mint cleanup completed"
}

# Linux Mint module loaded - functions are available for use