use axum::extract::ws::{Message, WebSocket, WebSocketUpgrade};
use axum::extract::{Query, State};
use axum::http::StatusCode;
use axum::response::{IntoResponse, Response};
use axum::routing::{get, post};
use axum::{Json, Router};
use futures_util::{SinkExt, StreamExt};
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};
use std::collections::{HashMap, VecDeque};
use std::net::SocketAddr;
use std::path::PathBuf;
use std::sync::Arc;
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};
use tokio::sync::{Mutex, mpsc, oneshot};

const MCP_PORT: u16 = 13469;
const API_PORT: u16 = 13470;
const PLUGIN_PORT: u16 = 13471;
const PROTOCOL_VERSION: &str = "2024-11-05";

#[tokio::main]
async fn main() {
    if let Err(err) = run().await {
        eprintln!("Rust daemon failed: {err}");
        std::process::exit(1);
    }
}

async fn run() -> Result<(), String> {
    let state = AppState::new();

    let mcp_router = Router::new()
        .route("/studio", get(mcp_ws))
        .with_state(state.clone());
    let api_router = api_router(state.clone());
    let plugin_router = plugin_router(state.clone());

    println!("Rust MCP bridge listening on ws://localhost:{MCP_PORT}/studio");
    println!("Rust HTTP API listening on http://localhost:{API_PORT}");
    println!("Rust companion channel listening on http://localhost:{PLUGIN_PORT}");

    tokio::try_join!(
        serve(mcp_router, MCP_PORT),
        serve(api_router, API_PORT),
        serve(plugin_router, PLUGIN_PORT),
    )
    .map(|_| ())
}

async fn serve(router: Router, port: u16) -> Result<(), String> {
    let addr = SocketAddr::from(([127, 0, 0, 1], port));
    let listener = tokio::net::TcpListener::bind(addr)
        .await
        .map_err(|err| format!("failed to bind {addr}: {err}"))?;
    axum::serve(listener, router)
        .await
        .map_err(|err| err.to_string())
}

fn api_router(state: AppState) -> Router {
    Router::new()
        .route("/health", get(api_health))
        .route("/tools", get(api_tools))
        .route("/call", post(api_call))
        .route("/state", get(api_state))
        .route("/execute", post(api_execute))
        .route("/log", post(api_log))
        .route("/context", get(api_context).post(api_set_context))
        .route("/ai-context", get(api_ai_context))
        .route("/memory", get(api_memory).post(api_remember))
        .route("/memory/clear", post(api_memory_clear))
        .route("/pending", get(api_pending))
        .route("/pending/verify", post(api_pending_verify))
        .route("/pending/clear", post(api_pending_clear))
        .route("/plugin/status", get(api_plugin_status))
        .route("/plugin/events", get(api_plugin_events))
        .route("/plugin/call", post(api_plugin_call))
        .route("/shutdown", post(api_shutdown))
        .with_state(state)
}

fn plugin_router(state: AppState) -> Router {
    Router::new()
        .route("/health", get(plugin_health))
        .route("/plugin/register", post(plugin_register))
        .route("/plugin/report", post(plugin_report))
        .route("/plugin/status", get(plugin_status))
        .route("/plugin/events", get(plugin_events))
        .route("/plugin/call", post(plugin_call))
        .with_state(state)
}

#[derive(Clone)]
struct AppState {
    bridge: Arc<Mutex<BridgeState>>,
    context: Arc<Mutex<ContextState>>,
    plugin: Arc<Mutex<PluginState>>,
    pending_pushes: Arc<Mutex<HashMap<String, PendingPush>>>,
    started_at: Instant,
}

impl AppState {
    fn new() -> Self {
        Self {
            bridge: Arc::new(Mutex::new(BridgeState::default())),
            context: Arc::new(Mutex::new(ContextState::default())),
            plugin: Arc::new(Mutex::new(PluginState::default())),
            pending_pushes: Arc::new(Mutex::new(HashMap::new())),
            started_at: Instant::now(),
        }
    }
}

#[derive(Default)]
struct BridgeState {
    connected: bool,
    ready: bool,
    next_id: u64,
    sender: Option<mpsc::UnboundedSender<Value>>,
    pending: HashMap<String, oneshot::Sender<Result<Value, String>>>,
    server_info: Option<Value>,
    tools: Vec<Value>,
    connected_at: Option<Instant>,
    generation: u64,
}

#[derive(Default, Serialize)]
#[serde(rename_all = "camelCase")]
struct ContextState {
    project_dir: Option<String>,
    preferred_datamodel: String,
    current_datamodel: Option<String>,
    recent_scripts: VecDeque<String>,
    recent_operations: VecDeque<Operation>,
    studio: Value,
    studio_event_counts: HashMap<String, u64>,
    recent_studio_events: VecDeque<Value>,
    recent_studio_errors: VecDeque<Value>,
}

