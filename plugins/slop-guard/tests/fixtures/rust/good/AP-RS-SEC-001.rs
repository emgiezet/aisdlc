// ok: slopguard.rs.unsafe-block
extern "C" {
    fn platform_init(flags: u32) -> i32;
}

pub fn initialize(flags: u32) -> i32 {
    unsafe {
        // SAFETY: platform_init() is documented as thread-safe; flags is a
        // plain bit-field with no pointer or lifetime implications, so no
        // aliasing or validity invariants are at risk here.
        platform_init(flags)
    }
}

pub fn initialize_documented_above(flags: u32) -> i32 {
    // SAFETY: platform_init accepts every flags bit-field and is thread-safe.
    unsafe {
        platform_init(flags)
    }
}
