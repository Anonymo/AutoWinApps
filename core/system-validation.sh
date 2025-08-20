#!/usr/bin/env bash

# System validation and requirements checking module
# This module provides comprehensive system validation

# Function to check system requirements comprehensively
validate_system_comprehensive() {
    print_header "Comprehensive System Validation"
    
    local validation_errors=0
    local validation_warnings=0
    
    # Check CPU architecture
    check_cpu_architecture || ((validation_errors++))
    
    # Check memory requirements
    check_memory_requirements || ((validation_warnings++))
    
    # Check disk space
    check_disk_space || ((validation_errors++))
    
    # Check virtualization support
    check_virtualization_support || ((validation_errors++))
    
    # Check network connectivity
    check_network_connectivity || ((validation_errors++))
    
    # Check kernel version
    check_kernel_version || ((validation_warnings++))
    
    # Check required kernel modules
    check_kernel_modules || ((validation_warnings++))
    
    # Check for conflicting software
    check_conflicting_software || ((validation_warnings++))
    
    # Check user permissions
    check_user_permissions || ((validation_warnings++))
    
    # Summary
    if [[ $validation_errors -gt 0 ]]; then
        print_error "System validation failed with $validation_errors critical errors"
        if [[ "${FORCE_INSTALL:-false}" != true ]]; then
            print_status "Use --force to override these checks (not recommended)"
            return 1
        else
            print_warning "Forcing installation despite errors (may cause issues)"
        fi
    elif [[ $validation_warnings -gt 0 ]]; then
        print_warning "System validation completed with $validation_warnings warnings"
        print_status "Installation can proceed but some features may not work optimally"
    else
        print_success "All system validation checks passed!"
    fi
    
    return 0
}

# Function to check CPU architecture
check_cpu_architecture() {
    print_status "Checking CPU architecture..."
    
    local arch
    arch=$(uname -m)
    
    case "$arch" in
        "x86_64"|"amd64")
            print_success "CPU architecture: $arch (supported)"
            return 0
            ;;
        "aarch64"|"arm64")
            print_warning "CPU architecture: $arch (experimental support)"
            print_status "ARM64 support may have limitations"
            return 0
            ;;
        *)
            print_error "CPU architecture: $arch (unsupported)"
            print_status "Supported architectures: x86_64, aarch64"
            return 1
            ;;
    esac
}

# Function to check memory requirements
check_memory_requirements() {
    print_status "Checking memory requirements..."
    
    local total_memory_kb
    total_memory_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local total_memory_gb=$((total_memory_kb / 1024 / 1024))
    
    local available_memory_kb
    available_memory_kb=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    local available_memory_gb=$((available_memory_kb / 1024 / 1024))
    
    print_status "Total memory: ${total_memory_gb}GB"
    print_status "Available memory: ${available_memory_gb}GB"
    
    if [[ $total_memory_gb -lt 4 ]]; then
        print_error "Insufficient total memory. Minimum: 4GB, detected: ${total_memory_gb}GB"
        return 1
    elif [[ $total_memory_gb -lt 8 ]]; then
        print_warning "Low total memory. Recommended: 8GB, detected: ${total_memory_gb}GB"
        print_status "Consider reducing Windows VM memory allocation"
        return 1
    else
        print_success "Memory requirements satisfied"
        return 0
    fi
}

# Function to check disk space
check_disk_space() {
    print_status "Checking disk space requirements..."
    
    local home_available_kb
    home_available_kb=$(df "$HOME" | awk 'NR==2 {print $4}')
    local home_available_gb=$((home_available_kb / 1024 / 1024))
    
    local root_available_kb
    root_available_kb=$(df / | awk 'NR==2 {print $4}')
    local root_available_gb=$((root_available_kb / 1024 / 1024))
    
    print_status "Available space in $HOME: ${home_available_gb}GB"
    print_status "Available space in /: ${root_available_gb}GB"
    
    # Check home directory space (for user installation)
    if [[ $home_available_gb -lt 50 ]]; then
        print_error "Insufficient space in $HOME. Minimum: 50GB, available: ${home_available_gb}GB"
        return 1
    elif [[ $home_available_gb -lt 80 ]]; then
        print_warning "Low space in $HOME. Recommended: 80GB, available: ${home_available_gb}GB"
    else
        print_success "Disk space requirements satisfied"
    fi
    
    # Check root filesystem space
    if [[ $root_available_gb -lt 5 ]]; then
        print_warning "Low space on root filesystem: ${root_available_gb}GB"
    fi
    
    return 0
}