#[derive(Clone, Serialize)]
struct Operation {
    time: u128,
    op: String,
    target: Option<String>,
    datamodel: Option<String>,
    summary: Option<String>,
}

#[derive(Default)]
struct PluginState {
    session: Option<PluginSession>,
    events: VecDeque<Value>,
    next_event_id: u64,
}

struct PluginSession {
    id: String,
    created_at: u128,
    last_seen_at: u128,
    commands: VecDeque<Value>,
    pending: HashMap<String, oneshot::Sender<Result<Value, String>>>,
}

#[derive(Clone, Serialize)]
#[serde(rename_all = "camelCase")]
struct PendingPush {
    path: String,
    source_hash: String,
    pushed_at: u128,
    status: String,
    verified_at: Option<u128>,
    stale: Option<bool>,
    error: Option<String>,
}

async fn mcp_ws(ws: WebSocketUpgrade, State(state): State<AppState>) -> Response {
    ws.on_upgrade(move |socket| async move {
        if let Err(err) = handle_mcp_socket(socket, state).await {
            eprintln!("[rust-bridge] websocket error: {err}");
        }
    })
}

async fn handle_mcp_socket(socket: WebSocket, state: AppState) -> Result<(), String> {
    let (mut sink, mut stream) = socket.split();
    let (tx, mut rx) = mpsc::unbounded_channel::<Value>();

    let generation = {
        let mut bridge = state.bridge.lock().await;
        if bridge.connected && bridge.ready {
            return Err("Studio already connected".into());
        }
        for (_, pending) in bridge.pending.drain() {
            let _ = pending.send(Err("Studio connection replaced".into()));
        }
        bridge.connected = true;
        bridge.ready = false;
        bridge.sender = Some(tx.clone());
        bridge.connected_at = Some(Instant::now());
        bridge.generation += 1;
        bridge.generation
    };

    let writer = tokio::spawn(async move {
        while let Some(value) = rx.recv().await {
            if sink
                .send(Message::Text(value.to_string().into()))
                .await
                .is_err()
            {
                break;
            }
        }
    });

    let reader_state = state.clone();
    let reader = tokio::spawn(async move {
        while let Some(message) = stream.next().await {
            match message.map_err(|err| err.to_string())? {
                Message::Text(text) => handle_mcp_message(&reader_state, &text).await?,
                Message::Binary(bytes) => {
                    if let Ok(text) = String::from_utf8(bytes.to_vec()) {
                        handle_mcp_message(&reader_state, &text).await?;
                    }
                }
                Message::Close(_) => break,
                _ => {}
            }
        }
        Ok::<(), String>(())
    });

    let init_result = match bridge_request(
        &state,
        "initialize",
        json!({
            "protocolVersion": PROTOCOL_VERSION,
            "capabilities": { "roots": { "listChanged": true } },
            "clientInfo": { "name": "abraxius-rs", "version": env!("CARGO_PKG_VERSION") }
        }),
    )
    .await
    {
        Ok(result) => result,
        Err(err) => {
            reader.abort();
            writer.abort();
            cleanup_mcp_connection(&state, generation).await;
            return Err(err);
        }
    };
    {
        let mut bridge = state.bridge.lock().await;
        bridge.server_info = Some(init_result);
        bridge.ready = true;
    }
    if let Err(err) = bridge_notify(&state, "notifications/initialized", json!({})).await {
        reader.abort();
        writer.abort();
        cleanup_mcp_connection(&state, generation).await;
        return Err(err);
    }
    let _ = log_to_studio(&state, "[Abraxius] Rust bridge connected").await;

    let read_result = match reader.await {
        Ok(result) => result,
        Err(err) => Err(err.to_string()),
    };
    writer.abort();
    cleanup_mcp_connection(&state, generation).await;
    read_result
}

async fn cleanup_mcp_connection(state: &AppState, generation: u64) {
    let mut bridge = state.bridge.lock().await;
    if bridge.generation != generation {
        return;
    }
    bridge.connected = false;
    bridge.ready = false;
    bridge.sender = None;
    bridge.server_info = None;
    bridge.tools.clear();
    for (_, pending) in bridge.pending.drain() {
        let _ = pending.send(Err("Roblox Studio disconnected".into()));
    }
}

async fn handle_mcp_message(state: &AppState, text: &str) -> Result<(), String> {
    let message: Value = serde_json::from_str(text).map_err(|err| err.to_string())?;
    if let Some(id) = message.get("id").and_then(Value::as_str) {
        let pending = {
            let mut bridge = state.bridge.lock().await;
            bridge.pending.remove(id)
        };
        if let Some(sender) = pending {
            if let Some(error) = message.get("error") {
                let msg = error
                    .get("message")
                    .and_then(Value::as_str)
                    .unwrap_or("MCP error");
                let _ = sender.send(Err(msg.to_string()));
            } else {
                let _ = sender.send(Ok(message.get("result").cloned().unwrap_or(Value::Null)));
            }
            return Ok(());
        }
        if message.get("method").and_then(Value::as_str) == Some("ping") {
            send_mcp_raw(state, json!({ "jsonrpc": "2.0", "id": id, "result": {} })).await?;
        }
    }
    Ok(())
}

