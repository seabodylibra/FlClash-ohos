use crate::api::hotkey::{HotKeyFailure, HotKeySpec};
use crate::frb_generated::StreamSink;
use flutter_rust_bridge::for_generated::SseCodec;

// Mobile platforms have no global shortcuts; these entry points keep one set of bindings for every platform.
const UNSUPPORTED: &str = "Global hotkeys are not available on this platform";

pub fn listen(_sink: StreamSink<u32, SseCodec>) -> Result<(), String> {
    Err(UNSUPPORTED.into())
}

pub fn set_hot_keys(_specs: Vec<HotKeySpec>) -> Result<Vec<HotKeyFailure>, String> {
    Err(UNSUPPORTED.into())
}
