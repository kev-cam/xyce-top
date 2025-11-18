#!/bin/bash
# Interactive Xyce Build Script
# Handles dependencies, Trilinos, and Xyce automatically

set -e

CONFIG_FILE="$HOME/.xyce-build-config"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Load or create config
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        info "Loaded configuration from $CONFIG_FILE"
        echo "Current settings:"
        echo "  XYCE_SOURCE: $XYCE_SOURCE"
        echo "  BUILD_DIR: $BUILD_DIR"
        echo "  INSTALL_PREFIX: $INSTALL_PREFIX"
        echo "  TRILINOS_INSTALL: $TRILINOS_INSTALL"
        echo "  NUM_JOBS: $NUM_JOBS"
        echo ""
        read -p "Use these settings? [Y/n] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]] && [[ ! -z $REPLY ]]; then
            configure
        fi
    else
        configure
    fi
}

configure() {
    info "Xyce Build Configuration"
    echo ""

    # Xyce source location
    read -p "Path to Xyce source directory [$(pwd)]: " src
    XYCE_SOURCE="${src:-$(pwd)}"
    [ ! -d "$XYCE_SOURCE" ] && error "Directory $XYCE_SOURCE does not exist"

    # Build directory
    read -p "Build directory [$HOME/xyce-build]: " bdir
    BUILD_DIR="${bdir:-$HOME/xyce-build}"

    # Install prefix
    read -p "Install prefix [/usr/local/xyce]: " prefix
    INSTALL_PREFIX="${prefix:-/usr/local/xyce}"

    # Trilinos location
    read -p "Trilinos install directory [$HOME/trilinos]: " trilinos
    TRILINOS_INSTALL="${trilinos:-$HOME/trilinos}"

    # Number of parallel jobs
    NPROC=$(nproc 2>/dev/null || echo 4)
    read -p "Number of parallel build jobs [$NPROC]: " jobs
    NUM_JOBS="${jobs:-$NPROC}"

    # Save config
    cat > "$CONFIG_FILE" << EOF
XYCE_SOURCE="$XYCE_SOURCE"
BUILD_DIR="$BUILD_DIR"
INSTALL_PREFIX="$INSTALL_PREFIX"
TRILINOS_INSTALL="$TRILINOS_INSTALL"
NUM_JOBS="$NUM_JOBS"
EOF
    info "Configuration saved to $CONFIG_FILE"
}

check_dependencies() {
    info "Checking dependencies..."

    local missing=()

    command -v cmake >/dev/null || missing+=("cmake")
    command -v g++ >/dev/null || missing+=("g++")
    command -v gfortran >/dev/null || missing+=("gfortran")
    command -v flex >/dev/null || missing+=("flex")
    command -v bison >/dev/null || missing+=("bison")

    if [ ${#missing[@]} -gt 0 ]; then
        error "Missing dependencies: ${missing[*]}\nInstall with: sudo apt-get install cmake g++ gfortran flex bison liblapack-dev libblas-dev libsuitesparse-dev"
    fi

    info "All dependencies found!"
}

check_trilinos() {
    if [ -d "$TRILINOS_INSTALL" ] && [ -f "$TRILINOS_INSTALL/lib/cmake/Trilinos/TrilinosConfig.cmake" ]; then
        info "Trilinos found at $TRILINOS_INSTALL"
        return 0
    else
        warn "Trilinos not found at $TRILINOS_INSTALL"
        echo ""
        echo "You need to build Trilinos first. Options:"
        echo "  1. Build Trilinos automatically (recommended)"
        echo "  2. I've already built Trilinos elsewhere (specify path)"
        echo "  3. Exit and build Trilinos manually"
        echo ""
        read -p "Choose [1-3]: " choice

        case $choice in
            1) build_trilinos ;;
            2)
                read -p "Enter Trilinos install path: " path
                TRILINOS_INSTALL="$path"
                [ ! -f "$TRILINOS_INSTALL/lib/cmake/Trilinos/TrilinosConfig.cmake" ] && error "Trilinos not found at $path"
                ;;
            *) error "Please build Trilinos first. See INSTALL.md for details." ;;
        esac
    fi
}

build_trilinos() {
    info "Building Trilinos 14.4..."

    local TRILINOS_SRC="$HOME/Trilinos-trilinos-release-14-4-branch"
    local TRILINOS_BUILD="$HOME/trilinos-build"

    # Download if needed
    if [ ! -d "$TRILINOS_SRC" ]; then
        info "Downloading Trilinos..."
        cd "$HOME"
        wget -q --show-progress https://github.com/trilinos/Trilinos/archive/refs/heads/trilinos-release-14-4-branch.zip
        unzip -q trilinos-release-14-4-branch.zip
        rm trilinos-release-14-4-branch.zip
    fi

    # Build
    mkdir -p "$TRILINOS_BUILD"
    cd "$TRILINOS_BUILD"

    info "Configuring Trilinos (this may take a few minutes)..."
    cmake \
        -C "$XYCE_SOURCE/cmake/trilinos/trilinos-base.cmake" \
        -D CMAKE_INSTALL_PREFIX="$TRILINOS_INSTALL" \
        -D AMD_INCLUDE_DIRS=/usr/include/suitesparse \
        "$TRILINOS_SRC" > /dev/null

    info "Building Trilinos (this will take 20-30 minutes)..."
    cmake --build . -j "$NUM_JOBS" -t install

    info "Trilinos installed to $TRILINOS_INSTALL"
}

build_xyce() {
    info "Building Xyce..."

    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"

    info "Configuring Xyce..."
    cmake \
        -D CMAKE_INSTALL_PREFIX="$INSTALL_PREFIX" \
        -D Trilinos_ROOT="$TRILINOS_INSTALL" \
        -D AMD_INCLUDE_DIRS=/usr/include/suitesparse \
        "$XYCE_SOURCE"

    info "Building Xyce (this will take 10-15 minutes)..."
    cmake --build . -j "$NUM_JOBS"

    info "Installing Xyce to $INSTALL_PREFIX..."
    cmake --build . -t install

    info "Build complete!"
    echo ""
    echo "Xyce installed to: $INSTALL_PREFIX"
    echo "Binary location: $INSTALL_PREFIX/bin/Xyce"
    echo ""
    echo "Test with: $INSTALL_PREFIX/bin/Xyce -v"
}

# Main execution
main() {
    echo "================================"
    echo "  Xyce Automated Build Script"
    echo "================================"
    echo ""

    load_config
    check_dependencies
    check_trilinos
    build_xyce

    info "All done! 🎉"
}

# Run if not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