async fn bridge_request(state: &AppState, method: &str, params: Value) -> Result<Value, String> {
    let (rx, id) = {
        let mut bridge = state.bridge.lock().await;
        let sender = bridge
            .sender
            .clone()
            .ok_or_else(|| "Roblox Studio not connected".to_string())?;
        bridge.next_id += 1;
        let id = format!("{method}-{}-{}", bridge.next_id, now_ms());
        let (tx, rx) = oneshot::channel();
        bridge.pending.insert(id.clone(), tx);
        sender
            .send(json!({
                "type": "json_rpc",
                "jsonrpc": "2.0",
                "id": id,
                "method": method,
                "params": params
            }))
            .map_err(|_| "failed to send websocket message".to_string())?;
        (rx, id)
    };

    match tokio::time::timeout(Duration::from_secs(30), rx).await {
        Ok(Ok(result)) => result,
        Ok(Err(_)) => Err("request cancelled".into()),
        Err(_) => {
            let mut bridge = state.bridge.lock().await;
            bridge.pending.remove(&id);
            Err("request timed out".into())
        }
    }
}

async fn bridge_notify(state: &AppState, method: &str, params: Value) -> Result<(), String> {
    send_mcp_raw(
        state,
        json!({
            "jsonrpc": "2.0",
            "method": method,
            "params": params
        }),
    )
    .await
}

async fn send_mcp_raw(state: &AppState, mut envelope: Value) -> Result<(), String> {
    envelope
        .as_object_mut()
        .ok_or("invalid envelope")?
        .insert("type".into(), Value::String("json_rpc".into()));
    let sender = state
        .bridge
        .lock()
        .await
        .sender
        .clone()
        .ok_or_else(|| "Roblox Studio not connected".to_string())?;
    sender
        .send(envelope)
        .map_err(|_| "failed to send websocket message".to_string())
}

async fn call_tool(state: &AppState, name: &str, args: Value) -> Result<Value, String> {
    bridge_request(
        state,
        "tools/call",
        json!({
            "name": name,
            "arguments": args
        }),
    )
    .await
}

async fn log_to_studio(state: &AppState, message: &str) -> Result<(), String> {
    let escaped = escape_luau_string(&message.replace(['\r', '\n'], " "));
    let code = format!("print(\"{escaped}\")");
    let _ = call_tool(
        state,
        "execute_luau",
        json!({ "code": code, "datamodel_type": "Edit" }),
    )
    .await;
    Ok(())
}

fn escape_luau_string(value: &str) -> String {
    let mut out = String::new();
    for ch in value.chars() {
        match ch {
            '"' => out.push_str("\\\""),
            '\\' => out.push_str("\\\\"),
            '\n' => out.push_str("\\n"),
            '\r' => out.push_str("\\r"),
            c => out.push(c),
        }
    }
    out
}

async fn api_health(State(state): State<AppState>) -> impl IntoResponse {
    let bridge = state.bridge.lock().await;
    let plugin = state.plugin.lock().await;
    Json(json!({
        "running": true,
        "rust": true,
        "connected": bridge.ready,
        "studio": bridge.server_info,
        "toolsLoaded": bridge.tools.len(),
        "pluginConnected": plugin_connected(&plugin),
        "pluginEvents": plugin.events.len(),
        "uptime": state.started_at.elapsed().as_secs(),
        "studioUptime": bridge.connected_at.map(|t| t.elapsed().as_secs()).unwrap_or(0),
        "version": env!("CARGO_PKG_VERSION"),
        "pid": std::process::id()
    }))
}

async fn api_tools(State(state): State<AppState>) -> impl IntoResponse {
    match bridge_request(&state, "tools/list", json!({})).await {
        Ok(result) => {
            let tools = result
                .get("tools")
                .and_then(Value::as_array)
                .cloned()
                .unwrap_or_default();
            state.bridge.lock().await.tools = tools.clone();
            ok(json!({ "tools": tools }))
        }
        Err(err) => error(StatusCode::SERVICE_UNAVAILABLE, err),
    }
}

#[derive(Deserialize)]
struct ToolCall {
    name: String,
    #[serde(default, rename = "arguments")]
    args: Value,
}

async fn api_call(State(state): State<AppState>, Json(body): Json<ToolCall>) -> impl IntoResponse {
    match call_tool(&state, &body.name, body.args.clone()).await {
        Ok(result) => {
            if body.name == "multi_edit" {
                record_pending_from_args(&state, &body.args).await;
            }
            ok(result)
        }
        Err(err) => error(StatusCode::SERVICE_UNAVAILABLE, err),
    }
}

