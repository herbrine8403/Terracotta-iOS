#!/bin/bash

# Terracotta iOS Build Script
# This script builds the Terracotta iOS app and its dependencies

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Project directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
IOS_DIR="$PROJECT_ROOT/ios"
BUILD_DIR="$IOS_DIR/build"
FRAMEWORKS_DIR="$IOS_DIR/Frameworks"

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to download ZeroTier framework
download_zerotier_framework() {
    print_status "Downloading ZeroTier framework..."
    
    ZT_VERSION="1.8.8"
    # Using the GitHub releases URL as the primary source
    ZT_FRAMEWORK_URL="https://github.com/zerotier/ZeroTierOne/releases/download/${ZT_VERSION}/ZeroTierOne-${ZT_VERSION}-iOS.zip"
    ZT_ARCHIVE="$BUILD_DIR/ZeroTierOne.zip"
    
    mkdir -p "$BUILD_DIR"
    
    if [ ! -f "$ZT_ARCHIVE" ]; then
        print_status "Attempting to download from GitHub: $ZT_FRAMEWORK_URL"
        if curl -L -o "$ZT_ARCHIVE" "$ZT_FRAMEWORK_URL"; then
            print_status "Successfully downloaded ZeroTier framework from GitHub"
        else
            # Fallback to the original URL if GitHub fails
            print_warning "GitHub download failed, trying original URL"
            ZT_FRAMEWORK_URL="https://download.zerotier.com/dist/ZeroTierOne-${ZT_VERSION}-iOS.zip"
            curl -L -o "$ZT_ARCHIVE" "$ZT_FRAMEWORK_URL"
        fi
    else
        print_status "ZeroTier archive already exists, skipping download"
    fi
    
    # Extract framework with error checking
    print_status "Extracting ZeroTier framework..."
    cd "$BUILD_DIR"
    
    # Check if the downloaded file is actually a valid zip file
    if ! file "$BUILD_DIR/ZeroTierOne.zip" | grep -q "Zip archive"; then
        print_error "Downloaded file is not a valid zip archive"
        exit 1
    fi
    
    if unzip -o "ZeroTierOne.zip"; then
        print_status "Successfully extracted ZeroTier framework"
    else
        print_error "Failed to extract ZeroTier framework archive"
        ls -la "ZeroTierOne.zip"
        file "ZeroTierOne.zip"
        exit 1
    fi
    
    # Copy framework to project
    if [ -d "ZeroTierOne.xcframework" ]; then
        rm -rf "$FRAMEWORKS_DIR/zt.framework"
        mkdir -p "$FRAMEWORKS_DIR"
        cp -r "ZeroTierOne.xcframework/ios-arm64/zt.framework" "$FRAMEWORKS_DIR/"
        print_status "ZeroTier framework installed successfully"
    elif [ -d "zt.xcframework" ]; then
        rm -rf "$FRAMEWORKS_DIR/zt.framework"
        mkdir -p "$FRAMEWORKS_DIR"
        cp -r "zt.xcframework/ios-arm64/zt.framework" "$FRAMEWORKS_DIR/"
        print_status "ZeroTier framework installed successfully"
    else
        print_error "Failed to extract ZeroTier framework - expected xcframework not found"
        ls -la
        exit 1
    fi
}

# Function to build Rust core library
build_rust_core() {
    print_status "Building Rust core library for iOS..."
    
    cd "$PROJECT_ROOT"
    
    # Install cargo-lipo if not available
    if ! command -v cargo-lipo &> /dev/null; then
        print_status "Installing cargo-lipo..."
        cargo install cargo-lipo
    fi
    
    # Install iOS targets if not available
    rustup target add aarch64-apple-ios
    rustup target add x86_64-apple-ios
    rustup target add aarch64-apple-ios-sim
    
    # Build universal library
    cargo lipo --release --targets aarch64-apple-ios,x86_64-apple-ios
    
    # Create header file from Rust code
    cbindgen --config cbindgen.toml --crate terracotta_core --output "$IOS_DIR/Sources/TerracottaCore/Native/terracotta_generated.h"
    
    print_status "Rust core library built successfully"
}

