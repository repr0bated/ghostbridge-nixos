#!/usr/bin/env bash

set -euo pipefail

TIMING_PATH="/var/lib/blockchain-timing"
SNAPSHOT_PATH="$TIMING_PATH/snapshots"
DB_PATH="$TIMING_PATH/events.db"
QDRANT_URL="http://localhost:6333"
COLLECTION_NAME="blockchain_events"

ensure_collection() {
    local status=$(curl -s -o /dev/null -w "%{http_code}" "$QDRANT_URL/collections/$COLLECTION_NAME")
    
    if [ "$status" != "200" ]; then
        echo "Creating Qdrant collection: $COLLECTION_NAME"
        curl -X PUT "$QDRANT_URL/collections/$COLLECTION_NAME" \
            -H 'Content-Type: application/json' \
            -d '{
                "vectors": {
                    "size": 384,
                    "distance": "Cosine"
                }
            }' 2>/dev/null || true
    fi
}

get_last_synced_id() {
    curl -s "$QDRANT_URL/collections/$COLLECTION_NAME/points/scroll" \
        -H 'Content-Type: application/json' \
        -d '{"limit": 1, "with_payload": true, "with_vector": false}' | \
        jq -r '.result.points[0].payload.event_id // 0' 2>/dev/null || echo "0"
}

sync_event_to_qdrant() {
    local event_id="$1"
    local timestamp="$2"
    local event_type="$3"
    local snapshot_id="$4"
    local hash="$5"
    local previous_hash="$6"
    
    local text="${event_type} at ${timestamp}: ${snapshot_id} (hash: ${hash}, prev: ${previous_hash})"
    
    local vector=$(echo -n "$text" | md5sum | awk '{print $1}' | \
        fold -w2 | head -n 384 | \
        awk '{printf "%d,", ("0x"$1) % 256}' | sed 's/,$//')
    
    local vector_array="[${vector}]"
    
    curl -X PUT "$QDRANT_URL/collections/$COLLECTION_NAME/points" \
        -H 'Content-Type: application/json' \
        -d "{
            \"points\": [
                {
                    \"id\": $event_id,
                    \"vector\": $vector_array,
                    \"payload\": {
                        \"event_id\": $event_id,
                        \"timestamp\": $timestamp,
                        \"event_type\": \"$event_type\",
                        \"snapshot_id\": \"$snapshot_id\",
                        \"hash\": \"$hash\",
                        \"previous_hash\": \"$previous_hash\"
                    }
                }
            ]
        }" 2>/dev/null || true
}

echo "Starting BTRFS to Qdrant vector sync service..."

ensure_collection

while true; do
    last_synced=$(get_last_synced_id)
    
    sqlite3 "$DB_PATH" -separator $'\t' \
        "SELECT id, timestamp, event_type, snapshot_id, hash, previous_hash 
         FROM events 
         WHERE id > $last_synced 
         ORDER BY id ASC 
         LIMIT 100;" 2>/dev/null | \
    while IFS=$'\t' read -r id timestamp event_type snapshot_id hash previous_hash; do
        sync_event_to_qdrant "$id" "$timestamp" "$event_type" "$snapshot_id" "$hash" "$previous_hash"
        echo "Synced event $id to Qdrant"
    done
    
    sleep 1
done
