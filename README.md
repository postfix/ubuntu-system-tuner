# ubuntu-system-tuner
A modular Bash script to optimize Ubuntu 24.04+ on laptops—zRAM, swap, TRIM, fstab &amp; sysctl tweaks, power management, Flatpak &amp; media codecs, GUI polish, and more.

---

## 🚀 Features

- **Dry-run mode**  
  Preview all changes without touching your system (`--dry-run`).
- **Minimal tuning**  
  Swap → zRAM, TRIM, `noatime` in `/etc/fstab`, sysctl tweaks (`--minimal`).
- **Battery optimization**  
  Install & enable TLP and auto-cpufreq (`--battery`).
- **Full production tuning**  
  Minimal + Snap Firefox cleanup, system-wide Flatpak, GNOME animation disable, media codecs (`--full`).
- **Idempotent**  
  Each change checks current state before applying.
- **User-aware**  
  Applies GUI tweaks (`gsettings`) to your non-root profile.

---

## 📋 Requirements

- Ubuntu 24.04 or later  
- Bash 4.4+ (for `set -o pipefail`, functions, etc.)  
- Sudo privileges (to make system changes)

---

## 🛠️ Installation

```bash
git clone https://github.com/<your-org>/ubuntu-system-tuner.git
cd ubuntu-system-tuner
chmod +x ubuntu-tune.sh
```
