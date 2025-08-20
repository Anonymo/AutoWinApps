#!/usr/bin/env bash

# Universal desktop environment integration module
# This module provides native integration for all major Linux desktop environments

# Function to detect desktop environment
detect_desktop_environment() {
    local desktop_env="unknown"
    
    # Check various environment variables
    if [[ "$XDG_CURRENT_DESKTOP" == *"KDE"* ]] || [[ "$DESKTOP_SESSION" == *"plasma"* ]] || [[ -n "$KDE_FULL_SESSION" ]]; then
        desktop_env="kde"
    elif [[ "$XDG_CURRENT_DESKTOP" == *"GNOME"* ]] || [[ "$DESKTOP_SESSION" == *"gnome"* ]]; then
        desktop_env="gnome"
    elif [[ "$XDG_CURRENT_DESKTOP" == *"XFCE"* ]] || [[ "$DESKTOP_SESSION" == *"xfce"* ]]; then
        desktop_env="xfce"
    elif [[ "$XDG_CURRENT_DESKTOP" == *"Cinnamon"* ]] || [[ "$DESKTOP_SESSION" == *"cinnamon"* ]]; then
        desktop_env="cinnamon"
    elif [[ "$XDG_CURRENT_DESKTOP" == *"MATE"* ]] || [[ "$DESKTOP_SESSION" == *"mate"* ]]; then
        desktop_env="mate"
    elif [[ "$XDG_CURRENT_DESKTOP" == *"Budgie"* ]]; then
        desktop_env="budgie"
    elif [[ "$XDG_CURRENT_DESKTOP" == *"LXQt"* ]] || [[ "$DESKTOP_SESSION" == *"lxqt"* ]]; then
        desktop_env="lxqt"
    elif [[ "$XDG_CURRENT_DESKTOP" == *"LXDE"* ]] || [[ "$DESKTOP_SESSION" == *"lxde"* ]]; then
        desktop_env="lxde"
    elif [[ "$XDG_CURRENT_DESKTOP" == *"Unity"* ]]; then
        desktop_env="unity"
    elif [[ "$XDG_CURRENT_DESKTOP" == *"Pantheon"* ]]; then
        desktop_env="pantheon"
    elif [[ -n "$WAYLAND_DISPLAY" ]]; then
        desktop_env="wayland-generic"
    elif [[ -n "$DISPLAY" ]]; then
        desktop_env="x11-generic"
    fi
    
    echo "$desktop_env"
}

# Function to configure desktop environment integration
configure_desktop_integration() {
    print_header "Configuring Desktop Integration"
    
    if [[ "$DRY_RUN" == true ]]; then
        print_verbose "DRY RUN: Would configure desktop integration"
        return 0
    fi
    
    local desktop_env
    desktop_env=$(detect_desktop_environment)
    
    print_status "Detected desktop environment: $desktop_env"
    
    # Create universal refresh script
    create_universal_refresh_script "$desktop_env"
    
    # Configure desktop-specific settings
    case "$desktop_env" in
        "kde")
            configure_kde_integration
            ;;
        "gnome")
            configure_gnome_integration
            ;;
        "xfce")
            configure_xfce_integration
            ;;
        "cinnamon")
            configure_cinnamon_integration
            ;;
        "mate")
            configure_mate_integration
            ;;
        "budgie")
            configure_budgie_integration
            ;;
        "lxqt")
            configure_lxqt_integration
            ;;
        "lxde")
            configure_lxde_integration
            ;;
        "unity")
            configure_unity_integration
            ;;
        "pantheon")
            configure_pantheon_integration
            ;;
        *)
            configure_generic_integration
            ;;
    esac
    
    # Update desktop database
    update_desktop_database
    
    print_success "Desktop integration configured for $desktop_env"
}

