#!/bin/bash
# RealMail - Build and Run Script
# Builds and launches the RealMail macOS email client

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

print_status() { echo -e "${BLUE}==>${NC} $1"; }
print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }
print_header() { echo -e "\n${CYAN}━━━ $1 ━━━${NC}\n"; }

# Check requirements
check_requirements() {
    if ! command -v swift &> /dev/null; then
        print_error "Swift not found! Please install Xcode or Swift toolchain."
        exit 1
    fi

    SWIFT_VERSION=$(swift --version 2>&1 | head -1)
    print_status "Using: $SWIFT_VERSION"
}

# Build the application
build() {
    print_header "Building RealMail"

    swift build --configuration "${1:-debug}" 2>&1 | while IFS= read -r line; do
        if [[ "$line" == *"error:"* ]]; then
            print_error "$line"
        elif [[ "$line" == *"warning:"* ]]; then
            print_warning "$line"
        elif [[ "$line" == *"Build complete!"* ]]; then
            print_success "$line"
        elif [[ "$line" == *"Compiling"* ]]; then
            echo -e "  ${BLUE}○${NC} $line"
        else
            echo "  $line"
        fi
    done

    if [ ${PIPESTATUS[0]} -ne 0 ]; then
        print_error "Build failed!"
        exit 1
    fi

    print_success "Build completed successfully"
}

# Run the application
run() {
    local config="${1:-debug}"
    local executable=".build/$config/RealMail"

    if [ ! -f "$executable" ]; then
        print_warning "Executable not found, building first..."
        build "$config"
    fi

    print_header "Running RealMail"
    print_status "Launching application..."

    # For a macOS app, we need to run it
    "$executable"
}

# Run tests
test_app() {
    print_header "Running Tests"

    swift test 2>&1 | while IFS= read -r line; do
        if [[ "$line" == *"passed"* ]]; then
            print_success "$line"
        elif [[ "$line" == *"failed"* ]]; then
            print_error "$line"
        elif [[ "$line" == *"Test Suite"* ]]; then
            echo -e "  ${CYAN}▶${NC} $line"
        else
            echo "  $line"
        fi
    done

    if [ ${PIPESTATUS[0]} -ne 0 ]; then
        print_error "Tests failed!"
        exit 1
    fi

    print_success "All tests passed"
}

# Clean build artifacts
clean() {
    print_header "Cleaning"
    rm -rf .build
    rm -rf .swiftpm
    print_success "Build artifacts cleaned"
}

# Open in Xcode (generates xcodeproj if needed)
open_xcode() {
    print_header "Opening in Xcode"

    if [ ! -d "RealMail.xcodeproj" ]; then
        print_status "Generating Xcode project..."
        swift package generate-xcodeproj 2>/dev/null || {
            print_warning "Could not generate xcodeproj, opening Package.swift instead"
            open Package.swift
            return
        }
    fi

    open RealMail.xcodeproj
    print_success "Opened in Xcode"
}

# Show help
usage() {
    echo ""
    echo -e "${CYAN}RealMail${NC} - Native macOS Email Client"
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  run [debug|release]   Build and run the application (default: debug)"
    echo "  build [debug|release] Build only (default: debug)"
    echo "  test                  Run unit tests"
    echo "  clean                 Remove build artifacts"
    echo "  xcode                 Open project in Xcode"
    echo "  help                  Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                    # Build and run in debug mode"
    echo "  $0 build release      # Build release version"
    echo "  $0 test               # Run all unit tests"
    echo ""
}

# Watch for changes and rebuild (development mode)
watch() {
    print_header "Development Mode"
    print_status "Watching for changes... (Ctrl+C to stop)"

    if command -v fswatch &> /dev/null; then
        fswatch -o RealMail/ | while read; do
            clear
            build debug
        done
    else
        print_warning "fswatch not installed. Install with: brew install fswatch"
        print_status "Running single build instead..."
        build debug
    fi
}

# Main entry point
main() {
    check_requirements

    case "${1:-run}" in
        run)
            build "${2:-debug}"
            run "${2:-debug}"
            ;;
        build)
            build "${2:-debug}"
            ;;
        test)
            test_app
            ;;
        clean)
            clean
            ;;
        xcode|open)
            open_xcode
            ;;
        watch|dev)
            watch
            ;;
        help|--help|-h)
            usage
            ;;
        *)
            print_error "Unknown command: $1"
            usage
            exit 1
            ;;
    esac
}

main "$@"
