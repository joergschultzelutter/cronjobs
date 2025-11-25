#!/usr/bin/env bash
# Datei: getpw_lib.sh

require_secure_pwfile() {
  # verweigern, wenn Datei nicht existiert oder nicht regulär
  [ -f "$1" ] || { logger "Password file is missing or is not a regular file: $1" >&2; return 2; }

  # Perms ermitteln: GNU stat zuerst, BSD/macOS Fallback
  local perm
  perm=$(stat -c '%a' "$1" 2>/dev/null || stat -f '%OLp' "$1" 2>/dev/null) || { logger "Unable to determine file access right: $1" >&2; return 2; }

  # Gruppen-/Andere-Bits extrahieren und auf 'read' prüfen
  # perm ist z. B. 640 oder 600; wir lesen die letzten beiden Oktal-Ziffern
  local g o
  g="${perm: -2:1}"
  o="${perm: -1}"

  # Wenn Gruppe oder Andere Leserechte haben (Bit 4 gesetzt) -> unsicher
  if (( (10#$g & 4) != 0 || (10#$o & 4) != 0 )); then
    echo "File $1 has insecure access rights (found: $perm)." >&2
    return 2
  fi
}

get_password() {
  local schluessel="$1"
  local pwfile="$2"
  local passwort

  require_secure_pwfile "$pwfile" || return 2

  passwort=$(
    /usr/bin/awk -v search="$schluessel" '
    function trim(s){ sub(/^[[:space:]]+/, "", s); sub(/[[:space:]]+$/, "", s); return s }
    BEGIN { matched=0 }
    index($0, "=") > 0 {
      k = substr($0, 1, index($0,"=")-1)
      v = substr($0, index($0,"=")+1)
      k = trim(k)
      v = trim(v)
      if (k == search) {
        print v
        matched=1
        exit 0
      }
    }
    END {
      if (!matched) exit 1
    }
    ' "$pwfile"
  ) || return 1

  printf '%s\n' "$passwort"
}

