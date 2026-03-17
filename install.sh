#!/usr/bin/env bash
# =============================================================================
# install.sh — cPanel Login Log Plugin Installer
#
# Installs the plugin for whichever cPanel themes are present on this server
# (jupiter and/or paper_lantern). Themes not installed on the server are
# skipped automatically.
#
# Usage: sudo ./install.sh
# =============================================================================

set -euo pipefail

CPANEL_FRONTEND="/usr/local/cpanel/base/frontend"
PLUGIN_TAR="loginlog.tar"
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Locate install_plugin ──────────────────────────────────────────────────
if   [[ -x "/usr/local/cpanel/scripts/install_plugin" ]]; then
    INSTALL_BIN="/usr/local/cpanel/scripts/install_plugin"
elif [[ -x "/usr/local/cpanel/bin/install_plugin" ]]; then
    INSTALL_BIN="/usr/local/cpanel/bin/install_plugin"
else
    echo "Error: install_plugin not found. Is cPanel installed on this server?" >&2
    exit 1
fi

# ── Locate rebuild_sprites ─────────────────────────────────────────────────
# Must be run after install_plugin so cPanel generates the icon CSS class
# (icon-loginlog). Without this step the icon is undefined and does not appear.
if   [[ -x "/usr/local/cpanel/scripts/rebuild_sprites" ]]; then
    REBUILD_BIN="/usr/local/cpanel/scripts/rebuild_sprites"
elif [[ -x "/usr/local/cpanel/bin/rebuild_sprites" ]]; then
    REBUILD_BIN="/usr/local/cpanel/bin/rebuild_sprites"
else
    REBUILD_BIN=""
fi

# ── Root check ─────────────────────────────────────────────────────────────
if [[ "${EUID}" -ne 0 ]]; then
    echo "Error: This script must be run as root (sudo)." >&2
    exit 1
fi

# ── Pre-flight: required source files ──────────────────────────────────────
cd "${SOURCE_DIR}"
for required in "${PLUGIN_TAR}" "lastlogin.live.php" "src/Account.php" \
                "src/hostname.php" "assets/css/main.css" "loginlog.svg"; do
    if [[ ! -f "${required}" ]]; then
        echo "Error: Required file not found: ${SOURCE_DIR}/${required}" >&2
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

    # Step 1: Register the plugin with cPanel using the tar from the source
    # directory (relative path). install_plugin reads install.json from the
    # tar, extracts the icon/metadata files, and registers the plugin entry.
    # Important: call from SOURCE_DIR so the relative tar path resolves correctly.
    "${INSTALL_BIN}" "${PLUGIN_TAR}" --theme "${theme}"

    # Step 2: Copy PHP source files and assets into the plugin directory that
    # install_plugin just created/updated.
    mkdir -p "${plugin_dir}/src"
    mkdir -p "${plugin_dir}/assets/css"

    cp "lastlogin.live.php"  "${plugin_dir}/"
    cp "src/Account.php"     "${plugin_dir}/src/"
    cp "src/hostname.php"    "${plugin_dir}/src/"
    cp "assets/css/main.css" "${plugin_dir}/assets/css/"
    cp "loginlog.svg"        "${plugin_dir}/"

    # Step 3: Ensure all plugin files are world-readable by the cpanel process
    chmod -R 755 "${plugin_dir}"
    find "${plugin_dir}" -type f -exec chmod 644 {} \;

    echo "  → ${theme} install complete."
    return 1  # signal that at least one theme was installed
}

# ── Install for each supported theme ───────────────────────────────────────
INSTALLED=0
for theme in jupiter paper_lantern; do
    install_theme "${theme}" || INSTALLED=$(( INSTALLED + 1 ))
done

echo ""
if [[ "${INSTALLED}" -eq 0 ]]; then
    echo "Warning: No supported cPanel themes were found. Nothing was installed." >&2
    exit 1
fi

# ── Rebuild sprites / icon CSS ─────────────────────────────────────────────
# This regenerates the CSS that maps icon-{plugin_id} classes to the SVG
# files. Without this step the 'icon-loginlog' class is undefined and the
# icon does not appear in the cPanel dashboard.
if [[ -n "${REBUILD_BIN}" ]]; then
    echo "Rebuilding cPanel icon sprites …"
    "${REBUILD_BIN}"
    echo "  → sprites rebuilt."
else
    echo "Note: rebuild_sprites not found — if the icon does not appear, run:"
    echo "  /usr/local/cpanel/scripts/rebuild_sprites"
fi

echo ""
echo "Plugin installed successfully."
