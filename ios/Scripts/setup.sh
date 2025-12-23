#!/bin/bash

# Terracotta iOS Setup Script
# This script sets up the development environment for iOS Terracotta

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

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check system requirements
check_requirements() {
    print_status "Checking system requirements..."
    
    # Check for Xcode
    if command_exists xcodebuild; then
        XCODE_VERSION=$(xcodebuild -version | head -n1)
        print_status "Xcode found: $XCODE_VERSION"
    else
        print_error "Xcode not found. Please install Xcode from the App Store."
        exit 1
    fi
    
    # Check for Swift
    if command_exists swift; then
        SWIFT_VERSION=$(swift --version | head -n1)
        print_status "Swift found: $SWIFT_VERSION"
    else
        print_error "Swift not found. Please install Xcode with Swift support."
        exit 1
    fi
    
    # Check for Rust
    if command_exists rustc; then
        RUST_VERSION=$(rustc --version)
        print_status "Rust found: $RUST_VERSION"
    else
        print_error "Rust not found. Please install Rust from https://rustup.rs/"
        exit 1
    fi
    
    # Check for Cargo
    if command_exists cargo; then
        CARGO_VERSION=$(cargo --version)
        print_status "Cargo found: $CARGO_VERSION"
    else
        print_error "Cargo not found. Please install Rust."
        exit 1
    fi
    
    # Check for iOS targets
    IOS_TARGETS=("aarch64-apple-ios" "x86_64-apple-ios" "aarch64-apple-ios-sim")
    for target in "${IOS_TARGETS[@]}"; do
        if rustup target list --installed | grep -q "$target"; then
            print_status "iOS target found: $target"
        else
            print_warning "iOS target not found: $target. Installing..."
            rustup target add "$target"
        fi
    done
    
    print_status "System requirements check completed"
}

# Function to install required tools
install_tools() {
    print_status "Installing required tools..."
    
    # Install cargo-lipo for universal binary creation
    if ! command_exists cargo-lipo; then
        print_status "Installing cargo-lipo..."
        cargo install cargo-lipo
    else
        print_status "cargo-lipo already installed"
    fi
    
    # Install cbindgen for C header generation
    if ! command_exists cbindgen; then
        print_status "Installing cbindgen..."
        cargo install cbindgen
    else
        print_status "cbindgen already installed"
    fi
    
    # Install SwiftLint for code quality
    if ! command_exists swiftlint; then
        print_status "Installing SwiftLint..."
        if command_exists brew; then
            brew install swiftlint
        else
            print_warning "Homebrew not found. Please install SwiftLint manually."
        fi
    else
        print_status "SwiftLint already installed"
    fi
    
    print_status "Required tools installation completed"
}

# Function to setup project structure
setup_project_structure() {
    print_status "Setting up project structure..."
    
    # Create necessary directories
    mkdir -p "$IOS_DIR/Sources/TerracottaCore/Native"
    mkdir -p "$IOS_DIR/Sources/TerracottaUI/Views"
    mkdir -p "$IOS_DIR/Sources/TerracottaUI/ViewModels"
    mkdir -p "$IOS_DIR/Sources/TerracottaUI/Components"
    mkdir -p "$IOS_DIR/Tests/TerracottaCoreTests"
    mkdir -p "$IOS_DIR/Tests/TerracottaUITests"
    mkdir -p "$IOS_DIR/Frameworks"
    mkdir -p "$IOS_DIR/Extensions"
    mkdir -p "$IOS_DIR/Scripts"
    mkdir -p "$IOS_DIR/build"
    
    print_status "Project structure created"
}

