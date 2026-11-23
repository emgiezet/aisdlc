// ruleid: slopguard.rs.mem-transmute
use std::mem;

pub fn bits_to_float(raw: u32) -> f32 {
    unsafe { mem::transmute(raw) }
}