async fn api_state(State(state): State<AppState>) -> impl IntoResponse {
    match call_tool(&state, "get_studio_state", json!({})).await {
        Ok(result) => ok(result),
        Err(err) => error(StatusCode::SERVICE_UNAVAILABLE, err),
    }
}

#[derive(Deserialize)]
struct ExecuteBody {
    code: String,
    datamodel_type: Option<String>,
}

async fn api_execute(
    State(state): State<AppState>,
    Json(body): Json<ExecuteBody>,
) -> impl IntoResponse {
    let datamodel = body.datamodel_type.unwrap_or_else(|| "Edit".into());
    match call_tool(
        &state,
        "execute_luau",
        json!({ "code": body.code, "datamodel_type": datamodel }),
    )
    .await
    {
        Ok(result) => {
            record_operation(&state, "execute", None, Some("execute_luau".into())).await;
            ok(result)
        }
        Err(err) => error(StatusCode::SERVICE_UNAVAILABLE, err),
    }
}

#[derive(Deserialize)]
struct LogBody {
    message: String,
}

async fn api_log(State(state): State<AppState>, Json(body): Json<LogBody>) -> impl IntoResponse {
    let _ = log_to_studio(&state, &body.message).await;
    ok(json!({ "ok": true }))
}

async fn api_context(State(state): State<AppState>) -> impl IntoResponse {
    Json(context_snapshot(&state).await)
}

#[derive(Deserialize)]
struct SetContextBody {
    #[serde(rename = "projectDir")]
    project_dir: Option<String>,
    datamodel: Option<String>,
}

async fn api_set_context(
    State(state): State<AppState>,
    Json(body): Json<SetContextBody>,
) -> impl IntoResponse {
    let mut context = state.context.lock().await;
    if let Some(project_dir) = body.project_dir {
        context.project_dir = Some(project_dir);
    }
    if let Some(datamodel) = body.datamodel {
        context.preferred_datamodel = datamodel;
    }
    Json(context_to_json(&context))
}

#[derive(Deserialize)]
struct AiContextQuery {
    format: Option<String>,
    #[serde(rename = "projectDir")]
    project_dir: Option<String>,
}

async fn api_ai_context(
    State(state): State<AppState>,
    Query(query): Query<AiContextQuery>,
) -> Response {
    let snapshot = ai_context_snapshot(&state, query.project_dir).await;
    if matches!(query.format.as_deref(), Some("markdown" | "md")) {
        (
            [(axum::http::header::CONTENT_TYPE, "text/markdown")],
            to_markdown(&snapshot),
        )
            .into_response()
    } else {
        Json(snapshot).into_response()
    }
}

#[derive(Deserialize)]
struct MemoryQuery {
    #[serde(rename = "projectDir")]
    project_dir: Option<String>,
}

async fn api_memory(
    State(state): State<AppState>,
    Query(query): Query<MemoryQuery>,
) -> impl IntoResponse {
    let project_dir = project_dir(&state, query.project_dir).await;
    Json(json!({
        "projectDir": project_dir,
        "memory": load_memory(&project_dir)
    }))
}

#[derive(Deserialize)]
struct RememberBody {
    text: String,
    tags: Option<Vec<String>>,
    path: Option<String>,
    #[serde(rename = "projectDir")]
    project_dir: Option<String>,
    source: Option<String>,
}

async fn api_remember(
    State(state): State<AppState>,
    Json(body): Json<RememberBody>,
) -> impl IntoResponse {
    let project_dir = project_dir(&state, body.project_dir).await;
    match add_memory(
        &project_dir,
        &body.text,
        body.tags.unwrap_or_default(),
        body.path,
        body.source.unwrap_or_else(|| "user".into()),
    ) {
        Ok((memory, entry)) => ok(json!({
            "ok": true,
            "projectDir": project_dir,
            "entry": entry,
            "memory": memory
        })),
        Err(err) => error(StatusCode::BAD_REQUEST, err),
    }
}

#[derive(Deserialize)]
struct MemoryClearBody {
    id: Option<String>,
    #[serde(rename = "projectDir")]
    project_dir: Option<String>,
}

async fn api_memory_clear(
    State(state): State<AppState>,
    Json(body): Json<MemoryClearBody>,
) -> impl IntoResponse {
    let project_dir = project_dir(&state, body.project_dir).await;
    match clear_memory(&project_dir, body.id) {
        Ok(memory) => ok(json!({ "ok": true, "projectDir": project_dir, "memory": memory })),
        Err(err) => error(StatusCode::BAD_REQUEST, err),
    }
}

async fn api_pending(State(state): State<AppState>) -> impl IntoResponse {
    let pushes = state.pending_pushes.lock().await;
    let mut list = pushes.values().cloned().collect::<Vec<_>>();
    list.sort_by(|a, b| b.pushed_at.cmp(&a.pushed_at));
    Json(json!({ "pushes": list }))
}