# Function to check virtualization support
check_virtualization_support() {
    print_status "Checking virtualization support..."
    
    # Check CPU virtualization extensions
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
        print_status "Enable virtualization in BIOS/UEFI settings"
        return 1
    fi
    
    # Check if KVM is available
    if [[ -e /dev/kvm ]]; then
        print_success "KVM device available"
        
        # Check KVM permissions
        if [[ -r /dev/kvm ]] && [[ -w /dev/kvm ]]; then
            print_success "KVM device accessible"
        else
            print_warning "KVM device permissions need adjustment"
            print_status "User will be added to kvm group during installation"
        fi
    else
        print_warning "KVM device not found"
        print_status "KVM modules may need to be loaded"
    fi
    
    return 0
}

# Function to check network connectivity
check_network_connectivity() {
    print_status "Checking network connectivity..."
    
    # Check basic connectivity
    if ping -c 1 -W 5 8.8.8.8 &>/dev/null; then
        print_success "Internet connectivity verified"
    else
        print_error "No internet connectivity"
        print_status "Internet connection required for installation"
        return 1
    fi
    
    # Check specific services
    local services=(
        "github.com:443"
        "raw.githubusercontent.com:443"
        "registry.hub.docker.com:443"
    )
    
    for service in "${services[@]}"; do
        local host port
        IFS=':' read -r host port <<< "$service"
        
        if timeout 5 bash -c "</dev/tcp/$host/$port" 2>/dev/null; then
            print_verbose "✓ $host:$port reachable"
        else
            print_warning "✗ $host:$port unreachable"
        fi
    done
    
    return 0
}

# Function to check kernel version
check_kernel_version() {
    print_status "Checking kernel version..."
    
    local kernel_version
    kernel_version=$(uname -r)
    local kernel_major
    kernel_major=$(echo "$kernel_version" | cut -d. -f1)
    local kernel_minor
    kernel_minor=$(echo "$kernel_version" | cut -d. -f2)
    
    print_status "Kernel version: $kernel_version"
    
    # Check for minimum kernel version (3.10 for basic support)
    if [[ $kernel_major -gt 3 ]] || [[ $kernel_major -eq 3 && $kernel_minor -ge 10 ]]; then
        print_success "Kernel version supported"
        
        # Check for recommended kernel version (5.0+)
        if [[ $kernel_major -ge 5 ]]; then
            print_success "Modern kernel with optimal feature support"
        else
            print_warning "Consider upgrading to kernel 5.0+ for better performance"
        fi
        return 0
    else
        print_error "Kernel version too old. Minimum: 3.10, detected: $kernel_version"
        return 1
    fi
}

# Function to check required kernel modules
check_kernel_modules() {
    print_status "Checking kernel modules..."
    
    local required_modules=(
        "kvm"
        "tun"
        "bridge"
    )
    
    local missing_modules=0
    
    for module in "${required_modules[@]}"; do
        if lsmod | grep -q "^$module"; then
            print_verbose "✓ Module $module loaded"
        elif modinfo "$module" &>/dev/null; then
            print_warning "Module $module available but not loaded"
            print_status "Will attempt to load during installation"
        else
            print_warning "Module $module not available"
            ((missing_modules++))
        fi
    done
    
    if [[ $missing_modules -gt 0 ]]; then
        print_warning "$missing_modules required modules missing"
        return 1
    else
        print_success "All required kernel modules available"
        return 0
    fi
}

