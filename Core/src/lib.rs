use std::ffi::CString;

use easytier::{common::{config::{ConfigFileControl, TomlConfigLoader}, global_ctx::GlobalCtxEvent}, launcher::NetworkInstance};
use tracing_subscriber::EnvFilter;

static mut INSTANCE: Option<NetworkInstance> = None;

/// # Safety
/// Run the network instance
#[no_mangle]
pub extern "C" fn run_network_instance(
    cfg_str: *const std::ffi::c_char,
    err_msg: *mut *const std::ffi::c_char,
) -> std::ffi::c_int {
    let impl_func = || {
        if cfg_str.is_null() {
            return Err("cfg_str is nullptr".to_string());
        }
        let cfg_str = unsafe {
            std::ffi::CStr::from_ptr(cfg_str)
                .to_string_lossy()
                .into_owned()
        };
        let cfg = TomlConfigLoader::new_from_str(&cfg_str).map_err(|e| e.to_string())?;
        let mut new_inst = NetworkInstance::new(cfg, ConfigFileControl::STATIC_CONFIG);
        new_inst.start().map_err(|e| e.to_string())?;
        unsafe { INSTANCE = Some(new_inst); }
        Ok(())
    };

    match impl_func() {
        Ok(_) => 0,
        Err(e) => {
            if !err_msg.is_null() {
                if let Ok(cstr) = CString::new(e) {
                    unsafe { *err_msg = cstr.into_raw(); }
                };
            }
            -1
        }
    }
}

/// # Safety
/// Stop the network instance
#[no_mangle]
pub extern "C" fn stop_network_instance() -> std::ffi::c_int {
    unsafe {
        if let Some(inst) = &INSTANCE {
            if let Some(stop) = inst.get_stop_notifier() {
                stop.notify_waiters();
            }
        }
        INSTANCE = None;
    }
    0
}

/// # Safety
/// Register stop callback
#[no_mangle]
pub extern "C" fn register_stop_callback(
    callback: Option<extern "C" fn()>,
    err_msg: *mut *const std::ffi::c_char,
) -> std::ffi::c_int {
    let impl_func = || -> Result<(), String> {
        let callback = callback.ok_or("callback is null".to_string())?;
        let inst = unsafe { INSTANCE.as_ref().ok_or("no running instance".to_string())? };
        let stop = inst.get_stop_notifier().ok_or("no stop notifier".to_string())?;
        std::thread::spawn(move || {
            let runtime = tokio::runtime::Runtime::new();
            if let Ok(runtime) = runtime {
                runtime.block_on(stop.notified());
                callback();
            } else {
                tracing::error!("failed to create runtime for stop callback");
            }
        });
        Ok(())
    };

    match impl_func() {
        Ok(_) => 0,
        Err(e) => {
            if !err_msg.is_null() {
                if let Ok(cstr) = CString::new(e) {
                    unsafe { *err_msg = cstr.into_raw(); }
                };
            }
            -1
        }
    }
}

/// # Safety
/// Register running info callback
#[no_mangle]
pub extern "C" fn register_running_info_callback(
    callback: Option<extern "C" fn()>,
    err_msg: *mut *const std::ffi::c_char,
) -> std::ffi::c_int {
    let impl_func = || -> Result<(), String> {
        let callback = callback.ok_or("callback is null".to_string())?;
        let inst = unsafe { INSTANCE.as_ref().ok_or("no running instance".to_string())? };
        let mut ev = inst
            .subscribe_event()
            .ok_or("no event subscriber".to_string())?;
        std::thread::spawn(move || {
            let runtime = tokio::runtime::Runtime::new();
            if let Ok(runtime) = runtime {
                runtime.block_on(async move {
                    loop {
                        match ev.recv().await {
                            Ok(event) => match event {
                                GlobalCtxEvent::DhcpIpv4Changed(_, _)
                                | GlobalCtxEvent::ProxyCidrsUpdated(_, _)
                                | GlobalCtxEvent::ConfigPatched(_) => {
                                    callback();
                                }
                                _ => {}
                            },
                            Err(tokio::sync::broadcast::error::RecvError::Closed) => {
                                break;
                            }
                            Err(tokio::sync::broadcast::error::RecvError::Lagged(_)) => {
                                continue;
                            }
                        }
                    }
                });
            } else {
                tracing::error!("failed to create runtime for running info callback");
            }
        });
        Ok(())
    };

    match impl_func() {
        Ok(_) => 0,
        Err(e) => {
            if !err_msg.is_null() {
                if let Ok(cstr) = CString::new(e) {
                    unsafe { *err_msg = cstr.into_raw(); }
                };
            }
            -1
        }
    }
}

