#!/usr/bin/env bash
# Install Kiro AI assets to user-level directories
set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
KIRO_DIR="${HOME}/.kiro"

install_agents() {
    echo "Installing agents..."
    mkdir -p "${KIRO_DIR}/agents"
    find "${REPO_ROOT}/agents" -name "*.json" -exec cp -v {} "${KIRO_DIR}/agents/" \;
    if [ -d "${REPO_ROOT}/agents/prompts" ]; then
        mkdir -p "${KIRO_DIR}/agents/prompts"
        find "${REPO_ROOT}/agents/prompts" -type f ! -name ".gitkeep" -exec cp -v {} "${KIRO_DIR}/agents/prompts/" \;
    fi
}

install_skills() {
    echo "Installing skills..."
    mkdir -p "${KIRO_DIR}/skills"
    for skill_dir in "${REPO_ROOT}"/skills/*/; do
        [ -d "$skill_dir" ] || continue
        skill_name=$(basename "$skill_dir")
        echo "  -> ${skill_name}"
        cp -r "$skill_dir" "${KIRO_DIR}/skills/"
    done
}

install_hooks() {
    echo "Installing hooks..."
    mkdir -p "${KIRO_DIR}/hooks"
    find "${REPO_ROOT}/hooks" -name "*.json" -exec cp -v {} "${KIRO_DIR}/hooks/" \;
}

install_steering() {
    echo "Installing steering rules..."
    mkdir -p "${KIRO_DIR}/steering"
    find "${REPO_ROOT}/steering" -name "*.md" ! -name "README.md" -exec cp -v {} "${KIRO_DIR}/steering/" \;
}

show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Install Kiro AI assets to ~/.kiro/"
    echo ""
    echo "Options:"
    echo "  --agents     Install agents only"
    echo "  --skills     Install skills only"
    echo "  --hooks      Install hooks only"
    echo "  --steering   Install steering rules only"
    echo "  --help       Show this help message"
    echo ""
    echo "Without options, installs all asset types."
}

if [ $# -eq 0 ]; then
    install_agents
    install_skills
    install_hooks
    install_steering
    echo "Done! All assets installed to ${KIRO_DIR}/"
    exit 0
fi

for arg in "$@"; do
    case "$arg" in
        --agents)   install_agents ;;
        --skills)   install_skills ;;
        --hooks)    install_hooks ;;
        --steering) install_steering ;;
        --help)     show_help; exit 0 ;;
        *)          echo "Unknown option: $arg"; show_help; exit 1 ;;
    esac
done

echo "Done!"
