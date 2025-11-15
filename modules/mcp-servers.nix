{ config, pkgs, lib, ... }:

{
  # Model Context Protocol (MCP) Servers Module
  # Configures multiple free/public MCP servers for Claude integration

  environment.systemPackages = with pkgs; [
    nodejs_20
    python3
    python3Packages.pip
    git
    sqlite
    postgresql
  ];

  # MCP Server: Filesystem
  systemd.services."mcp-filesystem" = {
    description = "MCP Filesystem Server - File operations via MCP";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];

    environment = {
      NODE_ENV = "production";
    };

    serviceConfig = {
      Type = "simple";
      Restart = "always";
      RestartSec = "5s";
      ExecStart = "${pkgs.nodejs_20}/bin/npx -y @modelcontextprotocol/server-filesystem /home /tmp /var";
      WorkingDirectory = "/var/lib/mcp";
      StateDirectory = "mcp";
      User = "mcp";
      Group = "mcp";
    };
  };

  # MCP Server: Git
  systemd.services."mcp-git" = {
    description = "MCP Git Server - Git operations via MCP";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];

    serviceConfig = {
      Type = "simple";
      Restart = "always";
      RestartSec = "5s";
      ExecStart = "${pkgs.nodejs_20}/bin/npx -y @modelcontextprotocol/server-git";
      WorkingDirectory = "/var/lib/mcp";
      StateDirectory = "mcp";
      User = "mcp";
      Group = "mcp";
    };
  };

  # MCP Server: GitHub
  systemd.services."mcp-github" = {
    description = "MCP GitHub Server - GitHub API access via MCP";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];

    environment = {
      GITHUB_PERSONAL_ACCESS_TOKEN = ""; # Set via environment or secrets
    };

    serviceConfig = {
      Type = "simple";
      Restart = "always";
      RestartSec = "5s";
      ExecStart = "${pkgs.nodejs_20}/bin/npx -y @modelcontextprotocol/server-github";
      WorkingDirectory = "/var/lib/mcp";
      StateDirectory = "mcp";
      User = "mcp";
      Group = "mcp";
    };
  };

  # MCP Server: PostgreSQL
  systemd.services."mcp-postgres" = {
    description = "MCP PostgreSQL Server - Database access via MCP";
    wantedBy = [ "multi-user.target" ];
    after = [ "postgresql.service" ];
    requires = [ "postgresql.service" ];

    environment = {
      POSTGRES_CONNECTION_STRING = "postgresql://localhost:5432";
    };

    serviceConfig = {
      Type = "simple";
      Restart = "always";
      RestartSec = "5s";
      ExecStart = "${pkgs.nodejs_20}/bin/npx -y @modelcontextprotocol/server-postgres";
      WorkingDirectory = "/var/lib/mcp";
      StateDirectory = "mcp";
      User = "mcp";
      Group = "mcp";
    };
  };

  # MCP Server: SQLite
  systemd.services."mcp-sqlite" = {
    description = "MCP SQLite Server - SQLite database access via MCP";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];

    serviceConfig = {
      Type = "simple";
      Restart = "always";
      RestartSec = "5s";
      ExecStart = "${pkgs.nodejs_20}/bin/npx -y @modelcontextprotocol/server-sqlite --db-path /var/lib/mcp/mcp.db";
      WorkingDirectory = "/var/lib/mcp";
      StateDirectory = "mcp";
      User = "mcp";
      Group = "mcp";
    };
  };

  # MCP Server: Brave Search
  systemd.services."mcp-brave-search" = {
    description = "MCP Brave Search Server - Web search via MCP";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];

    environment = {
      BRAVE_API_KEY = ""; # Set via environment or secrets
    };

    serviceConfig = {
      Type = "simple";
      Restart = "always";
      RestartSec = "5s";
      ExecStart = "${pkgs.nodejs_20}/bin/npx -y @modelcontextprotocol/server-brave-search";
      WorkingDirectory = "/var/lib/mcp";
      StateDirectory = "mcp";
      User = "mcp";
      Group = "mcp";
    };
  };

  # MCP Server: Google Drive
  systemd.services."mcp-gdrive" = {
    description = "MCP Google Drive Server - Google Drive access via MCP";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];

    environment = {
      GDRIVE_CLIENT_ID = ""; # Set via environment or secrets
      GDRIVE_CLIENT_SECRET = ""; # Set via environment or secrets
    };

    serviceConfig = {
      Type = "simple";
      Restart = "always";
      RestartSec = "5s";
      ExecStart = "${pkgs.nodejs_20}/bin/npx -y @modelcontextprotocol/server-gdrive";
      WorkingDirectory = "/var/lib/mcp";
      StateDirectory = "mcp";
      User = "mcp";
      Group = "mcp";
    };
  };

  # MCP Server: Google Maps
  systemd.services."mcp-google-maps" = {
    description = "MCP Google Maps Server - Maps and location services via MCP";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];

    environment = {
      GOOGLE_MAPS_API_KEY = ""; # Set via environment or secrets
    };

    serviceConfig = {
      Type = "simple";
      Restart = "always";
      RestartSec = "5s";
      ExecStart = "${pkgs.nodejs_20}/bin/npx -y @modelcontextprotocol/server-google-maps";
      WorkingDirectory = "/var/lib/mcp";
      StateDirectory = "mcp";
      User = "mcp";
      Group = "mcp";
    };
  };

  # MCP Server: Slack
  systemd.services."mcp-slack" = {
    description = "MCP Slack Server - Slack integration via MCP";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];

    environment = {
      SLACK_BOT_TOKEN = ""; # Set via environment or secrets
      SLACK_TEAM_ID = ""; # Set via environment or secrets
    };

    serviceConfig = {
      Type = "simple";
      Restart = "always";
      RestartSec = "5s";
      ExecStart = "${pkgs.nodejs_20}/bin/npx -y @modelcontextprotocol/server-slack";
      WorkingDirectory = "/var/lib/mcp";
      StateDirectory = "mcp";
      User = "mcp";
      Group = "mcp";
    };
  };

  # MCP Server: Memory (Simple key-value store)
  systemd.services."mcp-memory" = {
    description = "MCP Memory Server - Simple key-value storage via MCP";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];

    serviceConfig = {
      Type = "simple";
      Restart = "always";
      RestartSec = "5s";
      ExecStart = "${pkgs.nodejs_20}/bin/npx -y @modelcontextprotocol/server-memory";
      WorkingDirectory = "/var/lib/mcp";
      StateDirectory = "mcp";
      User = "mcp";
      Group = "mcp";
    };
  };

  # MCP Server: Fetch (HTTP/HTTPS requests)
  systemd.services."mcp-fetch" = {
    description = "MCP Fetch Server - HTTP requests via MCP";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];

    serviceConfig = {
      Type = "simple";
      Restart = "always";
      RestartSec = "5s";
      ExecStart = "${pkgs.nodejs_20}/bin/npx -y @modelcontextprotocol/server-fetch";
      WorkingDirectory = "/var/lib/mcp";
      StateDirectory = "mcp";
      User = "mcp";
      Group = "mcp";
    };
  };

  # MCP Server: Puppeteer (Browser automation)
  systemd.services."mcp-puppeteer" = {
    description = "MCP Puppeteer Server - Browser automation via MCP";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];

    serviceConfig = {
      Type = "simple";
      Restart = "always";
      RestartSec = "5s";
      ExecStart = "${pkgs.nodejs_20}/bin/npx -y @modelcontextprotocol/server-puppeteer";
      WorkingDirectory = "/var/lib/mcp";
      StateDirectory = "mcp";
      User = "mcp";
      Group = "mcp";
    };
  };

  # MCP Server: Sequential Thinking
  systemd.services."mcp-sequential-thinking" = {
    description = "MCP Sequential Thinking Server - Extended reasoning via MCP";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];

    serviceConfig = {
      Type = "simple";
      Restart = "always";
      RestartSec = "5s";
      ExecStart = "${pkgs.nodejs_20}/bin/npx -y @modelcontextprotocol/server-sequential-thinking";
      WorkingDirectory = "/var/lib/mcp";
      StateDirectory = "mcp";
      User = "mcp";
      Group = "mcp";
    };
  };

  # MCP Server: Everything (Multi-protocol aggregator)
  systemd.services."mcp-everything" = {
    description = "MCP Everything Server - Multi-source aggregation via MCP";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];

    serviceConfig = {
      Type = "simple";
      Restart = "always";
      RestartSec = "5s";
      ExecStart = "${pkgs.nodejs_20}/bin/npx -y @modelcontextprotocol/server-everything";
      WorkingDirectory = "/var/lib/mcp";
      StateDirectory = "mcp";
      User = "mcp";
      Group = "mcp";
    };
  };

  # Create MCP user and group
  users.users.mcp = {
    isSystemUser = true;
    group = "mcp";
    home = "/var/lib/mcp";
    createHome = true;
  };

  users.groups.mcp = {};

  # Create configuration file for MCP clients
  environment.etc."mcp/config.json" = {
    text = builtins.toJSON {
      mcpServers = {
        filesystem = {
          command = "npx";
          args = [ "-y" "@modelcontextprotocol/server-filesystem" "/home" "/tmp" "/var" ];
        };
        git = {
          command = "npx";
          args = [ "-y" "@modelcontextprotocol/server-git" ];
        };
        github = {
          command = "npx";
          args = [ "-y" "@modelcontextprotocol/server-github" ];
          env = {
            GITHUB_PERSONAL_ACCESS_TOKEN = "YOUR_TOKEN_HERE";
          };
        };
        postgres = {
          command = "npx";
          args = [ "-y" "@modelcontextprotocol/server-postgres" ];
          env = {
            POSTGRES_CONNECTION_STRING = "postgresql://localhost:5432";
          };
        };
        sqlite = {
          command = "npx";
          args = [ "-y" "@modelcontextprotocol/server-sqlite" "--db-path" "/var/lib/mcp/mcp.db" ];
        };
        brave-search = {
          command = "npx";
          args = [ "-y" "@modelcontextprotocol/server-brave-search" ];
          env = {
            BRAVE_API_KEY = "YOUR_API_KEY_HERE";
          };
        };
        gdrive = {
          command = "npx";
          args = [ "-y" "@modelcontextprotocol/server-gdrive" ];
        };
        google-maps = {
          command = "npx";
          args = [ "-y" "@modelcontextprotocol/server-google-maps" ];
        };
        slack = {
          command = "npx";
          args = [ "-y" "@modelcontextprotocol/server-slack" ];
        };
        memory = {
          command = "npx";
          args = [ "-y" "@modelcontextprotocol/server-memory" ];
        };
        fetch = {
          command = "npx";
          args = [ "-y" "@modelcontextprotocol/server-fetch" ];
        };
        puppeteer = {
          command = "npx";
          args = [ "-y" "@modelcontextprotocol/server-puppeteer" ];
        };
        "sequential-thinking" = {
          command = "npx";
          args = [ "-y" "@modelcontextprotocol/server-sequential-thinking" ];
        };
        everything = {
          command = "npx";
          args = [ "-y" "@modelcontextprotocol/server-everything" ];
        };
      };
    };
  };

  # Open firewall for MCP services if needed
  networking.firewall.allowedTCPPorts = [
    # Add ports if MCP servers expose HTTP endpoints
  ];
}
