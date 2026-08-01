#!/usr/bin/env bash
#
# CrashLab development environment bootstrap.
#
# Target: Ubuntu 24.04 LTS (system Python is 3.12, which the subject requires).
# Safe to re-run: every step checks its own state before doing work.
#
# Usage:
#   ./scripts/setup.sh                 # everything
#   ./scripts/setup.sh --skip-docker   # see --help for the full list
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SIMPLX_DIR="${SIMPLX_DIR:-$REPO_ROOT/vendor/simplx}"
VENV_DIR="${VENV_DIR:-$REPO_ROOT/.venv}"
MIN_FREE_GB=8

SKIP_APT=0
SKIP_DOCKER=0
SKIP_SIMPLX=0
SKIP_PYTHON=0

# ---------------------------------------------------------------- output ----

if [[ -t 1 ]]; then
    C_RESET=$'\033[0m'; C_BLUE=$'\033[34m'; C_GREEN=$'\033[32m'
    C_YELLOW=$'\033[33m'; C_RED=$'\033[31m'; C_BOLD=$'\033[1m'
else
    C_RESET=; C_BLUE=; C_GREEN=; C_YELLOW=; C_RED=; C_BOLD=
fi

info()    { printf '%s==>%s %s\n'   "$C_BLUE"   "$C_RESET" "$*"; }
ok()      { printf '%s  ok%s %s\n'  "$C_GREEN"  "$C_RESET" "$*"; }
warn()    { printf '%swarn%s %s\n'  "$C_YELLOW" "$C_RESET" "$*" >&2; }
err()     { printf '%s fail%s %s\n' "$C_RED"    "$C_RESET" "$*" >&2; }
section() { printf '\n%s%s%s\n' "$C_BOLD" "$*" "$C_RESET"; }

trap 'err "aborted at line $LINENO"' ERR

usage() {
    cat <<'EOF'
CrashLab development environment bootstrap.

Usage: ./scripts/setup.sh [options]

Options:
  --skip-apt      Do not install system packages
  --skip-docker   Do not install Docker Engine
  --skip-simplx   Do not clone/build the Simplx actor framework
  --skip-python   Do not create the Python virtualenv
  -h, --help      Show this message

Environment:
  SIMPLX_DIR      Where to clone Simplx   (default: <repo>/vendor/simplx)
  VENV_DIR        Where to put the venv   (default: <repo>/.venv)
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --skip-apt)    SKIP_APT=1 ;;
        --skip-docker) SKIP_DOCKER=1 ;;
        --skip-simplx) SKIP_SIMPLX=1 ;;
        --skip-python) SKIP_PYTHON=1 ;;
        -h|--help)     usage; exit 0 ;;
        *)             err "unknown option: $1"; usage; exit 2 ;;
    esac
    shift
done

# -------------------------------------------------------------- preflight ----

preflight() {
    section "Preflight"

    if [[ $EUID -eq 0 ]]; then
        err "Do not run this as root. It calls sudo only where needed,"
        err "and files it creates must belong to your user."
        exit 1
    fi

    if [[ -r /etc/os-release ]]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        if [[ "${ID:-}" == "ubuntu" && "${VERSION_ID:-}" == "24.04" ]]; then
            ok "Ubuntu 24.04 LTS"
        else
            warn "Expected Ubuntu 24.04, found ${PRETTY_NAME:-unknown}."
            warn "Package names and the system Python version may differ."
        fi
    fi

    local pyver
    pyver="$(python3 --version 2>/dev/null || echo 'none')"
    if [[ "$pyver" == *" 3.12."* ]]; then
        ok "$pyver"
    else
        warn "System python3 is '$pyver'; the subject specifies 3.12."
        warn "Consider 'uv venv --python 3.12' if this matters to your evaluator."
    fi

    local free_gb
    free_gb="$(df -BG --output=avail "$REPO_ROOT" 2>/dev/null | tail -1 | tr -dc '0-9')"
    free_gb="${free_gb:-0}"      # an empty value would abort the arithmetic below
    if (( free_gb < MIN_FREE_GB )); then
        warn "Only ${free_gb}G free on this filesystem (want >= ${MIN_FREE_GB}G)."
        warn "Docker images and C++ build artifacts are the usual culprits:"
        warn "  docker system prune -af --volumes && sudo fstrim -av"
    else
        ok "${free_gb}G free"
    fi

    if ! command -v sudo >/dev/null; then
        err "sudo not found; cannot install system packages."
        exit 1
    fi

    if (( SKIP_APT == 0 || SKIP_DOCKER == 0 )); then
        info "Caching sudo credentials"
        sudo -v
    fi
}

