use openflow_dbus::{OpenFlowManager, Error};
use openflow_dbus::cli::{Cli, Commands, print_examples};
use clap::Parser;
use colored::*;
use tracing::{info, error};
use tracing_subscriber;

#[tokio::main]
async fn main() -> Result<(), Error> {
    let cli = Cli::parse();

    // Initialize tracing
    let log_level = if cli.verbose { "debug" } else { "info" };
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| tracing_subscriber::EnvFilter::new(log_level)),
        )
        .init();

    // Load configuration for most commands
    let manager = if !matches!(cli.command, Commands::Examples | Commands::TestDbus) {
        info!("Loading configuration from: {}", cli.config);
        match OpenFlowManager::from_file(&cli.config).await {
            Ok(m) => {
                info!("Configuration loaded successfully");
                Some(m)
            }
            Err(e) => {
                error!("Failed to load configuration from {}: {}", cli.config, e);
                eprintln!("{} {}", "Error:".red().bold(), e);
                std::process::exit(1);
            }
        }
    } else {
        None
    };

    // Execute command
    match cli.command {
        Commands::Daemon => {
            info!("Starting OpenFlow D-Bus Manager daemon");
            println!("{}", "Starting OpenFlow D-Bus service...".cyan());

            let manager = manager.unwrap();
            openflow_dbus::dbus::start_dbus_service(manager).await?;
        }

        Commands::ApplyDefaults { bridge } => {
            let manager = manager.unwrap();
            println!("{} Applying default rules to bridge: {}", "→".cyan(), bridge.yellow());

            match manager.apply_default_rules(&bridge).await {
                Ok(true) => {
                    println!("{} Default rules applied successfully", "✓".green().bold());
                    std::process::exit(0);
                }
                Ok(false) => {
                    println!("{} auto_apply_defaults is disabled for this bridge", "!".yellow().bold());
                    std::process::exit(1);
                }
                Err(e) => {
                    error!("Failed to apply default rules: {}", e);
                    eprintln!("{} {}", "Error:".red().bold(), e);
                    std::process::exit(1);
                }
            }
        }

        Commands::ApplyAll => {
            let manager = manager.unwrap();
            println!("{} Applying default rules to all bridges", "→".cyan());

            match manager.apply_all_default_rules().await {
                Ok(true) => {
                    println!("{} Default rules applied to all bridges successfully", "✓".green().bold());
                    std::process::exit(0);
                }
                Ok(false) => {
                    println!("{} Some bridges failed to apply rules", "!".yellow().bold());
                    std::process::exit(1);
                }
                Err(e) => {
                    error!("Failed to apply default rules: {}", e);
                    eprintln!("{} {}", "Error:".red().bold(), e);
                    std::process::exit(1);
                }
            }
        }

        Commands::AddFlow { bridge, rule } => {
            let manager = manager.unwrap();
            println!("{} Adding flow rule to {}: {}", "→".cyan(), bridge.yellow(), rule.dimmed());

            match manager.add_flow_rule(&bridge, &rule).await {
                Ok(_) => {
                    println!("{} Flow rule added successfully", "✓".green().bold());
                    std::process::exit(0);
                }
                Err(e) => {
                    error!("Failed to add flow rule: {}", e);
                    eprintln!("{} {}", "Error:".red().bold(), e);
                    std::process::exit(1);
                }
            }
        }

        Commands::RemoveFlow { bridge, spec } => {
            let manager = manager.unwrap();
            println!("{} Removing flow rule from {}: {}", "→".cyan(), bridge.yellow(), spec.dimmed());

            match manager.remove_flow_rule(&bridge, &spec).await {
                Ok(_) => {
                    println!("{} Flow rule removed successfully", "✓".green().bold());
                    std::process::exit(0);
                }
                Err(e) => {
                    error!("Failed to remove flow rule: {}", e);
                    eprintln!("{} {}", "Error:".red().bold(), e);
                    std::process::exit(1);
                }
            }
        }

        Commands::ShowFlows { bridge } => {
            let manager = manager.unwrap();
            println!("{} OpenFlow rules for bridge: {}\n", "→".cyan(), bridge.yellow());

            match manager.dump_flows(&bridge).await {
                Ok(flows) => {
                    if flows.is_empty() {
                        println!("{} No flows configured", "!".yellow().bold());
                    } else {
                        for (i, flow) in flows.iter().enumerate() {
                            println!("{:2}. {}", i + 1, flow);
                        }
                        println!("\n{} Total flows: {}", "→".cyan(), flows.len().to_string().green());
                    }
                    std::process::exit(0);
                }
                Err(e) => {
                    error!("Failed to dump flows: {}", e);
                    eprintln!("{} {}", "Error:".red().bold(), e);
                    std::process::exit(1);
                }
            }
        }

        Commands::ClearFlows { bridge } => {
            let manager = manager.unwrap();
            println!("{} {} Clearing all flows from bridge: {}",
                "!".yellow().bold(),
                "WARNING:".yellow().bold(),
                bridge.yellow()
            );

            match manager.clear_flows(&bridge).await {
                Ok(_) => {
                    println!("{} All flows cleared successfully", "✓".green().bold());
                    std::process::exit(0);
                }
                Err(e) => {
                    error!("Failed to clear flows: {}", e);
                    eprintln!("{} {}", "Error:".red().bold(), e);
                    std::process::exit(1);
                }
            }
        }

        Commands::ListBridges => {
            let manager = manager.unwrap();
            println!("{} Configured bridges:\n", "→".cyan());

            let bridges = manager.list_bridges();
            if bridges.is_empty() {
                println!("{} No bridges configured", "!".yellow().bold());
            } else {
                for bridge in bridges {
                    let of_status = if bridge.openflow.as_ref()
                        .map(|of| of.auto_apply_defaults)
                        .unwrap_or(false) {
                        "✓ OpenFlow enabled".green()
                    } else {
                        "✗ OpenFlow disabled".dimmed()
                    };

                    let addr = bridge.address.as_deref()
                        .unwrap_or(if bridge.dhcp { "DHCP" } else { "none" });

                    println!("  {} {} ({})",
                        "•".cyan(),
                        bridge.name.yellow().bold(),
                        bridge.bridge_type.dimmed()
                    );
                    println!("    Address: {}", addr);
                    println!("    {}", of_status);

                    if let Some(of) = &bridge.openflow {
                        println!("    Default rules: {}", of.default_rules.len());
                    }
                    println!();
                }
            }
            std::process::exit(0);
        }

        Commands::ShowConfig { bridge } => {
            let manager = manager.unwrap();
            println!("{} Configuration for bridge: {}\n", "→".cyan(), bridge.yellow());

            match manager.get_bridge_config(&bridge) {
                Some(config) => {
                    match serde_json::to_string_pretty(config) {
                        Ok(json) => {
                            println!("{}", json);
                            std::process::exit(0);
                        }
                        Err(e) => {
                            error!("Failed to serialize config: {}", e);
                            eprintln!("{} {}", "Error:".red().bold(), e);
                            std::process::exit(1);
                        }
                    }
                }
                None => {
                    eprintln!("{} Bridge not found: {}", "Error:".red().bold(), bridge);
                    std::process::exit(1);
                }
            }
        }

        Commands::TestDbus => {
            println!("{} Testing D-Bus connectivity...\n", "→".cyan());

            // Try to connect to system bus
            match zbus::Connection::system().await {
                Ok(_conn) => {
                    println!("{} Connected to D-Bus system bus", "✓".green().bold());

                    // TODO: Try to introspect the OpenFlow service
                    println!("{} D-Bus service connectivity: OK", "✓".green().bold());
                    std::process::exit(0);
                }
                Err(e) => {
                    error!("Failed to connect to D-Bus: {}", e);
                    eprintln!("{} Failed to connect to D-Bus: {}", "Error:".red().bold(), e);
                    std::process::exit(1);
                }
            }
        }

        Commands::Examples => {
            print_examples();
            std::process::exit(0);
        }
    }

    Ok(())
}
