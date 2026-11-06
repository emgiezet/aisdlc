// ruleid: slopguard.rs.command-injection
use std::process::Command;

pub fn run_user_command(program: &str, user_arg: &str) {
    let _ = Command::new(program).arg(user_arg).spawn();
}
