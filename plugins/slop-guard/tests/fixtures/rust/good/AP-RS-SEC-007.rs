// ok: slopguard.rs.from-utf8-unchecked
pub fn bytes_to_str(bytes: &[u8]) -> Result<&str, std::str::Utf8Error> {
    std::str::from_utf8(bytes)
}
