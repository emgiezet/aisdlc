// ruleid: slopguard.rs.unsafe-block
pub fn overwrite_value(ptr: *mut u32, val: u32) {
    unsafe {
        // missing invariant documentation for this unsafe operation
        *ptr = val;
    }
}
