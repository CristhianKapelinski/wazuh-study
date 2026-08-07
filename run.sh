#!/usr/bin/env bash
# Bring up the study's Wazuh stack with the 1,000-event dataset ingested.
# Everything runs from bind mounts so state survives container recreation.
# Usage: ./run.sh           (start / re-apply)
#        ./run.sh --fresh   (wipe state and reprocess from scratch, reproducible)
set -euo pipefail
cd "$(dirname "$0")"
[ -f .env ] || { echo "missing .env — copy .env.example to .env and fill the placeholders"; exit 1; }
. ./.env

VER="$WAZUH_VERSION"
STACK="_upstream/wazuh-docker/single-node"
DD="$DATA_DIR"
MGR_IMG="wazuh/wazuh-manager:$VER"
DSH_IMG="wazuh/wazuh-dashboard:$VER"
FRESH="${1:-}"

c_ok(){ printf '\033[32m✓\033[0m %s\n' "$*"; }
c_log(){ printf '\033[34m[*]\033[0m %s\n' "$*"; }

command -v docker >/dev/null || { echo "docker not found"; exit 1; }
docker compose version >/dev/null 2>&1 || { echo "docker compose (plugin) not found"; exit 1; }

# The indexer needs vm.max_map_count >= 262144. Most desktop kernels already satisfy
# it, so this only acts when it does not. It never prompts: a password prompt in the
# middle of a reviewer's run is a dead end when the run is unattended or the account
# has no sudo. Tried without a password, and if that fails the exact command is printed
# and the run stops, so the reviewer fixes one thing and re-runs.
if [ "$(cat /proc/sys/vm/max_map_count 2>/dev/null || echo 0)" -lt 262144 ]; then
  if sudo -n sysctl -w vm.max_map_count=262144 >/dev/null 2>&1; then
    c_ok "raised vm.max_map_count"
  else
    echo "vm.max_map_count is below the 262144 the Wazuh indexer needs, and raising it" >&2
    echo "requires root. Run this once, then re-run this script:" >&2
    echo >&2
    echo "    sudo sysctl -w vm.max_map_count=262144" >&2
    echo >&2
    exit 1
  fi
fi

# 1. official Wazuh stack (fetched once, pinned version)
if [ ! -d "$STACK" ]; then
  c_log "cloning wazuh-docker v$VER (one time)"
  mkdir -p _upstream
  git clone --depth=1 -b "v$VER" https://github.com/wazuh/wazuh-docker.git _upstream/wazuh-docker
fi

c_log "preparing stack"
# The Wazuh certificate generator writes into stack/config as root, so a plain rm leaves
# the directory behind and the clone becomes undeletable. Fixed path, spelled out, no
# variable: the container can only ever remove this one directory.
rm -rf stack 2>/dev/null || true
if [ -e stack ]; then
  docker run --rm -v "$PWD:/p" alpine rm -rf /p/stack
fi
mkdir -p stack
cp -r "$STACK/." stack/
cp manager/compose.override.yml stack/docker-compose.override.yml
cp .env stack/.env

# fixed lab credentials in internal_users.yml
F=stack/config/wazuh_indexer/internal_users.yml
awk -v ah="$ADMIN_HASH" -v kh="$KIBANASERVER_HASH" '
  /^[a-zA-Z]/ && !/^[ ]/ {st=""}
  /^admin:/ {st="a"; print; next}
  /^kibanaserver:/ {st="k"; print; next}
  st=="a" && /^  hash:/ {print "  hash: \"" ah "\""; next}
  st=="k" && /^  hash:/ {print "  hash: \"" kh "\""; next}
  {print}' "$F" > "$F.tmp" && mv "$F.tmp" "$F"

# 2. internal certificates (generated once)
if [ ! -d stack/config/wazuh_indexer_ssl_certs ] || [ -z "$(ls -A stack/config/wazuh_indexer_ssl_certs 2>/dev/null)" ]; then
  c_log "generating internal certificates"
  ( cd stack && docker compose -f generate-indexer-certs.yml run --rm generator )
fi

# 3. DATA_DIR owned by the invoking user. The files inside belong to UID 999/1000, so
#    removing them needs root; that root is taken from a throwaway container rather than
#    from the host, exactly as the bind-mount preparation below already does. Docker is
#    a stated dependency of this claim, sudo is not, and asking for a password halfway
#    through stops an unattended run dead.
if [ ! -d "$DD" ] || [ ! -w "$DD" ]; then
  mkdir -p "$DD" 2>/dev/null || true
  docker run --rm -v "$DD:/d" alpine sh -c "chown $(id -u):$(id -g) /d" 2>/dev/null || true
fi
if [ "$FRESH" = "--fresh" ]; then
  c_log "--fresh: wiping containers and data"
  ( cd stack && docker compose down -v 2>/dev/null || true )
  docker run --rm -v "$DD:/d" alpine sh -c 'rm -rf /d/..?* /d/.[!.]* /d/*' 2>/dev/null || true
fi

