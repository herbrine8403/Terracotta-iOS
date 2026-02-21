use std::ffi::CString;

use easytier::{common::{config::{ConfigFileControl, TomlConfigLoader}, global_ctx::GlobalCtxEvent}, launcher::NetworkInstance};

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