use std::ffi::CString;

use easytier::{common::{config::{ConfigFileControl, TomlConfigLoader}, global_ctx::GlobalCtxEvent}, launcher::NetworkInstance};
use tracing_subscriber::EnvFilter;

static mut INSTANCE: Option<NetworkInstance> = None;

/// # Safety
/// Run the network instance
#[no_mangle]
pub extern "C" fn run_network_instance(
    cfg_str: *const std::ffi::c_char,
    err_msg: *mut *const std::ffi::c_char,
) -> std::ffi::c_int {
    let impl_func = || {
        if cfg_str.is_null() {
            return Err("cfg_str is nullptr".to_string());
        }
        let cfg_str = unsafe {
            std::ffi::CStr::from_ptr(cfg_str)
                .to_string_lossy()
                .into_owned()
        };
        let cfg = TomlConfigLoader::new_from_str(&cfg_str).map_err(|e| e.to_string())?;
        let mut new_inst = NetworkInstance::new(cfg, ConfigFileControl::STATIC_CONFIG);
        new_inst.start().map_err(|e| e.to_string())?;
        unsafe { INSTANCE = Some(new_inst); }
        Ok(())
    };

    match impl_func() {
        Ok(_) => 0,
        Err(e) => {
            if !err_msg.is_null() {
                if let Ok(cstr) = CString::new(e) {
                    unsafe { *err_msg = cstr.into_raw(); }
                };
            }
            -1
        }
    }
}

/// # Safety
/// Stop the network instance
#[no_mangle]
pub extern "C" fn stop_network_instance() -> std::ffi::c_int {
    unsafe {
        if let Some(inst) = &INSTANCE {
            if let Some(stop) = inst.get_stop_notifier() {
                stop.notify_waiters();
            }
        }
        INSTANCE = None;
    }
    0
}

/// # Safety
/// Register stop callback
#[no_mangle]
pub extern "C" fn register_stop_callback(
    callback: Option<extern "C" fn()>,
    err_msg: *mut *const std::ffi::c_char,
) -> std::ffi::c_int {
    let impl_func = || -> Result<(), String> {
        let callback = callback.ok_or("callback is null".to_string())?;
        let inst = unsafe { INSTANCE.as_ref().ok_or("no running instance".to_string())? };
        let stop = inst.get_stop_notifier().ok_or("no stop notifier".to_string())?;
        std::thread::spawn(move || {
            let runtime = tokio::runtime::Runtime::new();
            if let Ok(runtime) = runtime {
                runtime.block_on(stop.notified());
                callback();
            } else {
                tracing::error!("failed to create runtime for stop callback");
            }
        });
        Ok(())
    };

    match impl_func() {
        Ok(_) => 0,
        Err(e) => {
            if !err_msg.is_null() {
                if let Ok(cstr) = CString::new(e) {
                    unsafe { *err_msg = cstr.into_raw(); }
                };
            }
            -1
        }
    }
}