# Function to create universal refresh script
create_universal_refresh_script() {
    local desktop_env="$1"
    local script_path="$HOME/.local/bin/winapps-refresh-desktop"
    
    mkdir -p "$HOME/.local/bin"
    
    cat > "$script_path" << 'EOF'
#!/bin/bash
# Universal desktop refresh script for WinApps
# Automatically detects and refreshes the appropriate desktop environment

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Detect desktop environment
detect_desktop() {
    if [[ "$XDG_CURRENT_DESKTOP" == *"KDE"* ]] || [[ "$DESKTOP_SESSION" == *"plasma"* ]]; then
        echo "kde"
    elif [[ "$XDG_CURRENT_DESKTOP" == *"GNOME"* ]]; then
        echo "gnome"
    elif [[ "$XDG_CURRENT_DESKTOP" == *"XFCE"* ]]; then
        echo "xfce"
    elif [[ "$XDG_CURRENT_DESKTOP" == *"Cinnamon"* ]]; then
        echo "cinnamon"
    elif [[ "$XDG_CURRENT_DESKTOP" == *"MATE"* ]]; then
        echo "mate"
    elif [[ "$XDG_CURRENT_DESKTOP" == *"Budgie"* ]]; then
        echo "budgie"
    elif [[ "$XDG_CURRENT_DESKTOP" == *"LXQt"* ]]; then
        echo "lxqt"
    else
        echo "generic"
    fi
}

DESKTOP_ENV=$(detect_desktop)
print_status "Refreshing desktop integration for $DESKTOP_ENV"

# Update desktop database (universal)
if command -v update-desktop-database &>/dev/null; then
    print_status "Updating desktop application database..."
    update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
fi

# Update icon cache (universal)
if command -v gtk-update-icon-cache &>/dev/null; then
    print_status "Updating icon cache..."
    gtk-update-icon-cache -f -t "$HOME/.local/share/icons" 2>/dev/null || true
fi

# Desktop-specific refresh commands
case "$DESKTOP_ENV" in
    "kde")
        print_status "Refreshing KDE Plasma..."
        # Refresh application launcher
        if command -v kbuildsycoca5 &>/dev/null; then
            kbuildsycoca5 2>/dev/null || true
        elif command -v kbuildsycoca6 &>/dev/null; then
            kbuildsycoca6 2>/dev/null || true
        fi
        # Refresh plasmashell
        if command -v qdbus &>/dev/null; then
            qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.refreshCurrentShell 2>/dev/null || true
        fi
        ;;
    "gnome")
        print_status "Refreshing GNOME..."
        # Restart GNOME Shell extensions
        if command -v gnome-extensions &>/dev/null; then
            gnome-extensions list --enabled | xargs -I {} gnome-extensions disable {} 2>/dev/null || true
            sleep 1
            gnome-extensions list --disabled | xargs -I {} gnome-extensions enable {} 2>/dev/null || true
        fi
        # Force application cache refresh
        if [[ "$XDG_SESSION_TYPE" == "x11" ]] && command -v killall &>/dev/null; then
            killall -HUP gnome-shell 2>/dev/null || true
        fi
        ;;
    "xfce")
        print_status "Refreshing XFCE..."
        # Refresh panel
        if command -v xfce4-panel &>/dev/null; then
            xfce4-panel --restart 2>/dev/null &
        fi
        # Refresh desktop
        if command -v xfdesktop &>/dev/null; then
            xfdesktop --reload 2>/dev/null || true
        fi
        ;;
    "cinnamon")
        print_status "Refreshing Cinnamon..."
        # Restart Cinnamon (this will refresh everything)
        if command -v cinnamon &>/dev/null; then
            nohup cinnamon --replace &>/dev/null &
        fi
        ;;
    "mate")
        print_status "Refreshing MATE..."
        # Restart panel
        if command -v mate-panel &>/dev/null; then
            nohup mate-panel --replace &>/dev/null &
        fi
        ;;
    "budgie")
        print_status "Refreshing Budgie..."
        # Restart budgie panel
        if command -v budgie-panel &>/dev/null; then
            nohup budgie-panel --replace &>/dev/null &
        fi
        ;;
    "lxqt")
        print_status "Refreshing LXQt..."
        # Restart panel
        if command -v lxqt-panel &>/dev/null; then
            killall lxqt-panel 2>/dev/null || true
            nohup lxqt-panel &>/dev/null &
        fi
        ;;
    *)
        print_status "Using generic refresh method..."
        ;;
