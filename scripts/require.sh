#!/usr/bin/env bash
# Preflight helpers shared by claim.sh and scripts/make-env.sh.
#
# A missing tool must never be reported as a bare name: the evaluator is left to
# guess the package, and package names differ per distribution. Every check here
# prints the command for the package manager actually present, plus the upstream
# instructions, which stay authoritative when a distribution renames a package.

pkg_mgr() {
    local m
    for m in apt-get dnf pacman zypper apk; do
        if command -v "$m" >/dev/null 2>&1; then printf '%s\n' "$m"; return 0; fi
    done
    printf 'unknown\n'
}

# install_hint <apt-pkgs> <dnf-pkgs> <pacman-pkgs> <zypper-pkgs>
install_hint() {
    case "$(pkg_mgr)" in
        apt-get) printf 'sudo apt-get update && sudo apt-get install -y %s\n' "$1" ;;
        dnf)     printf 'sudo dnf install -y %s\n' "$2" ;;
        pacman)  printf 'sudo pacman -Sy --needed %s\n' "$3" ;;
        zypper)  printf 'sudo zypper install -y %s\n' "$4" ;;
        *)       printf 'install the equivalent of: %s\n' "$1" ;;
    esac
}

require_git() {
    command -v git >/dev/null 2>&1 && return 0
    {
        echo "need: git"
        echo "  $(install_hint git git git git)"
    } >&2
    exit 1
}

require_docker() {
    command -v docker >/dev/null 2>&1 || {
        {
            echo "need: docker"
            echo "  $(install_hint docker.io docker docker docker)"
            echo "  upstream instructions: https://docs.docker.com/engine/install/"
            echo "  after installing, add yourself to the docker group:"
            echo "    sudo usermod -aG docker \"\$USER\" && newgrp docker"
        } >&2
        exit 1
    }
    docker info >/dev/null 2>&1 || {
        {
            echo "need: a running docker daemon reachable by this user"
            echo "  start it:  sudo systemctl start docker"
            echo "  and allow this user without sudo:"
            echo "    sudo usermod -aG docker \"\$USER\" && newgrp docker"
        } >&2
        exit 1
    }
}

require_compose() {
    docker compose version >/dev/null 2>&1 && return 0
    {
        echo "need: the docker compose plugin (v2 -- the 'docker compose' subcommand,"
        echo "      not the standalone 'docker-compose' binary)"
        echo "  $(install_hint docker-compose-v2 docker-compose docker-compose docker-compose)"
        echo "  package names vary between distributions and releases; the upstream"
        echo "  instructions are authoritative:"
        echo "    https://docs.docker.com/compose/install/linux/"
    } >&2
    exit 1
}
