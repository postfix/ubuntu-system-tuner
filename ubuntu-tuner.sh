#!/usr/bin/env bash
# ubuntu-tuner.sh
# Tuning script for Ubuntu 24.04+ on laptops (NVRAM/NVMe systems)
# Author: ChatGPT + User
# Requires: Bash 4.4+ (for set -o pipefail, function definitions, and associative arrays if extended)

# Must be run as root
if [[ $(id -u) -ne 0 ]]; then
    echo "Error: This script must be run as root. Use sudo $0 [options]"
    exit 1
fi

# Exit immediately on error, unset variables, or pipe failures
set -euo pipefail

# Determine the original non-root user for GUI/settings commands
ORIGINAL_USER="${SUDO_USER:-$(logname)}"

# --- Dry-run handling ---
DRY_RUN=false
if [[ ${1:-} == "--dry-run" ]]; then
    DRY_RUN=true
    shift
fi

# Wrapper to run commands or echo in dry-run
run_cmd() {
    if [[ "$DRY_RUN" == true ]]; then
        echo "[DRY RUN] $*"
    else
        "$@"
    fi
}

# --- Variables ---
ZRAM_PERCENT=50
ZRAM_ALGO="zstd"

# --- Functions ---

check_nvme() {
    echo "> Checking for NVMe drive..."
    if lsblk -d -n -o NAME,ROTA | grep -qE '^nvme.* 0$'; then
        echo "✅ NVMe drive detected."
    else
        echo "⚠️  No NVMe drive found. Proceeding anyway."
    fi
}

disable_swap_partition() {
    echo "> Disabling swap partition if active..."
    if grep -qE '^\s*[^#].*\sswap\s' /etc/fstab; then
        run_cmd swapoff -a || true
        run_cmd sed -i.bak -E 's/^(\s*[^#].*\sswap\s.*)/#\1/' /etc/fstab
        echo "✅ Swap partition disabled in /etc/fstab (backup created)."
    else
        echo "ℹ️  No active swap entries found in /etc/fstab. Skipping."
    fi
}

enable_trim() {
    echo "> Enabling fstrim.timer..."
    run_cmd systemctl enable --now fstrim.timer
    echo "✅ fstrim.timer enabled."
}

tune_fstab() {
    echo "> Ensuring noatime option on root filesystem..."
    if grep -qE '\s/\s.*noatime' /etc/fstab; then
        echo "ℹ️  'noatime' already present in /etc/fstab. Skipping."
    else
        echo "🔧 Adding 'noatime' to root filesystem entry in /etc/fstab..."
        run_cmd sed -i.bak '/\s/\s.*ext4\s/ s/defaults/defaults,noatime/' /etc/fstab
        echo "✅ 'noatime' added (backup created)."
    fi
}

setup_zram() {
    echo "> Setting up zRAM..."
    run_cmd apt update
    run_cmd apt install -y zram-config
    if [[ "$DRY_RUN" == true ]]; then
        echo "[DRY RUN] Would write /etc/default/zramswap: ALGO=$ZRAM_ALGO, PERCENT=$ZRAM_PERCENT"
    else
        cat <<EOF >/etc/default/zramswap
ALGO=$ZRAM_ALGO
PERCENT=$ZRAM_PERCENT
PRIORITY=100
EOF
    fi
    echo "✅ zRAM configured with $ZRAM_ALGO compression and $ZRAM_PERCENT% of RAM."
    run_cmd systemctl restart zramswap.service || true
}

optimize_sysctl() {
    echo "> Tuning sysctl parameters..."
    if [[ "$DRY_RUN" == true ]]; then
        echo "[DRY RUN] Would append to /etc/sysctl.conf: vm.swappiness=10, vm.vfs_cache_pressure=50"
    else
        cat <<EOF >>/etc/sysctl.conf
# Custom tuning for NVRAM/NVMe laptop
vm.swappiness=10
vm.vfs_cache_pressure=50
EOF
        sysctl -p
    fi
    echo "✅ sysctl tuned."
}

basic_cleanup() {
    echo "> Optional: removing snap Firefox if found..."
    if snap list | grep -q firefox; then
        run_cmd snap remove firefox || true
        run_cmd add-apt-repository -y ppa:mozillateam/ppa
        run_cmd apt update
        run_cmd apt install -y firefox
        run_cmd apt-mark hold firefox
        echo "✅ Replaced Snap Firefox with .deb."
    fi
}

install_flatpak() {
    echo "> Installing Flatpak and Flathub (system-wide)..."
    run_cmd apt install -y flatpak gnome-software-plugin-flatpak
    run_cmd flatpak remote-add --system --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    echo "✅ Flatpak and Flathub installed (system-wide)."
}

install_tlp_cpufreq() {
    echo "> Installing TLP and auto-cpufreq..."
    run_cmd apt install -y tlp auto-cpufreq
    run_cmd systemctl enable --now tlp
    run_cmd systemctl enable --now auto-cpufreq
    echo "✅ TLP and auto-cpufreq installed and enabled."
}

disable_gnome_animations() {
    echo "> Disabling GNOME animations for user $ORIGINAL_USER..."
    if [[ $(id -u) -eq 0 ]]; then
        run_cmd sudo -u "$ORIGINAL_USER" gsettings set org.gnome.desktop.interface enable-animations false
    else
        run_cmd gsettings set org.gnome.desktop.interface enable-animations false
    fi
    echo "✅ GNOME animations disabled."
}

install_media_codecs() {
    echo "> Installing media codecs..."
    run_cmd apt install -y ubuntu-restricted-extras
    echo "✅ Media codecs installed."
}

show_usage() {
    echo "Usage: $0 [--dry-run] [--minimal | --battery | --full]"
    exit 1
}

run_minimal() {
    check_nvme
    disable_swap_partition
    enable_trim
    tune_fstab
    setup_zram
    optimize_sysctl
}

run_battery() {
    install_tlp_cpufreq
}

run_full() {
    run_minimal
    basic_cleanup
    install_flatpak
    install_tlp_cpufreq
    disable_gnome_animations
    install_media_codecs
}

# --- Main execution ---
if [[ $# -lt 1 ]]; then
    show_usage
fi
case "$1" in
    --minimal)
        echo "> Running minimal system tuning${DRY_RUN:+ (dry-run)}..."
        run_minimal
        ;;
    --battery)
        echo "> Running battery optimization only${DRY_RUN:+ (dry-run)}..."
        run_battery
        ;;
    --full)
        echo "> Running full production tuning${DRY_RUN:+ (dry-run)}..."
        run_full
        ;;
    *)
        show_usage
        ;;
esac

# --- Final Report ---
printf "\n✅ Ubuntu tuning completed! Recommended to reboot now.\n"