# Function to build iOS app
build_ios_app() {
    print_status "Building iOS app..."
    
    cd "$IOS_DIR"
    
    # Build for different architectures
    ARCHS="arm64 x86_64"
    
    for ARCH in $ARCHS; do
        print_status "Building for architecture: $ARCH"
        
        xcodebuild -project Terracotta.xcodeproj \
                   -scheme Terracotta \
                   -configuration Release \
                   -arch "$ARCH" \
                   -destination "generic/platform=iOS" \
                   build
    done
    
    # Create universal binary
    print_status "Creating universal binary..."
    
    APP_BUILD_DIR="$BUILD_DIR/Terracotta.app"
    mkdir -p "$APP_BUILD_DIR"
    
    # Copy app structure
    cp -r "$IOS_DIR/build/Release-iphoneos/Terracotta.app" "$BUILD_DIR/"
    
    # Create universal framework
    lipo -create \
         "$IOS_DIR/build/Release-iphoneos/Terracotta.app/Terracotta" \
         "$IOS_DIR/build/Release-iphonesimulator/Terracotta.app/Terracotta" \
         -output "$BUILD_DIR/Terracotta.app/Terracotta"
    
    print_status "iOS app built successfully"
}

# Function to run tests
run_tests() {
    print_status "Running tests..."
    
    cd "$IOS_DIR"
    
    # Run unit tests
    xcodebuild test \
               -project Terracotta.xcodeproj \
               -scheme Terracotta \
               -destination 'platform=iOS Simulator,name=iPhone 14,OS=latest'
    
    print_status "Tests completed successfully"
}

# Function to create Xcode project
create_xcode_project() {
    print_status "Creating Xcode project..."
    
    cd "$IOS_DIR"
    
    # Generate Xcode project from Swift Package
    swift package generate-xcodeproj
    
    # Configure project settings
    # This would typically involve more detailed Xcode project configuration
    # For now, we assume the basic configuration is sufficient
    
    print_status "Xcode project created successfully"
}

# Function to clean build artifacts
clean_build() {
    print_status "Cleaning build artifacts..."
    
    rm -rf "$BUILD_DIR"
    rm -rf "$IOS_DIR/.build"
    rm -rf "$IOS_DIR/Terracotta.xcodeproj"
    rm -rf "$IOS_DIR/.swiftpm"
    
    print_status "Build artifacts cleaned"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  setup        - Set up the build environment"
    echo "  build        - Build the complete iOS app"
    echo "  framework    - Download and setup ZeroTier framework"
    echo "  core         - Build Rust core library"
    echo "  app          - Build iOS app only"
    echo "  test         - Run tests"
    echo "  project      - Create Xcode project"
    echo "  clean        - Clean build artifacts"
    echo "  help         - Show this help message"
}

# Main script logic
case "${1:-build}" in
    setup)
        print_status "Setting up build environment..."
        download_zerotier_framework
        build_rust_core
        create_xcode_project
        ;;
    
    build)
        print_status "Starting complete build process..."
        download_zerotier_framework
        build_rust_core
        create_xcode_project
        build_ios_app
        ;;
    
    framework)
        download_zerotier_framework
        ;;
    
    core)
        build_rust_core
        ;;
    
    app)
        create_xcode_project
        build_ios_app
        ;;
    
    test)
        run_tests
        ;;
    
    project)
        create_xcode_project
        ;;
    
    clean)
        clean_build
        ;;
    
    help|--help|-h)
        show_usage
        ;;
    
    *)
        print_error "Unknown command: $1"
        show_usage
        exit 1
        ;;
esac

print_status "Build process completed successfully!"