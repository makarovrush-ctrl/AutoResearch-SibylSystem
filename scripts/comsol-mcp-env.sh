#!/usr/bin/env bash
# Resolve COMSOL Multiphysics root/bin and export them for MPh.
# Sourced by scripts/run-comsol-mcp.sh and scripts/install-comsol-mcp.sh.
#
# The desktop shortcut COMSOL Multiphysics 6.2.lnk points at a non-default
# Windows folder named Multiphysics_copy1. MPh registry discovery looks for
# the usual Multiphysics folder, so we put this copy's win64 bin on PATH.

: "${COMSOL_WIN_ROOT_DEFAULT:=C:\\Program Files\\COMSOL\\COMSOL62\\Multiphysics_copy1}"

comsol_mcp_unix_path() {
    local raw="$1"
    case "$raw" in
        [A-Za-z]:\\*|/[A-Za-z]/*) ;;
        *)
            printf '%s\n' "$raw"
            return 0
            ;;
    esac
    if command -v cygpath >/dev/null 2>&1; then
        cygpath -u "$raw"
        return 0
    fi
    local drive rest
    drive="$(printf '%s' "$raw" | cut -c1 | tr 'A-Z' 'a-z')"
    rest="$(printf '%s' "$raw" | cut -c3- | tr '\\' '/')"
    if [ -d "/mnt/${drive}${rest}" ]; then
        printf '/mnt/%s%s\n' "$drive" "$rest"
    elif [ -d "/${drive}${rest}" ]; then
        printf '/%s%s\n' "$drive" "$rest"
    else
        printf '%s\n' "$raw"
    fi
}

comsol_mcp_looks_like_root() {
    local root="$1"
    [ -n "$root" ] || return 1
    [ -e "$root/bin/win64/comsol.exe" ] || [ -e "$root/bin/glnxa64/comsol" ] || [ -e "$root/bin/maci64/comsol" ] || [ -e "$root/bin/macarm64/comsol" ]
}

comsol_mcp_parse_lnk() {
    local lnk="$1"
    [ -f "$lnk" ] || return 1
    local line
    line="$(file "$lnk" 2>/dev/null | sed -n 's/.*LocalBasePath "\([^"]*\)".*/\1/p')"
    [ -n "$line" ] || line="$(strings "$lnk" 2>/dev/null | grep -E '\\\\bin\\\\win64\\\\comsol\\.exe$' | head -1)"
    [ -n "$line" ] || return 1
    printf '%s\n' "$line" | sed -E 's/[\\/]+bin[\\/]+win64[\\/]+comsol\.exe$//'
}

comsol_mcp_discover_root() {
    local candidate unix lnk
    for candidate in \
        "${COMSOL_ROOT:-}" \
        "${COMSOLROOT:-}" \
        "$COMSOL_WIN_ROOT_DEFAULT" \
        "C:\\Program Files\\COMSOL\\COMSOL62\\Multiphysics" \
        "/usr/local/comsol62/multiphysics" \
        "/usr/local/comsol/multiphysics" \
        "$HOME/.local/comsol62/multiphysics"
    do
        [ -n "$candidate" ] || continue
        unix="$(comsol_mcp_unix_path "$candidate")"
        if comsol_mcp_looks_like_root "$unix"; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done

    for lnk in \
        "$HOME/Desktop/COMSOL Multiphysics 6.2.lnk" \
        "$HOME/Desktop/COMSOL_Multiphysics_6.2.lnk" \
        "/home/ubuntu/.cursor/projects/workspace/uploads/COMSOL_Multiphysics_6.2_8257.lnk"
    do
        candidate="$(comsol_mcp_parse_lnk "$lnk" 2>/dev/null || true)"
        [ -n "$candidate" ] || continue
        printf '%s\n' "$candidate"
        return 0
    done

    printf '%s\n' "$COMSOL_WIN_ROOT_DEFAULT"
}

comsol_mcp_bin_dir() {
    local root="$1"
    local unix
    unix="$(comsol_mcp_unix_path "$root")"
    if [ -d "$unix/bin/win64" ]; then
        printf '%s\\bin\\win64\n' "$root"
    elif [ -d "$unix/bin/glnxa64" ]; then
        printf '%s/bin/glnxa64\n' "$unix"
    elif [ -d "$unix/bin/macarm64" ]; then
        printf '%s/bin/macarm64\n' "$unix"
    elif [ -d "$unix/bin/maci64" ]; then
        printf '%s/bin/maci64\n' "$unix"
    else
        printf '%s\\bin\\win64\n' "$root"
    fi
}

comsol_mcp_export() {
    COMSOL_ROOT="$(comsol_mcp_discover_root)"
    export COMSOL_ROOT
    export COMSOLROOT="$COMSOL_ROOT"
    local bin
    bin="$(comsol_mcp_bin_dir "$COMSOL_ROOT")"
    case "$PATH" in
        *"${bin}"*) ;;
        *) PATH="${bin}${PATH:+:${PATH}}"; export PATH ;;
    esac
}
