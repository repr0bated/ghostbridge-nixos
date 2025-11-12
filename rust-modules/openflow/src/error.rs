use thiserror::Error;

#[derive(Error, Debug)]
pub enum Error {
    #[error("Bridge not found: {0}")]
    BridgeNotFound(String),

    #[error("Invalid flow rule syntax: {0}")]
    InvalidFlowRule(String),

    #[error("Command execution failed: {0}")]
    CommandFailed(String),

    #[error("ovs-ofctl error: {0}")]
    OvsOfctlError(String),

    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),

    #[error("JSON error: {0}")]
    Json(#[from] serde_json::Error),

    #[error("D-Bus error: {0}")]
    DBus(#[from] zbus::Error),

    #[error("Permission denied")]
    PermissionDenied,
}

pub type Result<T> = std::result::Result<T, Error>;
