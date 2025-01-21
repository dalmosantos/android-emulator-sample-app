#!/bin/bash

# Constants
declare -r DEFAULT_TIMEOUT=300
declare -r DEFAULT_MEMORY=3072

# Color definitions
declare -r BL='\033[0;34m'
declare -r G='\033[0;32m'
declare -r RED='\033[0;31m'
declare -r YE='\033[1;33m'
declare -r NC='\033[0m'

# Input validation
if [[ -z "${EMULATOR_NAME}" ]]; then
    echo "${RED}Error: EMULATOR_NAME environment variable is not set${NC}"
    exit 1
fi

function check_hardware_acceleration() {
    local hw_accel_flag

    if [[ -n "$HW_ACCEL_OVERRIDE" ]]; then
        hw_accel_flag="$HW_ACCEL_OVERRIDE"
    else
        local hw_accel_support
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS-specific hardware acceleration check
            hw_accel_support=$(sysctl -a | grep -E -c '(vmx|svm)')
        else
            # generic Linux hardware acceleration check
            hw_accel_support=$(grep -E -c '(vmx|svm)' /proc/cpuinfo)
        fi

        hw_accel_flag="-accel $(( hw_accel_support > 0 ? "on" : "off" ))"
    fi

    echo "$hw_accel_flag"
}

function launch_emulator() {
    local hw_accel_flag=$(check_hardware_acceleration)
    local options="@${EMULATOR_NAME} -no-window -no-snapshot -screen no-touch -noaudio -memory ${DEFAULT_MEMORY} -no-boot-anim ${hw_accel_flag} -camera-back none"
    
    # Kill existing emulator instances
    if ! adb devices | grep emulator | cut -f1 | xargs -I {} adb -s "{}" emu kill; then
        echo "${RED}Warning: Failed to kill existing emulator instances${NC}"
    fi

    case "${OSTYPE}" in
        *linux*)
            echo "${OSTYPE}: emulator ${options} -gpu off"
            nohup emulator ${options} -gpu off & ;;
        *darwin*|*macos*)
            echo "${OSTYPE}: emulator ${options} -gpu swiftshader_indirect"
            nohup emulator ${options} -gpu swiftshader_indirect & ;;
        *)
            echo "${RED}Error: Unsupported operating system: ${OSTYPE}${NC}"
            return 1 ;;
    esac

    local exit_code=$?
    if [[ ${exit_code} -ne 0 ]]; then
        echo "${RED}Error launching emulator (exit code: ${exit_code})${NC}"
        return 1
    fi
}

function check_emulator_status() {
    local -r timeout=${EMULATOR_TIMEOUT:-${DEFAULT_TIMEOUT}}
    local -r spinner=("⠹" "⠺" "⠼" "⠶" "⠦" "⠧" "⠇" "⠏")
    local start_time=$(date +%s)
    local i=0

    printf "${G}==>${BL} Checking emulator booting up status 🧐${NC}\n"

    while true; do
        local result=$(adb shell getprop sys.boot_completed 2>&1)
        local current_time=$(date +%s)
        local elapsed_time=$((current_time - start_time))

        case "${result}" in
            "1")
                printf "\e[K${G}==>${G} ✓ Emulator is ready${NC}\n"
                adb devices -l
                adb shell input keyevent 82
                return 0
                ;;
            "")
                printf "${YE}==>${YE} Emulator is partially Booted! 😕 ${spinner[$i]} ${NC}\r"
                ;;
            *)
                printf "${RED}==>${RED} ${result}, please wait ${spinner[$i]} ${NC}\r"
                ;;
        esac

        if [[ ${elapsed_time} -gt ${timeout} ]]; then
            printf "${RED}==>${RED} Timeout after ${timeout} seconds elapsed 🕛..${NC}\n"
            return 1
        fi

        i=$(( (i+1) % 8 ))
        sleep 4
    done
}

function disable_animation() {
    local commands=(
        "settings put global window_animation_scale 0.0"
        "settings put global transition_animation_scale 0.0"
        "settings put global animator_duration_scale 0.0"
    )

    for cmd in "${commands[@]}"; do
        if ! adb shell "$cmd"; then
            echo "${RED}Warning: Failed to execute: $cmd${NC}"
        fi
    done
}

function hidden_policy() {
    local policy_command="settings put global hidden_api_policy_pre_p_apps 1;settings put global hidden_api_policy_p_apps 1;settings put global hidden_api_policy 1"
    
    if ! adb shell "${policy_command}"; then
        echo "${RED}Warning: Failed to set hidden API policy${NC}"
        return 1
    fi
}

function main() {
    if ! launch_emulator; then
        echo "${RED}Failed to launch emulator${NC}"
        exit 1
    fi

    sleep 2

    if ! check_emulator_status; then
        echo "${RED}Emulator failed to start properly${NC}"
        exit 1
    fi

    sleep 1
    
    if ! disable_animation; then
        echo "${YE}Warning: Failed to disable animations${NC}"
    fi
    
    sleep 1
    
    if ! hidden_policy; then
        echo "${YE}Warning: Failed to set hidden policy${NC}"
    fi
    
    sleep 1
    
    echo "${G}Emulator setup completed successfully${NC}"
}

# Execute main function
main
