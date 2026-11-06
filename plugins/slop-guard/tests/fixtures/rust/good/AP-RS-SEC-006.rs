// ok: slopguard.rs.mem-transmute
pub fn bits_to_float(raw: u32) -> f32 {
    f32::from_bits(raw)
}