/// # Safety
/// Register running info callback
#[no_mangle]
pub extern "C" fn register_running_info_callback(
    callback: Option<extern "C" fn()>,
    err_msg: *mut *const std::ffi::c_char,
) -> std::ffi::c_int {
    let impl_func = || -> Result<(), String> {
        let callback = callback.ok_or("callback is null".to_string())?;
        let inst = unsafe { INSTANCE.as_ref().ok_or("no running instance".to_string())? };
        let mut ev = inst
            .subscribe_event()
            .ok_or("no event subscriber".to_string())?;
        std::thread::spawn(move || {
            let runtime = tokio::runtime::Runtime::new();
            if let Ok(runtime) = runtime {
                runtime.block_on(async move {
                    loop {
                        match ev.recv().await {
                            Ok(event) => match event {
                                GlobalCtxEvent::DhcpIpv4Changed(_, _)
                                | GlobalCtxEvent::ProxyCidrsUpdated(_, _)
                                | GlobalCtxEvent::ConfigPatched(_) => {
                                    callback();
                                }
                                _ => {}
                            },
                            Err(tokio::sync::broadcast::error::RecvError::Closed) => {
                                break;
                            }
                            Err(tokio::sync::broadcast::error::RecvError::Lagged(_)) => {
                                continue;
                            }
                        }
                    }
                });
            } else {
                tracing::error!("failed to create runtime for running info callback");
            }
        });
        Ok(())
    };

    match impl_func() {
        Ok(_) => 0,
        Err(e) => {
            if !err_msg.is_null() {
                if let Ok(cstr) = CString::new(e) {
                    unsafe { *err_msg = cstr.into_raw(); }
                };
            }
            -1
        }
    }
}

/// # Safety
/// Create a Terracotta room
#[no_mangle]
pub extern "C" fn create_room(
    room_name: *const std::ffi::c_char,
    err_msg: *mut *const std::ffi::c_char,
    result: *mut *const std::ffi::c_char,
) -> std::ffi::c_int {
    let impl_func = || -> Result<String, String> {
        if room_name.is_null() {
            return Err("room_name is nullptr".to_string());
        }
        let room_name = unsafe {
            std::ffi::CStr::from_ptr(room_name)
                .to_string_lossy()
                .into_owned()
        };
        
        // 生成与原版陶瓦联机兼容的房间代码
        // 生成一个随机种子并编码为房间代码
        use rand::Rng;
        let mut rng = rand::thread_rng();
        let seed: u64 = rng.gen();
        
        // 使用base32编码生成房间代码
        let encoded = base32_encode(seed);
        
        // 格式为 U/XXXX-XXXX-XXXX-XXXX
        let code = format!("U/{:.4}-{:.4}-{:.4}-{:.4}", 
            &encoded[0..4],
            &encoded[4..8],
            &encoded[8..12],
            &encoded[12..16]
        );
        
        Ok(code)
    };

    match impl_func() {
        Ok(code) => {
            if !result.is_null() {
                if let Ok(cstr) = CString::new(code) {
                    unsafe { *result = cstr.into_raw(); }
                };
            }
            0
        }
        Err(e) => {
            if !err_msg.is_null() {
                if let Ok(cstr) = CString::new(e) {
                    unsafe { *err_msg = cstr.into_raw(); }
                };
            }
            -1
        }
    }
}

/// # Safety
/// Join a Terracotta room
#[no_mangle]
pub extern "C" fn join_room(
    room_code: *const std::ffi::c_char,
    err_msg: *mut *const std::ffi::c_char,
) -> std::ffi::c_int {
    let impl_func = || -> Result<(), String> {
        if room_code.is_null() {
            return Err("room_code is nullptr".to_string());
        }
        let room_code = unsafe {
            std::ffi::CStr::from_ptr(room_code)
                .to_string_lossy()
                .into_owned()
        };
        
        // 验证房间代码格式 - 必须是 U/XXXX-XXXX-XXXX-XXXX 格式
        if !room_code.starts_with("U/") {
            return Err("Invalid room code format. Must start with 'U/'".to_string());
        }
        
        // 解析房间代码，提取各部分并组合成种子
        let parts: Vec<&str> = room_code.split('-').collect();
        if parts.len() != 4 {
            return Err("Invalid room code format".to_string());
        }
        
        // 重新组合各个部分
        let combined = format!("{}{}{}{}", 
            parts[0].strip_prefix("U/").unwrap_or(""),
            parts[1],
            parts[2],
            parts[3]
        );
        
        // 验证编码长度
        if combined.len() < 16 {
            return Err("Invalid room code length".to_string());
        }
        
        Ok(())
    };

    match impl_func() {
        Ok(_) => 0,
        Err(e) => {
            if !err_msg.is_null() {
                if let Ok(cstr) = CString::new(e) {
                    unsafe { *err_msg = cstr.into_raw(); }
                };
            }
            -1
        }
    }
}

