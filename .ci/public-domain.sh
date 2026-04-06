#!/usr/bin/env bash

set -e

OUTPUT_FILE="$(git rev-parse --show-toplevel)/.ci/public-domains.csv"

sort_output() {
    local tmp
    tmp="$(mktemp)"

    {
        echo "name,domain,statcodes"
        awk 'NR > 1 && NF > 0 { print $0 }' "$OUTPUT_FILE" | sort -t',' -k1,1f
    } > "$tmp"

    mv "$tmp" "$OUTPUT_FILE"
}

process() {
    local enabled="$1"
    local name="$2"
    local domain="$3"
    local statcodes="$4"

    if [[ ! -f "$OUTPUT_FILE" ]]; then
        touch "$OUTPUT_FILE"
        echo "name,domain,statcodes" > "$OUTPUT_FILE"
    fi

    if [[ "$enabled" != "true" ]]; then
        local tmp
        tmp="$(mktemp)"
        awk -F',' -v OFS=',' -v n="$name" '
            NR == 1 { print $0; next }
            tolower($1) == tolower(n) { next }
            { print $0 }
        ' "$OUTPUT_FILE" > "$tmp"
        mv "$tmp" "$OUTPUT_FILE"
        sort_output
        return 0
    fi

    local current_line
    current_line="$(awk -F',' -v n="$name" 'tolower($1) == tolower(n) { print $0; exit }' "$OUTPUT_FILE")"

    [[ "$current_line" == "$name,$domain,$statcodes" ]] && return 0

    if [[ -n "$current_line" ]]; then
        local tmp
        tmp="$(mktemp)"
        awk -F',' -v OFS=',' -v n="$name" -v d="$domain" -v s="$statcodes" '
            BEGIN { replaced = 0 }
            NR == 1 { print $0; next }
            tolower($1) == tolower(n) {
                if (!replaced) {
                    print n, d, s
                    replaced = 1
                }
                next
            }
            { print $0 }
            END {
                if (!replaced) {
                    print n, d, s
                }
            }
        ' "$OUTPUT_FILE" > "$tmp"
        mv "$tmp" "$OUTPUT_FILE"
        sort_output
        return 0
    fi

    echo "$name,$domain,$statcodes" >> "$OUTPUT_FILE"
    sort_output
}

usage() {
    echo """Usage: $(basename "$0") [OPTION]..."""
    echo "Options:"
    echo "  -e, --enabled   Enable or disable the public domain (true/false)"
    echo "  -n, --name      The name of the public domain"
    echo "  -d, --domain    The domain name to be used for the public domain"
    echo "  -s, --statcodes Colon-separated list of HTTP status codes to be considered as valid responses (e.g., 200:301:404)"
    echo "  -h, --help      Display this help message"
}

main() {
    enabled="true"
    name=""
    domain=""
    statcodes=""

    parsed="$(getopt -l "enabled:,name:,domain:,statcodes:,help" -o "e:,n:,d:,s:,h,b" -n "$0" -- "$@")" || {
        usage
        exit 1
    }
    eval set -- "$parsed"

  while true; do
    case $1 in
      -e | --enabled)
        enabled="$2"
        shift
      ;;
      -n | --name)
        name="$2"
        shift
      ;;
      -d | --domain)
        domain="$2"
        shift
      ;;
      -s | --statcodes)
        statcodes="$2"
        shift
      ;;
    --)
        shift
        break
      ;;
    -h | --help)
        usage
        break
      ;;
    esac
    _status="$?"
    [[ "${_status}" != "0" ]] && { exit ${_status}; }
    shift
  done

    if [[ -z "$name" || -z "$domain" ]]; then
        echo "Error: --name and --domain are required."
        usage
        exit 1
    fi

  process "$enabled" "$name" "$domain" "$statcodes"
}

main "$@"
