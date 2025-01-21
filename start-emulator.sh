#!/bin/bash

# Color definitions
declare -r BL='\033[0;34m'
declare -r G='\033[0;32m'
declare -r RED='\033[0;31m'
declare -r YE='\033[1;33m'
declare -r NC='\033[0m'

# Default values and configuration
declare -r DEFAULT_TIMEOUT=300  # 5 minutes timeout
declare -r BOOT_TIMEOUT=${EMULATOR_TIMEOUT:-$DEFAULT_TIMEOUT}
declare -r ADB_RETRY_ATTEMPTS=3
declare -r SLEEP_BETWEEN_ATTEMPTS=2

# Function to log messages with colors
log_message() {
    local level=$1
    local message=$2
    local color=$NC

    case $level in
        "INFO")  color=$BL ;;
        "SUCCESS") color=$G ;;
        "ERROR") color=$RED ;;
        "WARN")  color=$YE ;;
    esac

    echo -e "${color}[${level}] ${message}${NC}"
}

# Function to check if emulator is running
is_emulator_running() {
    adb devices | grep -q "emulator"
    return $?
}

# Function to check if required environment variables are set
check_requirements() {
    if [[ -z "${EMULATOR_NAME}" ]]; then
        log_message "ERROR" "EMULATOR_NAME environment variable is not set"
        exit 1
    fi
}

# Function to start the emulator
start_emulator() {
    local emulator_name=$1
    
    log_message "INFO" "Starting emulator: ${emulator_name}"
    
    # Check if KVM is available
    if [[ -c /dev/kvm ]]; then
        log_message "INFO" "KVM acceleration is available"
        emulator -avd "${emulator_name}" -no-boot-anim -gpu off -accel on
    else
        log_message "WARN" "KVM acceleration is not available, emulator might run slower"
        emulator -avd "${emulator_name}" -no-boot-anim -gpu off
    fi
}

# Function to wait for emulator to be ready
wait_emulator_to_be_ready() {
    local timeout=$1
    local start_time=$(date +%s)
    local current_time
    
    while true; do
        if is_emulator_running; then
            log_message "SUCCESS" "Emulator ${EMULATOR_NAME} has started successfully!"
            return 0
        fi
        
        current_time=$(date +%s)
        if (( current_time - start_time >= timeout )); then
            log_message "ERROR" "Timeout waiting for emulator to start"
            return 1
        fi
        
        sleep 5
    done
}

# Function to disable animations
disable_animations() {
    local retry=0
    
    while (( retry < ADB_RETRY_ATTEMPTS )); do
        if adb shell settings put global window_animation_scale 0.0 && \
           adb shell settings put global transition_animation_scale 0.0 && \
           adb shell settings put global animator_duration_scale 0.0; then
            log_message "SUCCESS" "Animations disabled successfully"
            return 0
        fi
        
        log_message "WARN" "Failed to disable animations, retrying..."
        ((retry++))
        sleep $SLEEP_BETWEEN_ATTEMPTS
    done
    
    log_message "ERROR" "Failed to disable animations after ${ADB_RETRY_ATTEMPTS} attempts"
    return 1
}

# Main execution
main() {
    check_requirements
    
    # Start emulator
    start_emulator "${EMULATOR_NAME}"
    
    # Wait for emulator to be ready
    if ! wait_emulator_to_be_ready "$BOOT_TIMEOUT"; then
        log_message "ERROR" "Failed to start emulator"
        exit 1
    fi
    
    # Disable animations
    if ! disable_animations; then
        log_message "ERROR" "Failed to configure emulator"
        exit 1
    fi
    
    log_message "SUCCESS" "Emulator setup completed successfully"
}

# Execute main function
main