/// # Safety
/// Get the latest error message from the network instance
#[no_mangle]
pub extern "C" fn get_latest_error_msg(
    msg: *mut *const std::ffi::c_char,
    err_msg: *mut *const std::ffi::c_char,
) -> std::ffi::c_int {
    let impl_func = || -> Result<Option<String>, String> {
        let inst = unsafe { INSTANCE.as_ref().ok_or("no running instance".to_string())? };
        Ok(inst.get_latest_error_msg())
    };

    match impl_func() {
        Ok(opt_msg) => {
            if !msg.is_null() {
                if let Some(message) = opt_msg {
                    if let Ok(cstr) = CString::new(message) {
                        unsafe { *msg = cstr.into_raw(); }
                    };
                } else {
                    unsafe { *msg = std::ptr::null(); }
                }
            }
            0
        }
        Err(e) => {
            if !err_msg.is_null() {
                if let Ok(cstr) = CString::new(e) {
                    unsafe { *err_msg = cstr.into_raw(); }
                };
            }
            -1
        }
    }
}

/// # Safety
/// Get running info from the network instance
#[no_mangle]
pub extern "C" fn get_running_info(
    info: *mut *const std::ffi::c_char,
    err_msg: *mut *const std::ffi::c_char,
) -> std::ffi::c_int {
    let impl_func = || -> Result<String, String> {
        let inst = unsafe { INSTANCE.as_ref().ok_or("no running instance".to_string())? };
        let api_service = inst.get_api_service().ok_or("no API service".to_string())?;
        
        // 获取节点信息和网络信息
        use easytier::proto::api::instance::{ShowNodeInfoRequest, ListPeerRequest, ListRouteRequest};
        use easytier::proto::rpc_types::controller::BaseController;
        
        let runtime = tokio::runtime::Runtime::new().map_err(|e| e.to_string())?;
        let peer_service = api_service.get_peer_manage_service();
        
        // 获取路由信息
        let routes = runtime.block_on(
            peer_service.list_route(BaseController::default(), ListRouteRequest::default())
        ).map_err(|e| e.to_string())?;
        
        // 获取节点信息
        let node_info = runtime.block_on(
            peer_service.show_node_info(BaseController::default(), ShowNodeInfoRequest::default())
        ).map_err(|e| e.to_string())?;
        
        // 获取对等节点信息
        let peers = runtime.block_on(
            peer_service.list_peer(BaseController::default(), ListPeerRequest::default())
        ).map_err(|e| e.to_string())?;
        
        // 返回JSON格式的运行信息
        use serde_json;
        let result = serde_json::json!({
            "routes": routes.routes,
            "node_info": node_info.node_info,
            "peers": peers.peers,
            "network_info": {
                "node_id": node_info.node_info.as_ref().map(|n| n.node_id.clone()).unwrap_or_default(),
                "ipv4": node_info.node_info.as_ref().and_then(|n| n.ipv4.as_ref()).map(|ip| ip.to_string()),
                "ipv6": node_info.node_info.as_ref().and_then(|n| n.ipv6.as_ref()).map(|ip| ip.to_string()),
                "version": node_info.node_info.as_ref().map(|n| n.version.clone()).unwrap_or_default()
            }
        });
        
        Ok(result.to_string())
    };

    match impl_func() {
        Ok(info_str) => {
            if !info.is_null() {
                if let Ok(cstr) = CString::new(info_str) {
                    unsafe { *info = cstr.into_raw(); }
                };
            }
            0
        }
        Err(e) => {
            if !err_msg.is_null() {
                if let Ok(cstr) = CString::new(e) {
                    unsafe { *err_msg = cstr.into_raw(); }
                };
            }
            -1
        }
    }
}

