// ruleid: slopguard.rs.from-utf8-unchecked
pub fn bytes_to_str(bytes: &[u8]) -> &str {
    unsafe { std::str::from_utf8_unchecked(bytes) }
}