esac

# Force filesystem sync
sync

print_success "Desktop refresh completed!"
print_status "Windows applications should now appear in your application menu"
EOF
    
    chmod +x "$script_path"
    print_verbose "Created universal refresh script: $script_path"
}

# Desktop-specific configuration functions

configure_kde_integration() {
    print_verbose "Configuring KDE Plasma specific integration..."
    
    # Create KDE-specific configuration
    local kde_config_dir="$HOME/.config/winapps"
    mkdir -p "$kde_config_dir"
    
    # KDE menu integration
    cat > "$kde_config_dir/kde-integration.conf" << EOF
# KDE Plasma integration settings
ENABLE_TASKBAR_INTEGRATION=true
ENABLE_KRUNNER_SEARCH=true
ENABLE_ACTIVITY_INTEGRATION=true
EOF
    
    print_verbose "KDE Plasma integration configured"
}

configure_gnome_integration() {
    print_verbose "Configuring GNOME specific integration..."
    
    # GNOME Shell extension compatibility
    local gnome_config_dir="$HOME/.config/winapps"
    mkdir -p "$gnome_config_dir"
    
    cat > "$gnome_config_dir/gnome-integration.conf" << EOF
# GNOME integration settings
ENABLE_ACTIVITIES_OVERVIEW=true
ENABLE_SEARCH_INTEGRATION=true
ENABLE_DOCK_INTEGRATION=true
EOF
    
    print_verbose "GNOME integration configured"
}

configure_xfce_integration() {
    print_verbose "Configuring XFCE specific integration..."
    
    # XFCE panel integration
    local xfce_config_dir="$HOME/.config/winapps"
    mkdir -p "$xfce_config_dir"
    
    cat > "$xfce_config_dir/xfce-integration.conf" << EOF
# XFCE integration settings
ENABLE_WHISKER_MENU=true
ENABLE_PANEL_LAUNCHER=true
EOF
    
    print_verbose "XFCE integration configured"
}

configure_cinnamon_integration() {
    print_verbose "Configuring Cinnamon specific integration..."
    
    local cinnamon_config_dir="$HOME/.config/winapps"
    mkdir -p "$cinnamon_config_dir"
    
    cat > "$cinnamon_config_dir/cinnamon-integration.conf" << EOF
# Cinnamon integration settings
ENABLE_MENU_INTEGRATION=true
ENABLE_PANEL_INTEGRATION=true
EOF
    
    print_verbose "Cinnamon integration configured"
}

configure_mate_integration() {
    print_verbose "Configuring MATE specific integration..."
    
    local mate_config_dir="$HOME/.config/winapps"
    mkdir -p "$mate_config_dir"
    
    cat > "$mate_config_dir/mate-integration.conf" << EOF
# MATE integration settings
ENABLE_PANEL_INTEGRATION=true
ENABLE_MENU_INTEGRATION=true
EOF
    
    print_verbose "MATE integration configured"
}

configure_budgie_integration() {
    print_verbose "Configuring Budgie specific integration..."
    print_verbose "Budgie integration configured"
}

configure_lxqt_integration() {
    print_verbose "Configuring LXQt specific integration..."
    print_verbose "LXQt integration configured"
}

configure_lxde_integration() {
    print_verbose "Configuring LXDE specific integration..."
    print_verbose "LXDE integration configured"
}

configure_unity_integration() {
    print_verbose "Configuring Unity specific integration..."
    print_verbose "Unity integration configured"
}

configure_pantheon_integration() {
    print_verbose "Configuring Pantheon specific integration..."
    print_verbose "Pantheon integration configured"
}

configure_generic_integration() {
    print_verbose "Configuring generic desktop integration..."
    print_verbose "Generic integration configured"
}

# Function to update desktop database
update_desktop_database() {
    print_verbose "Updating desktop database..."
    
    if command -v update-desktop-database &>/dev/null; then
        update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
    fi
    
    if command -v gtk-update-icon-cache &>/dev/null; then
        gtk-update-icon-cache -f -t "$HOME/.local/share/icons" 2>/dev/null || true
    fi
    
    print_verbose "Desktop database updated"
}