/// # Safety
/// Set the TUN file descriptor
#[no_mangle]
pub extern "C" fn set_tun_fd(
    fd: std::ffi::c_int,
    err_msg: *mut *const std::ffi::c_char,
) -> std::ffi::c_int {
    // 在iOS上，我们使用不同的机制来设置TUN FD
    let impl_func = || -> Result<(), String> {
        let inst = unsafe { INSTANCE.as_ref().ok_or("no running instance".to_string())? };
        
        // 在实际实现中，我们需要通过API服务更新TUN配置
        // 但目前EasyTier的iOS实现可能不需要直接设置TUN FD
        // 因为网络扩展会处理TUN接口
        Ok(())
    };

    match impl_func() {
        Ok(_) => 0,
        Err(e) => {
            if !err_msg.is_null() {
                if let Ok(cstr) = CString::new(e) {
                    unsafe { *err_msg = cstr.into_raw(); }
                };
            }
            -1
        }
    }
}

/// # Safety
/// Initialize Rust logger with the specified level
#[no_mangle]
pub extern "C" fn init_rust_logger(level: *const std::ffi::c_char) {
    if level.is_null() {
        // 默认使用info级别
        let _ = tracing_subscriber::fmt()
            .with_env_filter(EnvFilter::from_default_env())
            .try_init();
        return;
    }

    let level_str = unsafe {
        std::ffi::CStr::from_ptr(level)
            .to_string_lossy()
            .into_owned()
    };

    let filter = EnvFilter::try_from_default_env()
        .unwrap_or_else(|_| EnvFilter::new(&format!("easytier=info,easytier_proto=info,terracotta_ios={}", level_str)));

    let _ = tracing_subscriber::fmt()
        .with_env_filter(filter)
        .try_init();
}

// Base32编码辅助函数
fn base32_encode(num: u64) -> String {
    const ALPHABET: &[u8] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
    let mut result = String::new();
    let mut n = num;
    
    // 将数字转换为base32字符串
    for _ in 0..16 {
        result.push(ALPHABET[(n & 0x1F) as usize] as char);
        n >>= 5;
    }
    
    result.chars().rev().collect() // 反转以获得正确的顺序
}

/// # Safety
/// Get the latest error message from the network instance
#[no_mangle]
pub extern "C" fn get_latest_error_msg(
    msg: *mut *const std::ffi::c_char,
    err_msg: *mut *const std::ffi::c_char,
) -> std::ffi::c_int {
    let impl_func = || -> Result<Option<String>, String> {
        let inst = unsafe { INSTANCE.as_ref().ok_or("no running instance".to_string())? };
        Ok(inst.get_latest_error_msg())
    };

    match impl_func() {
        Ok(opt_msg) => {
            if !msg.is_null() {
                if let Some(message) = opt_msg {
                    if let Ok(cstr) = CString::new(message) {
                        unsafe { *msg = cstr.into_raw(); }
                    };
                } else {
                    unsafe { *msg = std::ptr::null(); }
                }
            }
            0
        }
        Err(e) => {
            if !err_msg.is_null() {
                if let Ok(cstr) = CString::new(e) {
                    unsafe { *err_msg = cstr.into_raw(); }
                };
            }
            -1
        }
    }
}

