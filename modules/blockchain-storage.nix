{ config, pkgs, lib, ... }:

{
  environment.systemPackages = with pkgs; [
    btrfs-progs
    btrfs-snap
    sqlite
    jq
  ];

  systemd.tmpfiles.rules = [
    "d /var/lib/blockchain-timing 0755 root root -"
    "d /var/lib/blockchain-vectors 0755 root root -"
    "d /var/lib/blockchain-timing/snapshots 0755 root root -"
    "d /var/lib/blockchain-timing/events 0755 root root -"
    "d /work 0755 root root -"
  ];

  systemd.services."btrfs-snapshot" = {
    description = "BTRFS Snapshot Service (1-second intervals)";
    after = [ "local-fs.target" ];
    wantedBy = [ "multi-user.target" ];
    
    path = with pkgs; [ btrfs-progs coreutils ];
    
    serviceConfig = {
      Type = "simple";
      Restart = "always";
      RestartSec = "1s";
      ExecStart = "${pkgs.bash}/bin/bash ${./scripts/btrfs-snapshot.sh}";
    };
  };

  systemd.services."btrfs-vector-sync" = {
    description = "BTRFS to Qdrant Vector Sync (1-second intervals)";
    after = [ "btrfs-snapshot.service" "qdrant.service" ];
    wants = [ "btrfs-snapshot.service" ];
    wantedBy = [ "multi-user.target" ];
    
    path = with pkgs; [ btrfs-progs curl jq ];
    
    serviceConfig = {
      Type = "simple";
      Restart = "always";
      RestartSec = "1s";
      ExecStart = "${pkgs.bash}/bin/bash ${./scripts/btrfs-vector-sync.sh}";
    };
  };

  systemd.services."qdrant" = {
    description = "Qdrant Vector Database";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    
    serviceConfig = {
      Type = "simple";
      Restart = "always";
      RestartSec = "5s";
      ExecStart = "${pkgs.unstable.qdrant}/bin/qdrant --config-path /etc/qdrant/config.yaml";
      WorkingDirectory = "/var/lib/blockchain-vectors";
      StateDirectory = "qdrant";
      User = "qdrant";
      Group = "qdrant";
    };
  };

  users.users.qdrant = {
    isSystemUser = true;
    group = "qdrant";
    home = "/var/lib/blockchain-vectors";
  };

  users.groups.qdrant = {};

  environment.etc."qdrant/config.yaml" = {
    text = ''
      service:
        host: 0.0.0.0
        http_port: 6333
        grpc_port: 6334
      
      storage:
        storage_path: /var/lib/blockchain-vectors
        snapshots_path: /var/lib/blockchain-vectors/snapshots
        on_disk_payload: true
        
      log_level: INFO
    '';
  };

  systemd.services."blockchain-timing-db" = {
    description = "Blockchain Timing Database Service";
    after = [ "local-fs.target" ];
    wantedBy = [ "multi-user.target" ];
    
    path = with pkgs; [ sqlite ];
    
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };

    script = ''
      DB_PATH="/var/lib/blockchain-timing/events.db"
      
      if [ ! -f "$DB_PATH" ]; then
        echo "Initializing blockchain timing database..."
        sqlite3 "$DB_PATH" <<SQL
          CREATE TABLE IF NOT EXISTS events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp INTEGER NOT NULL,
            event_type TEXT NOT NULL,
            snapshot_id TEXT NOT NULL,
            data TEXT,
            hash TEXT NOT NULL,
            previous_hash TEXT,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
          );
          
          CREATE INDEX idx_timestamp ON events(timestamp);
          CREATE INDEX idx_event_type ON events(event_type);
          CREATE INDEX idx_snapshot_id ON events(snapshot_id);
          CREATE INDEX idx_hash ON events(hash);
          
          PRAGMA journal_mode=WAL;
          PRAGMA synchronous=NORMAL;
SQL
        echo "Database initialized at $DB_PATH"
      fi
    '';
  };

  environment.etc."ghostbridge/query-blockchain.sh" = {
    text = ''
      #!/usr/bin/env bash
      DB_PATH="/var/lib/blockchain-timing/events.db"
      
      echo "=== Recent Blockchain Events ==="
      sqlite3 "$DB_PATH" "SELECT timestamp, event_type, snapshot_id FROM events ORDER BY id DESC LIMIT 10;"
      
      echo ""
      echo "=== Event Statistics ==="
      sqlite3 "$DB_PATH" "SELECT event_type, COUNT(*) as count FROM events GROUP BY event_type;"
    '';
    mode = "0755";
  };
}