# ------------------------------------------------------------ apt packages ----

APT_PACKAGES=(
    # C++ toolchain (M2)
    build-essential cmake ninja-build pkg-config ccache
    # Debugging, profiling, coverage (M11). linux-tools-common alone only ships
    # a stub that tells you to install the kernel-specific package, so pull in
    # linux-tools-generic too or `perf` will not actually run.
    gdb valgrind lcov gcovr linux-tools-common linux-tools-generic
    clang-format clang-tidy
    # Python (M3)
    python3.12 python3.12-venv python3.12-dev python3-pip
    # Storage. The Postgres *server* runs in Docker Compose to save disk;
    # these are the client and headers the Python drivers need.
    sqlite3 libsqlite3-dev postgresql-client libpq-dev
    # Everyday
    git curl wget jq make tmux htop unzip
)

install_apt() {
    section "System packages"
    if (( SKIP_APT )); then info "skipped"; return; fi

    local missing=()
    for pkg in "${APT_PACKAGES[@]}"; do
        dpkg -s "$pkg" >/dev/null 2>&1 || missing+=("$pkg")
    done

    if (( ${#missing[@]} == 0 )); then
        ok "all ${#APT_PACKAGES[@]} packages already installed"
        return
    fi

    info "Installing ${#missing[@]} package(s): ${missing[*]}"
    sudo apt-get update -qq
    sudo apt-get install -y "${missing[@]}"

    # Unbounded ccache grows to 5G by default, which we cannot afford.
    if command -v ccache >/dev/null; then
        ccache -M 1G >/dev/null
        ok "ccache capped at 1G"
    fi
}

# ------------------------------------------------------------------ docker ----

install_docker() {
    section "Docker Engine"
    if (( SKIP_DOCKER )); then info "skipped"; return; fi

    if command -v docker >/dev/null; then
        ok "already installed ($(docker --version))"
    else
        info "Adding Docker's official apt repository"
        sudo install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
            | sudo gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg
        sudo chmod a+r /etc/apt/keyrings/docker.gpg

        local codename
        codename="$(. /etc/os-release && echo "$VERSION_CODENAME")"
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $codename stable" \
            | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

        info "Installing Docker Engine + Compose plugin"
        sudo apt-get update -qq
        sudo apt-get install -y \
            docker-ce docker-ce-cli containerd.io \
            docker-buildx-plugin docker-compose-plugin
    fi

    # Container logs are unbounded by default and will silently eat the disk.
    if [[ ! -f /etc/docker/daemon.json ]]; then
        info "Capping container log size"
        sudo install -m 0755 -d /etc/docker
        sudo tee /etc/docker/daemon.json >/dev/null <<'JSON'
{
  "log-driver": "json-file",
  "log-opts": { "max-size": "10m", "max-file": "3" }
}
JSON
        sudo systemctl restart docker || warn "could not restart docker"
    fi

    local me; me="$(id -un)"
    if id -nG "$me" | grep -qw docker; then
        ok "$me is in the docker group"
    else
        sudo usermod -aG docker "$me"
        warn "Added $me to the docker group."
        warn "LOG OUT AND BACK IN before docker works without sudo."
    fi
}

# ------------------------------------------------------------------ simplx ----

install_simplx() {
    section "Simplx (Exchange A actor framework)"
    if (( SKIP_SIMPLX )); then info "skipped"; return; fi

    if [[ -d "$SIMPLX_DIR/.git" ]]; then
        ok "already cloned at $SIMPLX_DIR"
    else
        info "Cloning into $SIMPLX_DIR"
        mkdir -p "$(dirname "$SIMPLX_DIR")"
        git clone --depth 1 https://github.com/Tredzone/simplx.git "$SIMPLX_DIR"
    fi

    info "Building (Release)"
    # Simplx predates GCC 13; a build failure here is not fatal to the rest of
    # the setup, so report it and carry on rather than aborting.
    if cmake -S "$SIMPLX_DIR" -B "$SIMPLX_DIR/build" \
             -G Ninja -DCMAKE_BUILD_TYPE=Release >/dev/null 2>&1 \
       && cmake --build "$SIMPLX_DIR/build" -j "$(nproc)" >/dev/null 2>&1; then
        ok "built into $SIMPLX_DIR/build"
    else
        warn "Simplx build failed."
        warn "Rerun verbosely to see why:"
        warn "  cmake -S $SIMPLX_DIR -B $SIMPLX_DIR/build -DCMAKE_BUILD_TYPE=Release"
        warn "  cmake --build $SIMPLX_DIR/build -j$(nproc)"
        warn "Older codebases often need -DCMAKE_CXX_FLAGS='-include cstdint'"
        warn "with GCC 13, which tightened its transitive includes."
    fi
}

# ------------------------------------------------------------------ python ----

install_python() {
    section "Python environment"
    if (( SKIP_PYTHON )); then info "skipped"; return; fi

    if [[ -x "$VENV_DIR/bin/python" ]]; then
        ok "venv exists at $VENV_DIR"
    else
        # Prefer the interpreter the subject specifies over whatever `python3`
        # happens to point at, so the venv is 3.12 even on a newer Ubuntu.
        local py=python3.12
        command -v "$py" >/dev/null 2>&1 || py=python3
        info "Creating venv at $VENV_DIR (using $py)"
        "$py" -m venv "$VENV_DIR"
    fi

    info "Installing dependencies"
    "$VENV_DIR/bin/python" -m pip install --quiet --upgrade pip setuptools wheel

    if [[ -f "$REPO_ROOT/requirements.txt" ]]; then
        "$VENV_DIR/bin/python" -m pip install --quiet -r "$REPO_ROOT/requirements.txt"
        ok "installed from requirements.txt"
    else
        warn "no requirements.txt found; venv is empty"
    fi
}

# ------------------------------------------------------------------ verify ----

verify() {
    section "Verification"

    check() {
        local label="$1"; shift
        # A pipeline's status is head's, which is 0 even when the command is
        # missing, so probe for the binary explicitly before running it.
        if ! command -v "$1" >/dev/null 2>&1 && [[ ! -x "$1" ]]; then
            warn "$(printf '%-10s not found' "$label")"
            return
        fi
        local out
        out="$("$@" 2>&1 | head -1)" || out='(returned an error)'
        ok "$(printf '%-10s %s' "$label" "$out")"
    }

    check gcc     gcc --version
    check cmake   cmake --version
    check ninja   ninja --version
    check python  python3 --version
    check git     git --version

    if command -v docker >/dev/null; then
        check docker docker --version
        if docker info >/dev/null 2>&1; then
            ok "$(printf '%-10s daemon reachable' 'docker')"
        else
            warn "$(printf '%-10s daemon unreachable — log out and back in' 'docker')"
        fi
    fi

    if [[ -d "$SIMPLX_DIR/build" ]]; then
        local nlibs
        nlibs="$(find "$SIMPLX_DIR/build" -name '*.a' -o -name '*.so' 2>/dev/null | wc -l)"
        if (( nlibs > 0 )); then
            ok "$(printf '%-10s %s librar(y|ies) built' 'simplx' "$nlibs")"
        else
            warn "$(printf '%-10s no libraries produced' 'simplx')"
        fi
    fi

    if [[ -x "$VENV_DIR/bin/python" ]]; then
        check venv "$VENV_DIR/bin/python" --version
    fi
}

# -------------------------------------------------------------------- main ----

main() {
    printf '%sCrashLab setup%s  (%s)\n' "$C_BOLD" "$C_RESET" "$REPO_ROOT"

    preflight
    install_apt
    install_docker
    install_simplx
    install_python
    verify

    section "Next"
    cat <<EOF
  source $VENV_DIR/bin/activate

If Docker was just installed, log out and back in first.
EOF
}

main "$@"
