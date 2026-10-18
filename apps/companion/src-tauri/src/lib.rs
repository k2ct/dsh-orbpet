pub mod acp;
mod balance;
mod dsh;

use std::{env, path::PathBuf};
use tauri::{
    menu::{Menu, MenuItem},
    tray::{MouseButton, MouseButtonState, TrayIconBuilder, TrayIconEvent},
    Manager, WebviewWindow,
};

fn smoke_test_mode() -> bool {
    env::var_os("DSH_COMPANION_SMOKE_TEST").is_some()
}

fn native_self_test_path() -> Option<std::path::PathBuf> {
    env::var_os("DSH_COMPANION_NATIVE_SELF_TEST").map(std::path::PathBuf::from)
}

#[tauri::command]
fn set_click_through(window: WebviewWindow, enabled: bool) -> Result<(), String> {
    window
        .set_ignore_cursor_events(enabled)
        .map_err(|error| error.to_string())
}

fn acp_session_file() -> PathBuf {
    env::var_os("LOCALAPPDATA")
        .map(PathBuf::from)
        .unwrap_or_else(env::temp_dir)
        .join("DSH Companion")
        .join("acp-session-id")
}

pub fn run() {
    tauri::Builder::default()
        .manage(acp::AcpManager::new(acp_session_file()))
        .plugin(tauri_plugin_single_instance::init(|app, _args, _cwd| {
            if let Some(window) = app.get_webview_window("main") {
                let _ = window.show();
                let _ = window.set_focus();
            }
        }))
        .setup(|app| {
            if smoke_test_mode() {
                if let Some(window) = app.get_webview_window("main") {
                    window.hide()?;
                }
            }

            let show = MenuItem::with_id(app, "show", "显示桌宠", true, None::<&str>)?;
            let hide = MenuItem::with_id(app, "hide", "隐藏桌宠", true, None::<&str>)?;
            let quit = MenuItem::with_id(app, "quit", "退出", true, None::<&str>)?;
            let menu = Menu::with_items(app, &[&show, &hide, &quit])?;

            TrayIconBuilder::new()
                .tooltip("DSH Companion")
                .menu(&menu)
                .on_menu_event(|app, event| match event.id.as_ref() {
                    "show" => {
                        if let Some(window) = app.get_webview_window("main") {
                            let _ = window.set_ignore_cursor_events(false);
                            let _ = window.show();
                            let _ = window.set_focus();
                        }
                    }
                    "hide" => {
                        if let Some(window) = app.get_webview_window("main") {
                            let _ = window.hide();
                        }
                    }
                    "quit" => app.exit(0),
                    _ => {}
                })
                .on_tray_icon_event(|tray, event| {
                    if let TrayIconEvent::Click {
                        button: MouseButton::Left,
                        button_state: MouseButtonState::Up,
                        ..
                    } = event
                    {
                        let app = tray.app_handle();
                        if let Some(window) = app.get_webview_window("main") {
                            let _ = window.set_ignore_cursor_events(false);
                            let _ = window.show();
                            let _ = window.set_focus();
                        }
                    }
                })
                .build(app)?;

            if let Some(result_path) = native_self_test_path() {
                if let Some(window) = app.get_webview_window("main") {
                    window.hide()?;
                    window.set_ignore_cursor_events(true)?;
                    window.set_ignore_cursor_events(false)?;
                }
                std::fs::write(
                    result_path,
                    r#"{"trayInitialized":true,"clickThroughEnabled":true,"clickThroughRestored":true}"#,
                )?;
                app.handle().exit(0);
            }

            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            set_click_through,
            dsh::probe_dsh_environment,
            dsh::acp_handshake,
            dsh::acp_prompt_stream,
            dsh::acp_cancel,
            dsh::acp_disconnect,
            balance::deepseek_credential_status,
            balance::save_deepseek_api_key,
            balance::delete_deepseek_api_key,
            balance::get_deepseek_balance
        ])
        .run(tauri::generate_context!())
        .expect("failed to run DSH Companion");
}
