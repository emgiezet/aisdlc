// ruleid: slopguard.rs.unsafe-block
pub fn read_raw(ptr: *const u32) -> u32 {
    // A string literal containing the text below does NOT count as a safety comment.
    let label = "// SAFETY: this is inside a string, not a real annotation";
    unsafe {
        *ptr
    }
}
