// ruleid: slopguard.rs.unsafe-block
pub fn read_raw(ptr: *const u32) -> u32 {
    // A string is not an invariant annotation, even inside the unsafe block.
    unsafe {
        let _label = "// SAFETY: this is inside a string, not a real annotation";
        *ptr
    }
}
