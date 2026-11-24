// ok: slopguard.rs.raw-pointer-deref
pub fn read_ref(val: &u32) -> u32 {
    *val
}