async fn api_pending_verify(State(state): State<AppState>) -> impl IntoResponse {
    let paths = state
        .pending_pushes
        .lock()
        .await
        .keys()
        .cloned()
        .collect::<Vec<_>>();
    let mut verified = Vec::new();
    for path in paths {
        let result = plugin_command(&state, json!({ "type": "read_source", "path": path })).await;
        let mut pushes = state.pending_pushes.lock().await;
        if let Some(push) = pushes.get_mut(&path) {
            match result {
                Ok(value) => {
                    let source = value.get("source").and_then(Value::as_str).unwrap_or("");
                    let stale = hash_source(source) != push.source_hash;
                    push.stale = Some(stale);
                    push.status = if stale { "stale".into() } else { "live".into() };
                    push.verified_at = Some(now_ms());
                    push.error = None;
                }
                Err(err) => {
                    push.status = "error".into();
                    push.error = Some(err);
                }
            }
            verified.push(json!(push));
        }
    }
    Json(json!({ "verified": verified }))
}

#[derive(Deserialize)]
struct PendingClearBody {
    path: Option<String>,
}

async fn api_pending_clear(
    State(state): State<AppState>,
    Json(body): Json<PendingClearBody>,
) -> impl IntoResponse {
    let mut pushes = state.pending_pushes.lock().await;
    if let Some(path) = body.path {
        pushes.remove(&path);
    } else {
        pushes.clear();
    }
    ok(json!({ "ok": true }))
}

async fn api_plugin_status(State(state): State<AppState>) -> impl IntoResponse {
    Json(plugin_status_json(&state).await)
}

#[derive(Deserialize)]
struct EventsQuery {
    limit: Option<usize>,
    since: Option<u64>,
}

async fn api_plugin_events(
    State(state): State<AppState>,
    Query(query): Query<EventsQuery>,
) -> impl IntoResponse {
    Json(plugin_events_json(&state, query.limit, query.since).await)
}

#[derive(Deserialize)]
struct PluginCallBody {
    command: Value,
}

async fn api_plugin_call(
    State(state): State<AppState>,
    Json(body): Json<PluginCallBody>,
) -> impl IntoResponse {
    match plugin_command(&state, body.command).await {
        Ok(result) => ok(json!({ "ok": true, "result": result })),
        Err(err) => error(StatusCode::SERVICE_UNAVAILABLE, err),
    }
}

async fn api_shutdown() -> impl IntoResponse {
    tokio::spawn(async {
        tokio::time::sleep(Duration::from_millis(100)).await;
        std::process::exit(0);
    });
    ok(json!({ "status": "shutting down" }))
}

async fn plugin_health(State(state): State<AppState>) -> impl IntoResponse {
    let plugin = state.plugin.lock().await;
    Json(json!({
        "running": true,
        "connected": plugin_connected(&plugin),
        "sessionId": plugin.session.as_ref().map(|s| s.id.clone()),
        "queuedEvents": plugin.events.len()
    }))
}

#[derive(Deserialize)]
struct RegisterBody {
    #[serde(rename = "sessionId")]
    session_id: Option<String>,
}

async fn plugin_register(
    State(state): State<AppState>,
    Json(body): Json<RegisterBody>,
) -> impl IntoResponse {
    let id = body
        .session_id
        .unwrap_or_else(|| format!("rs-{}", now_ms()));
    let mut plugin = state.plugin.lock().await;
    if let Some(session) = plugin.session.as_mut().filter(|session| session.id == id) {
        session.last_seen_at = now_ms();
    } else {
        plugin.session = Some(PluginSession {
            id: id.clone(),
            created_at: now_ms(),
            last_seen_at: now_ms(),
            commands: VecDeque::new(),
            pending: HashMap::new(),
        });
    }
    ok(json!({
        "ok": true,
        "sessionId": id,
        "pollIntervalMs": 500,
        "pollTimeoutMs": 10000
    }))
}

#[derive(Deserialize)]
struct PluginReportBody {
    #[serde(rename = "sessionId")]
    session_id: String,
    responses: Option<Vec<Value>>,
    events: Option<Vec<Value>>,
}