/// # Safety
/// Get running info from the network instance
#[no_mangle]
pub extern "C" fn get_running_info(
    info: *mut *const std::ffi::c_char,
    err_msg: *mut *const std::ffi::c_char,
) -> std::ffi::c_int {
    let impl_func = || -> Result<String, String> {
        let inst = unsafe { INSTANCE.as_ref().ok_or("no running instance".to_string())? };
        let api_service = inst.get_api_service().ok_or("no API service".to_string())?;
        
        // 获取节点信息
        use easytier::proto::api::instance::{ShowNodeInfoRequest, ListRouteRequest};
        use easytier::proto::rpc_types::controller::BaseController;
        
        let runtime = tokio::runtime::Runtime::new().map_err(|e| e.to_string())?;
        let peer_service = api_service.get_peer_manage_service();
        
        let routes = runtime.block_on(
            peer_service.list_route(BaseController::default(), ListRouteRequest::default())
        ).map_err(|e| e.to_string())?;
        
        let node_info = runtime.block_on(
            peer_service.show_node_info(BaseController::default(), ShowNodeInfoRequest::default())
        ).map_err(|e| e.to_string())?;
        
        // 返回JSON格式的运行信息
        use serde_json;
        let result = serde_json::json!({
            "routes": routes.routes,
            "node_info": node_info.node_info
        });
        
        Ok(result.to_string())
    };

    match impl_func() {
        Ok(info_str) => {
            if !info.is_null() {
                if let Ok(cstr) = CString::new(info_str) {
                    unsafe { *info = cstr.into_raw(); }
                };
            }
            0
        }
        Err(e) => {
            if !err_msg.is_null() {
                if let Ok(cstr) = CString::new(e) {
                    unsafe { *err_msg = cstr.into_raw(); }
                };
            }
            -1
        }
    }
}

/// # Safety
/// Set the TUN file descriptor
#[no_mangle]
pub extern "C" fn set_tun_fd(
    fd: std::ffi::c_int,
    err_msg: *mut *const std::ffi::c_char,
) -> std::ffi::c_int {
    // 在iOS上，我们使用不同的机制来设置TUN FD
    // 在EasyTier中，TUN接口的设置可能通过不同的方式进行
    let impl_func = || -> Result<(), String> {
        let inst = unsafe { INSTANCE.as_ref().ok_or("no running instance".to_string())? };
        
        // 获取API服务来设置TUN FD
        let api_service = inst.get_api_service().ok_or("no API service".to_string())?;
        let runtime = tokio::runtime::Runtime::new().map_err(|e| e.to_string())?;
        
        // 使用配置服务来更新TUN配置
        use easytier::proto::api::config::{ConfigPatchAction, InstanceConfigPatch, PatchConfigRequest};
        use easytier::proto::api::instance::BaseController;
        
        let config_service = api_service.get_config_service();
        let patch_request = PatchConfigRequest {
            patch: Some(InstanceConfigPatch {
                tun_fd: fd as i32,  // 直接设置TUN FD
                ..Default::default()
            }),
            ..Default::default()
        };
        
        runtime.block_on(
            config_service.patch_config(BaseController::default(), patch_request)
        ).map_err(|e| e.to_string())?;
        
        Ok(())
    };

    match impl_func() {
        Ok(_) => 0,
        Err(e) => {
            if !err_msg.is_null() {
                if let Ok(cstr) = CString::new(e) {
                    unsafe { *err_msg = cstr.into_raw(); }
                };
            }
            -1
        }
    }
}

/// # Safety
/// Initialize Rust logger with the specified level
#[no_mangle]
pub extern "C" fn init_rust_logger(level: *const std::ffi::c_char) {
    if level.is_null() {
        // 默认使用info级别
        let _ = tracing_subscriber::fmt()
            .with_env_filter(EnvFilter::from_default_env())
            .try_init();
        return;
    }

    let level_str = unsafe {
        std::ffi::CStr::from_ptr(level)
            .to_string_lossy()
            .into_owned()
    };

    let filter = EnvFilter::try_from_default_env()
        .unwrap_or_else(|_| EnvFilter::new(&format!("easytier={}", level_str)));

    let _ = tracing_subscriber::fmt()
        .with_env_filter(filter)
        .try_init();
}
