// ruleid: slopguard.rs.raw-pointer-deref
pub fn read_raw(ptr: *const u32) -> u32 {
    unsafe {
        *ptr
    }
}