async fn plugin_report(
    State(state): State<AppState>,
    Json(body): Json<PluginReportBody>,
) -> impl IntoResponse {
    let mut plugin = state.plugin.lock().await;
    if plugin.session.as_ref().map(|s| s.id.as_str()) != Some(body.session_id.as_str()) {
        return error(StatusCode::BAD_REQUEST, "Invalid or missing session");
    }
    let mut responses_to_resolve = body.responses.unwrap_or_default();
    let mut events_to_record = Vec::new();
    for event in body.events.unwrap_or_default() {
        if event.get("type").and_then(Value::as_str) == Some("command_responses") {
            let responses = event
                .get("responses")
                .and_then(Value::as_array)
                .cloned()
                .unwrap_or_default();
            responses_to_resolve.extend(responses);
        } else {
            events_to_record.push(event);
        }
    }
    if let Some(session) = plugin.session.as_mut() {
        session.last_seen_at = now_ms();
        resolve_plugin_responses(session, responses_to_resolve);
    }
    let mut context_events = Vec::new();
    for event in events_to_record {
        plugin.next_event_id += 1;
        let mut recorded = event;
        if let Some(obj) = recorded.as_object_mut() {
            obj.insert("id".into(), Value::from(plugin.next_event_id));
            obj.insert("time".into(), Value::from(now_ms() as u64));
        }
        context_events.push(recorded.clone());
        if recorded.get("type").and_then(Value::as_str) != Some("context_snapshot") {
            plugin.events.push_back(recorded);
            while plugin.events.len() > 200 {
                plugin.events.pop_front();
            }
        }
    }
    let commands = plugin
        .session
        .as_mut()
        .map(|s| s.commands.drain(..).collect::<Vec<_>>())
        .unwrap_or_default();
    drop(plugin);
    for event in context_events {
        ingest_studio_event(&state, event).await;
    }
    ok(json!({ "ok": true, "commands": commands }))
}

async fn plugin_status(State(state): State<AppState>) -> impl IntoResponse {
    Json(plugin_status_json(&state).await)
}

async fn plugin_events(
    State(state): State<AppState>,
    Query(query): Query<EventsQuery>,
) -> impl IntoResponse {
    Json(plugin_events_json(&state, query.limit, query.since).await)
}

async fn plugin_call(
    State(state): State<AppState>,
    Json(body): Json<PluginCallBody>,
) -> impl IntoResponse {
    match plugin_command(&state, body.command).await {
        Ok(result) => ok(json!({ "ok": true, "result": result })),
        Err(err) => error(StatusCode::SERVICE_UNAVAILABLE, err),
    }
}

fn resolve_plugin_responses(session: &mut PluginSession, responses: Vec<Value>) {
    for response in responses {
        let Some(id) = response.get("id").and_then(Value::as_str) else {
            continue;
        };
        if let Some(sender) = session.pending.remove(id) {
            if let Some(error) = response.get("error") {
                let _ = sender.send(Err(error.to_string()));
            } else {
                let _ = sender.send(Ok(response.get("result").cloned().unwrap_or(Value::Null)));
            }
        }
    }
}

async fn plugin_command(state: &AppState, mut command: Value) -> Result<Value, String> {
    let (rx, id) = {
        let mut plugin = state.plugin.lock().await;
        let session = plugin
            .session
            .as_mut()
            .filter(|s| now_ms() - s.last_seen_at < 60_000)
            .ok_or_else(|| "Studio plugin not connected".to_string())?;
        let id = format!("cmd-{}", now_ms());
        command
            .as_object_mut()
            .ok_or("plugin command must be an object")?
            .insert("id".into(), Value::String(id.clone()));
        let (tx, rx) = oneshot::channel();
        session.pending.insert(id.clone(), tx);
        session.commands.push_back(command);
        (rx, id)
    };
    match tokio::time::timeout(Duration::from_secs(15), rx).await {
        Ok(Ok(result)) => result,
        Ok(Err(_)) => Err("plugin command cancelled".into()),
        Err(_) => {
            let mut plugin = state.plugin.lock().await;
            if let Some(session) = plugin.session.as_mut() {
                session.pending.remove(&id);
            }
            Err("plugin command timed out".into())
        }
    }
}

async fn record_pending_from_args(state: &AppState, args: &Value) {
    let path = args.get("file_path").and_then(Value::as_str);
    let source = args
        .get("edits")
        .and_then(Value::as_array)
        .and_then(|edits| edits.first())
        .and_then(|edit| edit.get("new_string"))
        .and_then(Value::as_str);
    if let (Some(path), Some(source)) = (path, source) {
        state.pending_pushes.lock().await.insert(
            path.to_string(),
            PendingPush {
                path: path.to_string(),
                source_hash: hash_source(source),
                pushed_at: now_ms(),
                status: "pending".into(),
                verified_at: None,
                stale: None,
                error: None,
            },
        );
    }
}

async fn record_operation(
    state: &AppState,
    op: &str,
    target: Option<String>,
    summary: Option<String>,
) {
    let mut context = state.context.lock().await;
    let datamodel = context.preferred_datamodel.clone();
    context.recent_operations.push_front(Operation {
        time: now_ms(),
        op: op.into(),
        target,
        datamodel: Some(datamodel),
        summary,
    });
    while context.recent_operations.len() > 32 {
        context.recent_operations.pop_back();
    }
}

