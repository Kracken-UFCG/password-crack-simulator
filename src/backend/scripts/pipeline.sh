#!/bin/bash

classify_password() {
    local pass="$1"
    local score=0
    [[ ${#pass} -ge 6 ]] && ((score++))
    [[ "$pass" =~ [A-Z] ]] && ((score++))
    [[ "$pass" =~ [0-9] ]] && ((score++))
    [[ "$pass" =~ [@#$*%+=-] ]] && ((score++))

    if [[ $score -le 1 ]]; then echo "weak"
    elif [[ $score -eq 2 ]] || [[ $score -eq 3 ]]; then echo "medium"
    else echo "strong"; fi
}

crack_password() {
    local password="$1"
    local level="$2"
    local kdf_value="$3"
    local crack_path="../cpu/password-crack-cpu"

    local cmd=("$crack_path" "$password" "$level")

    if [[ -n "$kdf_value" ]]; then
        cmd+=("--kdf" "$kdf_value")
    fi

    RESULTADO=$("${cmd[@]}" 2>/dev/null)
    echo $RESULTADO
    if [[ -n "$RESULTADO" ]]; then
        echo "$RESULTADO"
    else
        echo "erro"
    fi
}


PASS_INPUT=""
KDF_INT=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --kdf)
            KDF_INT="$2"
            shift 2
            ;;
        *)
            PASS_INPUT="$1"
            shift
            ;;
    esac
done


if [[ -n "$PASS_INPUT" ]]; then
    level=$(classify_password "$PASS_INPUT")
    crack_password "$PASS_INPUT" "$level" "$KDF_INT"
else
    echo "Uso: bash $0 <senha> [--kdf <valor>]" >&2
    exit 1
fi