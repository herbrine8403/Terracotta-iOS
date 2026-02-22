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
        let _room_name = unsafe {
            std::ffi::CStr::from_ptr(room_name)
                .to_string_lossy()
                .into_owned()
        };
        
        // 生成房间代码逻辑
        use rand::Rng;
        let mut rng = rand::thread_rng();
        let code = format!("U/{}-{}-{}-{}", 
            rng.gen_range(0..34*34*34*34).to_string(),
            rng.gen_range(0..34*34*34*34).to_string(),
            rng.gen_range(0..34*34*34*34).to_string(),
            rng.gen_range(0..34*34*34*34).to_string()
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
    let impl_func = || {
        if room_code.is_null() {
            return Err("room_code is nullptr".to_string());
        }
        let _room_code = unsafe {
            std::ffi::CStr::from_ptr(room_code)
                .to_string_lossy()
                .into_owned()
        };
        
        // 解析房间代码逻辑
        // 这里需要实现与 Terracotta 相同的房间代码解析逻辑
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