async fn ingest_studio_event(state: &AppState, event: Value) {
    let event_type = event
        .get("type")
        .and_then(Value::as_str)
        .unwrap_or("unknown")
        .to_string();
    let mut context = state.context.lock().await;
    *context
        .studio_event_counts
        .entry(event_type.clone())
        .or_insert(0) += 1;

    if event_type == "context_snapshot" {
        if let Some(snapshot) = event.get("snapshot") {
            context.studio = snapshot.clone();
            context.current_datamodel = snapshot
                .get("mode")
                .and_then(Value::as_str)
                .map(str::to_string);
        }
    } else {
        if !context.studio.is_object() {
            context.studio = json!({});
        }
        let studio = context.studio.as_object_mut().expect("studio object");
        match event_type.as_str() {
            "selection_changed" => {
                studio.insert(
                    "selectionPaths".into(),
                    event.get("paths").cloned().unwrap_or_else(|| json!([])),
                );
            }
            "active_script_changed" => {
                studio.insert(
                    "activeScriptPath".into(),
                    event.get("path").cloned().unwrap_or(Value::Null),
                );
            }
            "mode_changed" => {
                let mode = event.get("mode").cloned().unwrap_or(Value::Null);
                studio.insert("mode".into(), mode.clone());
                context.current_datamodel = mode.as_str().map(str::to_string);
            }
            "hierarchy_changed" => {
                studio.insert("lastHierarchyChange".into(), event.clone());
            }
            "history" => {
                studio.insert("lastHistoryCommit".into(), event.clone());
            }
            _ => {}
        }
    }

    if event_type == "source_changed" {
        if let Some(path) = event.get("path").and_then(Value::as_str) {
            context.recent_scripts.retain(|entry| entry != path);
            context.recent_scripts.push_front(path.to_string());
            while context.recent_scripts.len() > 32 {
                context.recent_scripts.pop_back();
            }
        }
    }
    if event_type == "output" && event.get("level").and_then(Value::as_str) == Some("MessageError")
    {
        context.recent_studio_errors.push_front(event.clone());
        while context.recent_studio_errors.len() > 20 {
            context.recent_studio_errors.pop_back();
        }
    }
    if event_type != "context_snapshot" {
        context.recent_studio_events.push_front(event);
        while context.recent_studio_events.len() > 32 {
            context.recent_studio_events.pop_back();
        }
    }
}

async fn context_snapshot(state: &AppState) -> Value {
    let context = state.context.lock().await;
    context_to_json(&context)
}

fn context_to_json(context: &ContextState) -> Value {
    json!({
        "projectDir": context.project_dir,
        "preferredDatamodel": if context.preferred_datamodel.is_empty() { "Edit" } else { &context.preferred_datamodel },
        "currentDatamodel": context.current_datamodel,
        "recentScripts": context.recent_scripts,
        "recentOperations": context.recent_operations,
        "studio": context.studio,
        "studioEventCounts": context.studio_event_counts,
        "recentStudioEvents": context.recent_studio_events,
        "recentStudioErrors": context.recent_studio_errors,
    })
}

async fn project_dir(state: &AppState, requested: Option<String>) -> String {
    if let Some(requested) = requested {
        return requested;
    }
    if let Some(project_dir) = state.context.lock().await.project_dir.clone() {
        return project_dir;
    }
    std::env::current_dir()
        .unwrap_or_else(|_| PathBuf::from("."))
        .display()
        .to_string()
}

async fn ai_context_snapshot(state: &AppState, requested_project_dir: Option<String>) -> Value {
    let project_dir = project_dir(state, requested_project_dir).await;
    let plugin = state.plugin.lock().await;
    let pending = state
        .pending_pushes
        .lock()
        .await
        .values()
        .cloned()
        .collect::<Vec<_>>();
    json!({
        "generatedAt": now_ms(),
        "projectDir": project_dir,
        "memoryPath": memory_path(&project_dir).display().to_string(),
        "memory": load_memory(&project_dir),
        "context": context_snapshot(state).await,
        "pendingPushes": pending,
        "plugin": {
            "connected": plugin_connected(&plugin),
            "sessionId": plugin.session.as_ref().map(|s| s.id.clone()),
            "lastSeenAt": plugin.session.as_ref().map(|s| s.last_seen_at),
        },
        "recentPluginEvents": plugin.events.iter().cloned().collect::<Vec<_>>()
    })
}

fn to_markdown(snapshot: &Value) -> String {
    let mut out = String::new();
    out.push_str("# Abraxius AI Context\n\n");
    out.push_str(&format!(
        "Generated: {}\n",
        snapshot.get("generatedAt").unwrap_or(&Value::Null)
    ));
    out.push_str(&format!(
        "Project: {}\n\n",
        snapshot
            .get("projectDir")
            .and_then(Value::as_str)
            .unwrap_or("unknown")
    ));
    out.push_str("## Pinned Memory\n");
    let notes = snapshot
        .get("memory")
        .and_then(|m| m.get("notes"))
        .and_then(Value::as_array)
        .cloned()
        .unwrap_or_default();
    if notes.is_empty() {
        out.push_str("- No pinned memory yet.\n");
    } else {
        for note in notes {
            out.push_str("- ");
            out.push_str(note.get("text").and_then(Value::as_str).unwrap_or(""));
            out.push('\n');
        }
    }
    out.push_str("\n## Pending Studio Pushes\n");
    let pushes = snapshot
        .get("pendingPushes")
        .and_then(Value::as_array)
        .cloned()
        .unwrap_or_default();
    if pushes.is_empty() {
        out.push_str("- None.\n");
    } else {
        for push in pushes {
            out.push_str(&format!(
                "- {}: {}\n",
                push.get("path")
                    .and_then(Value::as_str)
                    .unwrap_or("unknown"),
                push.get("status")
                    .and_then(Value::as_str)
                    .unwrap_or("unknown")
            ));
        }
    }
    out
}

