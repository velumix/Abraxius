use serde_json::{json, Value};
use std::{
    collections::HashMap,
    path::PathBuf,
    sync::{
        atomic::{AtomicU64, Ordering},
        Arc,
    },
};
use tauri::{Emitter, State};
use tokio::{
    io::{AsyncBufReadExt, AsyncWriteExt, BufReader},
    process::{ChildStdin, Command},
    sync::{oneshot, Mutex},
};

struct Backend {
    stdin: Mutex<ChildStdin>,
    pending: Mutex<HashMap<String, oneshot::Sender<Result<Value, String>>>>,
    events: Mutex<Vec<Value>>,
    next_id: AtomicU64,
}

#[tauri::command]
async fn backend_call(
    state: State<'_, Arc<Backend>>,
    name: String,
    args: Vec<Value>,
) -> Result<Value, String> {
    let id = format!("tauri-{}", state.next_id.fetch_add(1, Ordering::Relaxed));
    let (tx, rx) = oneshot::channel();
    state.pending.lock().await.insert(id.clone(), tx);
    let line = serde_json::to_string(&json!({"type":"call", "id": id, "name": name, "args": args}))
        .map_err(|e| e.to_string())?
        + "\n";
    if let Err(error) = state.stdin.lock().await.write_all(line.as_bytes()).await {
        state.pending.lock().await.remove(&id);
        return Err(format!("backend unavailable: {error}"));
    }
    rx.await
        .map_err(|_| "backend stopped before returning a result".to_string())?
}

#[tauri::command]
async fn backend_events(
    state: State<'_, Arc<Backend>>,
    channel: String,
) -> Result<Vec<Value>, String> {
    let events = state.events.lock().await;
    Ok(events
        .iter()
        .filter(|event| event.get("channel").and_then(Value::as_str) == Some(channel.as_str()))
        .filter_map(|event| event.get("value").cloned())
        .collect())
}

fn repo_root() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("../../..")
        .canonicalize()
        .unwrap_or_else(|_| PathBuf::from("."))
}

#[tokio::main]
async fn main() {
    let root = repo_root();
    let mut child = Command::new("node")
        .arg(root.join("app/Abraxius.Linux/backend-rpc.js"))
        .current_dir(&root)
        .env("ELECTRON_RUN_AS_NODE", "1")
        .stdin(std::process::Stdio::piped())
        .stdout(std::process::Stdio::piped())
        .stderr(std::process::Stdio::inherit())
        .spawn()
        .expect("failed to start Abraxius backend");
    let stdin = child.stdin.take().expect("backend stdin unavailable");
    let stdout = child.stdout.take().expect("backend stdout unavailable");
    let backend = Arc::new(Backend {
        stdin: Mutex::new(stdin),
        pending: Mutex::new(HashMap::new()),
        events: Mutex::new(Vec::new()),
        next_id: AtomicU64::new(1),
    });
    let backend_reader = backend.clone();

    tauri::Builder::default()
        .manage(backend)
        .setup(move |app| {
            let app_handle = app.handle().clone();
            tauri::async_runtime::spawn(async move {
                let mut lines = BufReader::new(stdout).lines();
                while let Ok(Some(line)) = lines.next_line().await {
                    let Ok(message) = serde_json::from_str::<Value>(&line) else {
                        continue;
                    };
                    if message.get("type").and_then(Value::as_str) == Some("event") {
                        let mut events = backend_reader.events.lock().await;
                        events.push(message.clone());
                        if events.len() > 1000 {
                            let remove_count = events.len() - 1000;
                            events.drain(0..remove_count);
                        }
                        let _ = app_handle.emit("backend-event", message);
                        continue;
                    }
                    if message.get("type").and_then(Value::as_str) != Some("result") {
                        continue;
                    }
                    let id = message
                        .get("id")
                        .and_then(Value::as_str)
                        .unwrap_or_default()
                        .to_string();
                    let sender = backend_reader.pending.lock().await.remove(&id);
                    if let Some(sender) = sender {
                        let result = if message.get("ok").and_then(Value::as_bool).unwrap_or(false)
                        {
                            Ok(message.get("result").cloned().unwrap_or(Value::Null))
                        } else {
                            Err(message
                                .get("error")
                                .and_then(Value::as_str)
                                .unwrap_or("backend error")
                                .to_string())
                        };
                        let _ = sender.send(result);
                    }
                }
            });
            Ok(())
        })
        .invoke_handler(tauri::generate_handler![backend_call, backend_events])
        .run(tauri::generate_context!())
        .expect("error while running Abraxius Tauri application");
    let _ = child.kill().await;
}
