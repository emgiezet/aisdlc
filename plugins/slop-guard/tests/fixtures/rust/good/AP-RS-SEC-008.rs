// ok: slopguard.rs.command-injection
use std::process::Command;

const ALLOWED: &[&str] = &["list", "status", "info"];

pub fn run_safe_command(subcommand: &str) -> bool {
    if !ALLOWED.contains(&subcommand) {
        return false;
    }
    // The executable is fixed and only explicitly allowed subcommands reach it.
    let mut cmd = Command::new("myapp");
    cmd.arg(subcommand);
    let _ = cmd.spawn();
    true
}