# Function to check for conflicting software
check_conflicting_software() {
    print_status "Checking for conflicting software..."
    
    local conflicts=0
    
    # Check for VirtualBox (can conflict with KVM)
    if command -v vboxmanage &>/dev/null; then
        print_warning "VirtualBox detected - may conflict with KVM"
        print_status "Consider stopping VirtualBox services during WinApps usage"
        ((conflicts++))
    fi
    
    # Check for VMware
    if systemctl is-active --quiet vmware &>/dev/null; then
        print_warning "VMware services detected - may conflict with KVM"
        ((conflicts++))
    fi
    
    # Check for Hyper-V (on WSL)
    if grep -q Microsoft /proc/version 2>/dev/null; then
        print_warning "Running on WSL - nested virtualization may not work"
        ((conflicts++))
    fi
    
    if [[ $conflicts -eq 0 ]]; then
        print_success "No conflicting software detected"
        return 0
    else
        print_warning "$conflicts potential conflicts detected"
        return 1
    fi
}

# Function to check user permissions
check_user_permissions() {
    print_status "Checking user permissions..."
    
    local permission_issues=0
    
    # Check sudo access
    if sudo -n true 2>/dev/null; then
        print_success "Sudo access available (no password required)"
    elif sudo -v &>/dev/null; then
        print_success "Sudo access available"
    else
        print_warning "Sudo access required for installation"
        ((permission_issues++))
    fi
    
    # Check group memberships
    local user_groups
    user_groups=$(groups "$(whoami)")
    
    if echo "$user_groups" | grep -q "\bdocker\b"; then
        print_verbose "User already in docker group"
    fi
    
    if echo "$user_groups" | grep -q "\blibvirt\b"; then
        print_verbose "User already in libvirt group"
    fi
    
    if echo "$user_groups" | grep -q "\bkvm\b"; then
        print_verbose "User already in kvm group"
    fi
    
    # Check home directory permissions
    if [[ ! -w "$HOME" ]]; then
        print_error "Home directory not writable"
        ((permission_issues++))
    fi
    
    if [[ $permission_issues -eq 0 ]]; then
        print_success "User permissions adequate"
        return 0
    else
        print_warning "$permission_issues permission issues detected"
        return 1
    fi
}

# Function to check system load
check_system_load() {
    print_status "Checking system load..."
    
    local load_avg
    load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
    local cpu_count
    cpu_count=$(nproc)
    
    # Convert load average to percentage
    local load_percentage
    load_percentage=$(echo "$load_avg * 100 / $cpu_count" | bc -l 2>/dev/null || echo "0")
    load_percentage=${load_percentage%.*}  # Remove decimal part
    
    print_status "System load: ${load_percentage}% (${load_avg}/${cpu_count} cores)"
    
    if [[ $load_percentage -gt 80 ]]; then
        print_warning "High system load detected (${load_percentage}%)"
        print_status "Consider waiting for system load to decrease"
        return 1
    else
        print_success "System load acceptable"
        return 0
    fi
}

# Function to generate system report
generate_system_report() {
    local report_file="$HOME/.cache/winapps-system-report.txt"
    
    print_status "Generating system report..."
    
    cat > "$report_file" << EOF
AutoWinApps System Report
Generated: $(date)
=========================

System Information:
- OS: $(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)
- Kernel: $(uname -r)
- Architecture: $(uname -m)
- Desktop: ${XDG_CURRENT_DESKTOP:-Unknown}

Hardware:
- CPU: $(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | sed 's/^ *//')
- Cores: $(nproc)
- Memory: $(grep MemTotal /proc/meminfo | awk '{print int($2/1024/1024)"GB"}')
- Virtualization: $(grep -o -E 'vmx|svm' /proc/cpuinfo | head -1 || echo "Not detected")

Storage:
- Root filesystem: $(df -h / | awk 'NR==2 {print $4" available of "$2}')
- Home directory: $(df -h "$HOME" | awk 'NR==2 {print $4" available of "$2}')
- Filesystem type: $(findmnt -n -o FSTYPE /)

Network:
- Default gateway: $(ip route | grep default | awk '{print $3}' | head -1)
- DNS servers: $(grep nameserver /etc/resolv.conf | awk '{print $2}' | tr '\n' ' ')

Services:
- Docker: $(systemctl is-active docker 2>/dev/null || echo "not active")
- Libvirt: $(systemctl is-active libvirtd 2>/dev/null || echo "not active")

User Information:
- Username: $(whoami)
- Groups: $(groups "$(whoami)")
- Shell: $SHELL
EOF
    
    print_success "System report saved to: $report_file"
}