# 4. bind mounts: all directory handling via a root container (avoids host
#    permission issues, since files inside belong to UID 999/1000)
c_log "preparing bind mounts in $DD"
docker run --rm -v "$DD:/d" alpine sh -c '
  mkdir -p /d/manager/api-config /d/manager/etc /d/manager/queue \
           /d/manager/var-multigroups /d/manager/integrations \
           /d/manager/active-response /d/manager/agentless /d/manager/wodles \
           /d/manager/filebeat-etc /d/manager/filebeat-var /d/manager/logs \
           /d/indexer/data /d/dashboard/config /d/dashboard/custom'

seed() { # image path_in_image subpath_in_DD
  local img="$1" src="$2" sub="$3"
  [ -n "$(docker run --rm -v "$DD/$sub:/c" alpine sh -c 'ls -A /c 2>/dev/null')" ] && return
  docker run --rm --entrypoint sh -v "$DD/$sub:/seed" "$img" -c "cp -a $src/. /seed/ 2>/dev/null || true"
}
seed "$MGR_IMG" /var/ossec/api/configuration       manager/api-config
seed "$MGR_IMG" /var/ossec/etc                      manager/etc
seed "$MGR_IMG" /var/ossec/queue                    manager/queue
seed "$MGR_IMG" /var/ossec/integrations             manager/integrations
seed "$MGR_IMG" /var/ossec/active-response/bin      manager/active-response
seed "$MGR_IMG" /var/ossec/agentless                manager/agentless
seed "$MGR_IMG" /var/ossec/wodles                   manager/wodles
seed "$MGR_IMG" /etc/filebeat                       manager/filebeat-etc
seed "$MGR_IMG" /var/lib/filebeat                   manager/filebeat-var
seed "$MGR_IMG" /var/ossec/logs                     manager/logs
seed "$DSH_IMG" /usr/share/wazuh-dashboard/data/wazuh/config dashboard/config
# feed subdir + empty feed + correct owners (manager=999, indexer/dashboard=1000)
docker run --rm -v "$DD:/d" alpine sh -c '
  mkdir -p /d/manager/logs/study
  : > /d/manager/logs/study/feed.log
  chown -R 999:999 /d/manager
  chown -R 1000:1000 /d/indexer /d/dashboard'

# 5. start
c_log "starting stack (manager + indexer + dashboard)"
( cd stack && docker compose up -d )

# 6. wait until the log collector follows the (empty) feed.log
c_log "waiting for the manager to initialize"
CT=$(cd stack && docker compose ps -q wazuh.manager)
for i in $(seq 1 72); do
  docker exec "$CT" sh -c 'grep -q "study/feed.log" /var/ossec/logs/ossec.log' 2>/dev/null && break
  sleep 5
done
sleep 5

# 7. active ingestion: append the 1,000 events to the feed
c_log "injecting the 1,000 events into the feed (deterministic ingestion)"
docker exec "$CT" sh -c 'cat /var/ossec/logs/study/sample-1000.log >> /var/ossec/logs/study/feed.log'

# 8. wait for processing and count alerts
c_log "waiting for processing"
count_ssh() { docker exec "$CT" sh -c 'grep -hoE "\"id\":\"5[0-9]{3}\"" /var/ossec/logs/alerts/alerts.json 2>/dev/null | wc -l' | tr -dc 0-9; }
count_arch() { docker exec "$CT" sh -c 'wc -l < /var/ossec/logs/archives/archives.json 2>/dev/null || echo 0' | tr -dc 0-9; }
# Returning as soon as ONE alert exists left the rest of the feed in flight. The replay
# that follows clears these logs and re-injects the same events, so events still being
# processed here land in the replay's freshly emptied archive and are counted against
# the wrong run. Wait for the whole feed, and for the count to stop moving.
EXPECTED=$(docker exec "$CT" sh -c 'wc -l < /var/ossec/logs/study/sample-1000.log' | tr -dc 0-9)
EXPECTED=${EXPECTED:-1000}
N=0; prev=-1; stable=0
for i in $(seq 1 60); do
  N=$(count_arch); N=${N:-0}
  if [ "$N" -ge "$EXPECTED" ]; then
    if [ "$N" = "$prev" ]; then
      stable=$((stable + 1))
      [ "$stable" -ge 2 ] && break
    else
      stable=0
    fi
  fi
  prev="$N"
  sleep 3
done
[ "$N" -lt "$EXPECTED" ] && \
  echo "  note: $N of $EXPECTED events archived before the timeout; the stack is up but still draining."
SSH_ALERTS=$(count_ssh)

echo
c_ok "study Wazuh stack is up"
echo "  ┌──────────────────────────────────────────────"
echo "  │ Dashboard:   https://localhost:${DASHBOARD_PORT}"
echo "  │ Login:       admin / ${ADMIN_PASSWORD}"
echo "  │ Dataset:     1,000 events (auth.log, srv01+srv02)"
echo "  │ SSH alerts:  ${SSH_ALERTS}"
echo "  │ Rules:       edit via Server management → Rules (persists in ./rules/)"
echo "  └──────────────────────────────────────────────"
