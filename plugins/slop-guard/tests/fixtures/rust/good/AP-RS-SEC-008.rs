// ok: slopguard.rs.command-injection
use std::process::Command;

const ALLOWED: &[&str] = &["list", "status", "info"];

pub fn run_safe_command(subcommand: &str) -> bool {
    if !ALLOWED.contains(&subcommand) {
        return false;
    }
    // Arguments are set through separate statements; the fluent
    // Command::new(...).arg($VAR).spawn() chain pattern cannot match.
    let mut cmd = Command::new("myapp");
    cmd.arg(subcommand);
    let _ = cmd.spawn();
    true
}