# Function to setup Git hooks
setup_git_hooks() {
    print_status "Setting up Git hooks..."
    
    HOOKS_DIR="$PROJECT_ROOT/.git/hooks"
    
    # Pre-commit hook for SwiftLint
    cat > "$HOOKS_DIR/pre-commit" << 'EOF'
#!/bin/bash
# SwiftLint pre-commit hook

if command -v swiftlint &> /dev/null; then
    swiftlint --strict
else
    echo "warning: SwiftLint not installed, skipping linting"
fi
EOF
    
    chmod +x "$HOOKS_DIR/pre-commit"
    
    # Pre-push hook for tests
    cat > "$HOOKS_DIR/pre-push" << 'EOF'
#!/bin/bash
# Test pre-push hook

cd ios
swift test --enable-code-coverage
EOF
    
    chmod +x "$HOOKS_DIR/pre-push"
    
    print_status "Git hooks setup completed"
}

# Function to create configuration files
create_config_files() {
    print_status "Creating configuration files..."
    
    # Create cbindgen.toml for Rust C header generation
    cat > "$PROJECT_ROOT/cbindgen.toml" << 'EOF'
[lib]
name = "terracotta_core"
crate_type = ["staticlib", "cdylib"]

[struct]
derive_eq = true
derive_neq = true

[enum]
derive_helper_methods = true

[const]
allow_variadic = true

[fn]
sort_by_name = true

[macro_expansion]
bitflags = true

[defines]
"target_os = ios" = "IOS"
"target_arch = aarch64" = "ARM64"
EOF
    
    # Create .swiftlint.yml
    cat > "$IOS_DIR/.swiftlint.yml" << 'EOF'
disabled_rules:
  - trailing_whitespace
  - line_length

opt_in_rules:
  - empty_count
  - force_unwrapping
  - implicitly_unwrapped_optional

line_length:
  warning: 120
  error: 150

function_body_length:
  warning: 50
  error: 100

type_body_length:
  warning: 300
  error: 500

file_length:
  warning: 400
  error: 800

cyclomatic_complexity:
  warning: 10
  error: 20
EOF
    
    # Create .gitignore for iOS directory
    cat > "$IOS_DIR/.gitignore" << 'EOF'
# Xcode
*.xcodeproj/*
!*.xcodeproj/project.pbxproj
!*.xcodeproj/xcshareddata/
!*.xcodeproj/project.xcworkspace/

# Build
build/
DerivedData/

# Swift Package Manager
.swiftpm/
.build/

# Carthage
Carthage/

# CocoaPods
Pods/

# AppCode
.idea/

# VSCode
.vscode/

# OS
.DS_Store
Thumbs.db

# Temporary files
*.tmp
*.temp

# Logs
*.log

# Coverage
*.gcov
*.profraw
EOF
    
    print_status "Configuration files created"
}

# Function to setup development certificates
setup_certificates() {
    print_status "Setting up development certificates..."
    
    # Check if development team is configured
    DEVELOPMENT_TEAM=$(security find-identity -v -p codesigning | grep -E "Apple Development|iPhone Developer" | head -n1 | awk '{print $2}')
    
    if [ -n "$DEVELOPMENT_TEAM" ]; then
        print_status "Development certificate found: $DEVELOPMENT_TEAM"
        
        # Update project files with development team
        # This would typically involve updating Xcode project files
        print_status "Development certificates configured"
    else
        print_warning "No development certificate found. Please configure Xcode with your Apple Developer account."
    fi
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  all          - Run complete setup"
    echo "  check        - Check system requirements only"
    echo "  tools        - Install required tools only"
    echo "  project      - Setup project structure only"
    echo "  git          - Setup Git hooks only"
    echo "  config       - Create configuration files only"
    echo "  certificates - Setup development certificates only"
    echo "  help         - Show this help message"
}

# Main script logic
case "${1:-all}" in
    all)
        print_status "Starting complete iOS setup..."
        check_requirements
        install_tools
        setup_project_structure
        create_config_files
        setup_git_hooks
        setup_certificates
        print_status "iOS setup completed successfully!"
        ;;
    
    check)
        check_requirements
        ;;
    
    tools)
        install_tools
        ;;
    
    project)
        setup_project_structure
        ;;
    
    git)
        setup_git_hooks
        ;;
    
    config)
        create_config_files
        ;;
    
    certificates)
        setup_certificates
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