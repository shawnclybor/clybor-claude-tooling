#!/bin/bash
# Added 2026-11-19 (KB 41d25bc3-529a-8109): used by the chrome-profiles skill. Tested clean (exit 0) and red (exit 1 fake id, exit 2 no ids).
# Map Claude-in-Chrome deviceIds to Chrome profiles. Usage: chrome-profile-map.sh <deviceId>...
# Exit 0 = every id mapped, 1 = an id matched no profile, 2 = could not read Chrome.
C="$HOME/Library/Application Support/Google/Chrome"; X=fcoeoabgfenejglbffodgkkbkcdhcgfn
[ -r "$C/Local State" ] || { echo "CANNOT-CHECK: no Local State"; exit 2; }
python3 -c "import json,sys;c=json.load(open(sys.argv[1]))['profile']['info_cache'];[print('PROFILE',d,'|',i.get('name'),'|',i.get('user_name')) for d,i in c.items()]" "$C/Local State" || exit 2
rc=0; n=0
for id in "$@"; do n=$((n+1)); hit=""
  for p in "$C"/Default "$C"/Profile\ *; do
    grep -rqs --binary-files=text "$id" "$p/Local Extension Settings/$X" && hit="$hit $(basename "$p")"
  done
  [ -n "$hit" ] && echo "MAP $id ->$hit" || { echo "UNMAPPED $id"; rc=1; }
done
echo "checked $n deviceId(s)"; [ "$n" -gt 0 ] || exit 2; exit $rc
