#!/bin/bash
# Hardware detection utilities for Local-LLM-Kit
# Provides: GPU detection, group ID resolution, hardware verification

# Source common utilities (use local var to not overwrite caller's SCRIPT_DIR)
_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$_LIB_DIR/common.sh"

# Detect GPU type on Linux
# Returns: nvidia, amd, or none
detect_gpu_linux() {
    # Check for NVIDIA first
    if is_command_available nvidia-smi; then
        if nvidia-smi &>/dev/null; then
            echo "nvidia"
            return 0
        fi
    fi

    # Check for AMD GPU
    if [ -d "/dev/dri" ]; then
        # Verify it's actually an AMD GPU
        if lspci 2>/dev/null | grep -i "VGA.*AMD\|VGA.*Radeon\|Display.*AMD\|Display.*Radeon" &>/dev/null; then
            echo "amd"
            return 0
        fi
    fi

    # No GPU detected
    echo "none"
    return 0
}

# Get video group ID
# Returns: group ID number or empty if not found
get_video_group_id() {
    if getent group video &>/dev/null; then
        getent group video | cut -d: -f3
    else
        echo ""
    fi
}

# Get render group ID
# Returns: group ID number or empty if not found
get_render_group_id() {
    if getent group render &>/dev/null; then
        getent group render | cut -d: -f3
    else
        echo ""
    fi
}

# Check if user is in video and render groups (for AMD)
check_user_in_gpu_groups() {
    local in_video=false
    local in_render=false

    if groups | grep -q "\bvideo\b"; then
        in_video=true
    fi

    if groups | grep -q "\brender\b"; then
        in_render=true
    fi

    if $in_video && $in_render; then
        return 0
    else
        return 1
    fi
}

# Verify NVIDIA Container Toolkit is installed and working
verify_nvidia_toolkit() {
    if ! is_command_available docker; then
        return 1
    fi

    # Try to run a simple NVIDIA container
    if docker run --rm --gpus all nvidia/cuda:12.0-base nvidia-smi &>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Check if native Ollama is installed and running (macOS)
check_native_ollama() {
    # Check if ollama command exists
    if ! is_command_available ollama; then
        return 1
    fi

    # Check if ollama service is responding
    if curl -s http://localhost:11434/api/tags &>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Check Vulkan support (for AMD)
check_vulkan_support() {
    if is_command_available vulkaninfo; then
        if vulkaninfo 2>/dev/null | grep -i "amd\|radeon" &>/dev/null; then
            return 0
        fi
    fi
    return 1
}

# Get CPU core count
get_cpu_cores() {
    if [ -f /proc/cpuinfo ]; then
        grep -c ^processor /proc/cpuinfo
    elif is_command_available sysctl; then
        sysctl -n hw.ncpu 2>/dev/null || echo "4"
    else
        echo "4"  # Default fallback
    fi
}

# Get total RAM in GB
get_total_ram_gb() {
    if [ -f /proc/meminfo ]; then
        awk '/MemTotal/ {printf "%.0f", $2/1024/1024}' /proc/meminfo
    elif is_command_available sysctl; then
        local bytes=$(sysctl -n hw.memsize 2>/dev/null)
        if [ -n "$bytes" ]; then
            echo $((bytes / 1024 / 1024 / 1024))
        else
            echo "8"  # Default fallback
        fi
    else
        echo "8"  # Default fallback
    fi
}

# Recommend performance tier based on hardware
# Returns: low, medium, or high
recommend_performance_tier() {
    local gpu_type="$1"
    local ram_gb=$(get_total_ram_gb)
    local cores=$(get_cpu_cores)

    if [ "$gpu_type" = "none" ]; then
        # CPU-only: be conservative
        if [ "$ram_gb" -lt 8 ] || [ "$cores" -lt 4 ]; then
            echo "low"
        else
            echo "medium"
        fi
    else
        # GPU available: can be more aggressive
        if [ "$ram_gb" -ge 16 ] && [ "$cores" -ge 8 ]; then
            echo "high"
        else
            echo "medium"
        fi
    fi
}

# Get performance settings for tier
# Usage: get_performance_settings "high"
# Returns: "NUM_PARALLEL MAX_LOADED"
get_performance_settings() {
    local tier="$1"

    case "$tier" in
        low)
            echo "1 1"
            ;;
        medium)
            echo "2 1"
            ;;
        high)
            echo "4 2"
            ;;
        *)
            echo "2 1"
            ;;
    esac
}
