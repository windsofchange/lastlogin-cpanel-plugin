#!/usr/bin/env bash
# =============================================================================
# install.sh — cPanel Login Log Plugin Installer
#
# Installs the plugin for whichever cPanel themes are present on this server
# (jupiter and/or paper_lantern). Themes that are not installed are skipped
# automatically — no manual configuration required.
#
# Usage: sudo ./install.sh
# =============================================================================

set -euo pipefail

CPANEL_FRONTEND="/usr/local/cpanel/base/frontend"
PLUGIN_TAR="loginlog.tar"

# ── Locate install_plugin ──────────────────────────────────────────────────
# cPanel places it in scripts/ on most versions; some builds also have a
# bin/ symlink.
if   [[ -x "/usr/local/cpanel/scripts/install_plugin" ]]; then
    INSTALL_BIN="/usr/local/cpanel/scripts/install_plugin"
elif [[ -x "/usr/local/cpanel/bin/install_plugin" ]]; then
    INSTALL_BIN="/usr/local/cpanel/bin/install_plugin"
else
    echo "Error: install_plugin not found. Is cPanel installed on this server?" >&2
    exit 1
fi

# ── Root check ─────────────────────────────────────────────────────────────
if [[ "${EUID}" -ne 0 ]]; then
    echo "Error: This script must be run as root (sudo)." >&2
    exit 1
fi

# ── Pre-flight: required source files ──────────────────────────────────────
for required in "${PLUGIN_TAR}" "lastlogin.live.php" "src/Account.php" \
                "src/hostname.php" "assets/css/main.css" "loginlog.svg"; do
    if [[ ! -f "${required}" ]]; then
        echo "Error: Required file not found: ${required}" >&2
        exit 1
    fi
done

# ── Helper: install into one theme ─────────────────────────────────────────
install_theme() {
    local theme="${1}"
    local theme_dir="${CPANEL_FRONTEND}/${theme}"
    local plugin_dir="${theme_dir}/loginlog"

    # Skip themes that are not installed on this server
    if [[ ! -d "${theme_dir}" ]]; then
        echo "  → theme '${theme}' not found on this server, skipping."
        return 0
    fi

    echo "Installing for theme: ${theme} …"

    mkdir -p "${plugin_dir}/src"
    mkdir -p "${plugin_dir}/assets/css"

    cp "${PLUGIN_TAR}"        "${plugin_dir}/"
    cp "lastlogin.live.php"   "${plugin_dir}/"
    cp "src/Account.php"      "${plugin_dir}/src/"
    cp "src/hostname.php"     "${plugin_dir}/src/"
    cp "assets/css/main.css"  "${plugin_dir}/assets/css/"
    cp "loginlog.svg"         "${plugin_dir}/"

    "${INSTALL_BIN}" "${plugin_dir}/${PLUGIN_TAR}" --theme "${theme}"
    echo "  → ${theme} install complete."
}

# ── Install for each supported theme ───────────────────────────────────────
INSTALLED=0

for theme in jupiter paper_lantern; do
    install_theme "${theme}" && INSTALLED=$(( INSTALLED + 1 ))
done

echo ""
if [[ "${INSTALLED}" -eq 0 ]]; then
    echo "Warning: No supported cPanel themes were found. Nothing was installed." >&2
    exit 1
fi

echo "Plugin installed successfully."
