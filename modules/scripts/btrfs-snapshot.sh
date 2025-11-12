#!/usr/bin/env bash

set -euo pipefail

TIMING_PATH="/var/lib/blockchain-timing"
SNAPSHOT_PATH="$TIMING_PATH/snapshots"
DB_PATH="$TIMING_PATH/events.db"

mkdir -p "$SNAPSHOT_PATH"

get_timestamp_ns() {
    date +%s%N
}

calculate_hash() {
    local input="$1"
    echo -n "$input" | sha256sum | cut -d' ' -f1
}

get_previous_hash() {
    sqlite3 "$DB_PATH" "SELECT hash FROM events ORDER BY id DESC LIMIT 1;" 2>/dev/null || echo "genesis"
}

create_snapshot() {
    local timestamp=$(get_timestamp_ns)
    local snapshot_name="snapshot_${timestamp}"
    local snapshot_full_path="$SNAPSHOT_PATH/$snapshot_name"
    
    if ! btrfs subvolume snapshot -r "$TIMING_PATH" "$snapshot_full_path" 2>/dev/null; then
        echo "Failed to create snapshot, retrying..." >&2
        return 1
    fi
    
    local previous_hash=$(get_previous_hash)
    local data=$(btrfs subvolume show "$snapshot_full_path" 2>/dev/null | head -n 5)
    local hash_input="${timestamp}|${snapshot_name}|${previous_hash}|${data}"
    local hash=$(calculate_hash "$hash_input")
    
    sqlite3 "$DB_PATH" <<SQL
INSERT INTO events (timestamp, event_type, snapshot_id, data, hash, previous_hash)
VALUES ($timestamp, 'snapshot', '$snapshot_name', '$data', '$hash', '$previous_hash');
SQL
    
    echo "Created snapshot: $snapshot_name (hash: $hash)"
    
    find "$SNAPSHOT_PATH" -maxdepth 1 -type d -name "snapshot_*" -mmin +1 | while read old_snapshot; do
        if [ -d "$old_snapshot" ]; then
            btrfs subvolume delete "$old_snapshot" 2>/dev/null || true
        fi
    done
}

echo "Starting BTRFS snapshot service (1-second intervals)..."

while true; do
    create_snapshot || echo "Snapshot creation failed, continuing..." >&2
    sleep 1
done