fn memory_path(project_dir: &str) -> PathBuf {
    PathBuf::from(project_dir)
        .join(".abraxius")
        .join("memory.json")
}

fn load_memory(project_dir: &str) -> Value {
    let path = memory_path(project_dir);
    std::fs::read_to_string(path)
        .ok()
        .and_then(|text| serde_json::from_str(&text).ok())
        .unwrap_or_else(|| json!({ "version": 1, "updatedAt": null, "notes": [] }))
}

fn add_memory(
    project_dir: &str,
    text: &str,
    tags: Vec<String>,
    path: Option<String>,
    source: String,
) -> Result<(Value, Value), String> {
    if text.trim().is_empty() {
        return Err("Memory text is required".into());
    }
    let mut memory = load_memory(project_dir);
    let entry = json!({
        "id": format!("{}-rs", now_ms()),
        "time": now_ms(),
        "text": text,
        "tags": tags,
        "path": path,
        "source": source
    });
    let notes = memory
        .get_mut("notes")
        .and_then(Value::as_array_mut)
        .ok_or("invalid memory file")?;
    notes.insert(0, entry.clone());
    save_memory(project_dir, &mut memory)?;
    Ok((memory, entry))
}

fn clear_memory(project_dir: &str, id: Option<String>) -> Result<Value, String> {
    let mut memory = load_memory(project_dir);
    if let Some(notes) = memory.get_mut("notes").and_then(Value::as_array_mut) {
        if let Some(id) = id {
            notes.retain(|note| note.get("id").and_then(Value::as_str) != Some(id.as_str()));
        } else {
            notes.clear();
        }
    }
    save_memory(project_dir, &mut memory)?;
    Ok(memory)
}

fn save_memory(project_dir: &str, memory: &mut Value) -> Result<(), String> {
    memory["version"] = Value::from(1);
    memory["updatedAt"] = Value::from(now_ms() as u64);
    let path = memory_path(project_dir);
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent).map_err(|err| err.to_string())?;
    }
    std::fs::write(
        path,
        serde_json::to_string_pretty(memory).map_err(|err| err.to_string())?,
    )
    .map_err(|err| err.to_string())
}

fn plugin_connected(plugin: &PluginState) -> bool {
    plugin
        .session
        .as_ref()
        .map(|s| now_ms() - s.last_seen_at < 60_000)
        .unwrap_or(false)
}

async fn plugin_status_json(state: &AppState) -> Value {
    let plugin = state.plugin.lock().await;
    json!({
        "connected": plugin_connected(&plugin),
        "sessionId": plugin.session.as_ref().map(|s| s.id.clone()),
        "lastSeenAt": plugin.session.as_ref().map(|s| s.last_seen_at),
        "session": plugin.session.as_ref().map(|s| json!({
            "id": s.id,
            "createdAt": s.created_at,
            "lastSeenAt": s.last_seen_at,
            "queuedCommands": s.commands.len(),
            "pendingCommands": s.pending.len(),
            "connected": now_ms() - s.last_seen_at < 60_000
        })),
        "queuedEvents": plugin.events.len()
    })
}

async fn plugin_events_json(state: &AppState, limit: Option<usize>, since: Option<u64>) -> Value {
    let plugin = state.plugin.lock().await;
    let since = since.unwrap_or(0);
    let limit = limit.unwrap_or(50).clamp(1, 200);
    let events = plugin
        .events
        .iter()
        .filter(|event| event.get("id").and_then(Value::as_u64).unwrap_or(0) > since)
        .rev()
        .take(limit)
        .cloned()
        .collect::<Vec<_>>();
    json!({ "events": events, "nextEventId": plugin.next_event_id + 1 })
}

fn hash_source(source: &str) -> String {
    // Lightweight deterministic hash for tracking. Node uses sha256; Rust daemon
    // keeps the same comparison semantics even though the displayed hash differs.
    let mut hash = 0xcbf29ce484222325u64;
    for byte in source.as_bytes() {
        hash ^= *byte as u64;
        hash = hash.wrapping_mul(0x100000001b3);
    }
    format!("{hash:016x}")
}

fn ok(value: Value) -> Response {
    (StatusCode::OK, Json(value)).into_response()
}

fn error(status: StatusCode, message: impl ToString) -> Response {
    (status, Json(json!({ "error": message.to_string() }))).into_response()
}

fn now_ms() -> u128 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis()
}
