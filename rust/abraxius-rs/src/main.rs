use std::env;
use std::fs::{self, OpenOptions};
use std::io::{Read, Write};
use std::net::TcpStream;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::time::Duration;

const API_PORT: u16 = 13470;
const PLUGIN_FILE: &str = "AbraxiusCompanion.lua";
const PLUGIN_INIT: &str = include_str!("../../../plugin/AbraxiusCompanion/init.server.luau");
const PLUGIN_LOGGER: &str = include_str!("../../../plugin/AbraxiusCompanion/Logger.luau");

type Result<T> = std::result::Result<T, String>;

fn main() {
    if let Err(err) = run() {
        eprintln!("Error: {err}");
        std::process::exit(1);
    }
}

fn run() -> Result<()> {
    let mut args = env::args().skip(1).collect::<Vec<_>>();
    let command = if args.is_empty() {
        "help".to_string()
    } else {
        args.remove(0)
    };

    match command.as_str() {
        "help" | "--help" | "-h" => {
            print_usage();
            Ok(())
        }
        "health" | "status" => print_http("GET", "/health", None),
        "tools" => print_http("GET", "/tools", None),
        "state" => print_http("GET", "/state", None),
        "context" => print_http("GET", "/context", None),
        "ai-context" => ai_context(&args),
        "remember" => remember(&args),
        "memory" => memory(&args),
        "call" => call_tool(&args),
        "execute" => execute(&args),
        "pending" => pending(&args),
        "plugin" => plugin(&args),
        "install-plugin" => install_plugin(),
        "start" => start_native_daemon(),
        "start-node" => start_node_daemon(),
        "stop" => print_http("POST", "/shutdown", Some("{}")),
        _ => Err(format!(
            "Unknown command: {command}\nRun `abraxius-rs help`."
        )),
    }
}

fn print_usage() {
    println!(
        r#"Abraxius Rust Extension

Usage:
  abraxius-rs status
  abraxius-rs start
  abraxius-rs start-node
  abraxius-rs stop
  abraxius-rs tools
  abraxius-rs state
  abraxius-rs call <tool> [json]
  abraxius-rs execute <luau>
  abraxius-rs ai-context [--json] [--project <dir>]
  abraxius-rs remember <text> [--tag <tag>] [--path <path>] [--project <dir>]
  abraxius-rs memory [clear [id]] [--project <dir>]
  abraxius-rs pending [verify|clear [path]]
  abraxius-rs plugin [status|events [limit]|selection|state|call <type> [json]]
  abraxius-rs install-plugin

This binary controls the existing Abraxius daemon API and installs the Studio
companion plugin as a single local plugin script."#
    );
}

fn print_http(method: &str, path: &str, body: Option<&str>) -> Result<()> {
    let response = http_request(method, path, body)?;
    if response.status >= 400 {
        return Err(format!("HTTP {}: {}", response.status, response.body));
    }
    println!("{}", response.body);
    Ok(())
}

fn call_tool(args: &[String]) -> Result<()> {
    let name = args
        .first()
        .ok_or("Usage: abraxius-rs call <tool> [json]")?;
    let tool_args = args.get(1).map(String::as_str).unwrap_or("{}");
    let body = format!(
        r#"{{"name":{},"arguments":{}}}"#,
        json_string(name),
        tool_args
    );
    print_http("POST", "/call", Some(&body))
}

fn execute(args: &[String]) -> Result<()> {
    if args.is_empty() {
        return Err("Usage: abraxius-rs execute <luau>".into());
    }
    let code = args.join(" ");
    let body = format!(r#"{{"code":{}}}"#, json_string(&code));
    print_http("POST", "/execute", Some(&body))
}

fn ai_context(args: &[String]) -> Result<()> {
    let opts = parse_options(args);
    let format = if opts.json { "json" } else { "markdown" };
    let mut path = format!("/ai-context?format={format}");
    if let Some(project) = opts.project_dir {
        path.push_str("&projectDir=");
        path.push_str(&url_encode(&project));
    }

    match http_request("GET", &path, None) {
        Ok(response) if response.status < 400 => {
            println!("{}", response.body);
            Ok(())
        }
        _ => {
            let project_dir = env::current_dir()
                .map_err(|err| err.to_string())?
                .to_string_lossy()
                .to_string();
            let memory = read_memory_text(Path::new(&project_dir));
            if opts.json {
                println!(
                    r#"{{"projectDir":{},"offline":true,"memory":{}}}"#,
                    json_string(&project_dir),
                    memory
                );
            } else {
                println!("# Abraxius AI Context\n");
                println!("Project: {project_dir}");
                println!("Daemon: offline");
                println!("\n## Pinned Memory\n");
                println!("{memory}");
            }
            Ok(())
        }
    }
}

fn remember(args: &[String]) -> Result<()> {
    let opts = parse_options(args);
    let text = opts.positionals.join(" ");
    if text.trim().is_empty() {
        return Err("Usage: abraxius-rs remember <text> [--tag <tag>] [--path <path>]".into());
    }
    let tags = opts
        .tags
        .iter()
        .map(|tag| json_string(tag))
        .collect::<Vec<_>>()
        .join(",");
    let mut fields = vec![
        format!(r#""text":{}"#, json_string(&text)),
        format!(r#""tags":[{tags}]"#),
    ];
    if let Some(path) = opts.path {
        fields.push(format!(r#""path":{}"#, json_string(&path)));
    }
    if let Some(project_dir) = opts.project_dir {
        fields.push(format!(r#""projectDir":{}"#, json_string(&project_dir)));
    }
    let body = format!("{{{}}}", fields.join(","));
    print_http("POST", "/memory", Some(&body))
}

fn memory(args: &[String]) -> Result<()> {
    let clear = args.first().is_some_and(|arg| arg == "clear");
    if clear {
        let opts = parse_options(&args[1..]);
        let mut fields = Vec::new();
        if let Some(id) = opts.positionals.first() {
            fields.push(format!(r#""id":{}"#, json_string(id)));
        }
        if let Some(project_dir) = opts.project_dir {
            fields.push(format!(r#""projectDir":{}"#, json_string(&project_dir)));
        }
        let body = format!("{{{}}}", fields.join(","));
        print_http("POST", "/memory/clear", Some(&body))
    } else {
        let opts = parse_options(args);
        let path = opts
            .project_dir
            .map(|project| format!("/memory?projectDir={}", url_encode(&project)))
            .unwrap_or_else(|| "/memory".to_string());
        print_http("GET", &path, None)
    }
}

fn pending(args: &[String]) -> Result<()> {
    match args.first().map(String::as_str) {
        Some("verify") => print_http("POST", "/pending/verify", Some("{}")),
        Some("clear") => {
            let body = args
                .get(1)
                .map(|path| format!(r#"{{"path":{}}}"#, json_string(path)))
                .unwrap_or_else(|| "{}".to_string());
            print_http("POST", "/pending/clear", Some(&body))
        }
        _ => print_http("GET", "/pending", None),
    }
}

fn plugin(args: &[String]) -> Result<()> {
    match args.first().map(String::as_str).unwrap_or("status") {
        "status" => print_http("GET", "/plugin/status", None),
        "events" => {
            let limit = args.get(1).map(String::as_str).unwrap_or("50");
            print_http("GET", &format!("/plugin/events?limit={limit}"), None)
        }
        "selection" => print_http(
            "POST",
            "/plugin/call",
            Some(r#"{"command":{"type":"get_selection"}}"#),
        ),
        "state" => print_http(
            "POST",
            "/plugin/call",
            Some(r#"{"command":{"type":"get_state"}}"#),
        ),
        "inspect" => {
            let path = args.get(1).ok_or("Usage: abraxius plugin inspect <path>")?;
            let body = format!(
                r#"{{"command":{{"type":"get_children","path":{}}}}}"#,
                json_string(path)
            );
            print_http("POST", "/plugin/call", Some(&body))
        }
        "select" => {
            if args.len() < 2 {
                return Err("Usage: abraxius plugin select <path...>".into());
            }
            let paths = args[1..]
                .iter()
                .map(|path| json_string(path))
                .collect::<Vec<_>>()
                .join(",");
            let body = format!(r#"{{"command":{{"type":"set_selection","paths":[{paths}]}}}}"#);
            print_http("POST", "/plugin/call", Some(&body))
        }
        "open" => {
            let path = args
                .get(1)
                .ok_or("Usage: abraxius plugin open <path> [line]")?;
            let line = args
                .get(2)
                .and_then(|line| line.parse::<u32>().ok())
                .unwrap_or(1);
            let body = format!(
                r#"{{"command":{{"type":"open_script","path":{},"line":{line}}}}}"#,
                json_string(path)
            );
            print_http("POST", "/plugin/call", Some(&body))
        }
        "call" => {
            let command_type = args
                .get(1)
                .ok_or("Usage: abraxius-rs plugin call <type> [json]")?;
            let extra = args.get(2).map(String::as_str).unwrap_or("{}");
            let extra_body = extra.trim().trim_start_matches('{').trim_end_matches('}');
            let comma = if extra_body.is_empty() { "" } else { "," };
            let body = format!(
                r#"{{"command":{{"type":{}{}{}}}}}"#,
                json_string(command_type),
                comma,
                extra_body
            );
            print_http("POST", "/plugin/call", Some(&body))
        }
        other => Err(format!("Unknown plugin subcommand: {other}")),
    }
}

fn install_plugin() -> Result<()> {
    let dest_dir = roblox_plugins_dir()?;
    fs::create_dir_all(&dest_dir).map_err(|err| err.to_string())?;

    let legacy = dest_dir.join("AbraxiusCompanion");
    if legacy.is_dir() {
        fs::remove_dir_all(&legacy).map_err(|err| err.to_string())?;
        println!("Removed legacy folder install:\n  {}", legacy.display());
    }

    let dest = dest_dir.join(PLUGIN_FILE);
    let logger = PLUGIN_LOGGER
        .trim_start_matches("--!strict\r\n")
        .trim_start_matches("--!strict\n")
        .trim_end()
        .strip_suffix("return Logger")
        .unwrap_or(PLUGIN_LOGGER)
        .trim();
    let bundled = PLUGIN_INIT.replace("local Logger = require(script.Logger)", logger);
    fs::write(&dest, bundled).map_err(|err| err.to_string())?;
    println!(
        "Installed AbraxiusCompanion plugin to:\n  {}",
        dest.display()
    );
    println!("Restart Roblox Studio to load it.");
    Ok(())
}

fn start_node_daemon() -> Result<()> {
    let repo = repo_root()?;
    let server = repo.join("server.js");
    if !server.exists() {
        return Err(format!("server.js not found at {}", server.display()));
    }
    Command::new("node")
        .arg(server)
        .arg("--daemon")
        .current_dir(repo)
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .spawn()
        .map_err(|err| format!("failed to spawn node daemon: {err}"))?;
    println!("Started Abraxius Node daemon.");
    Ok(())
}

fn start_native_daemon() -> Result<()> {
    if let Ok(response) = http_request("GET", "/health", None) {
        if response.status < 400 {
            println!("Abraxius host is already running.\n{}", response.body);
            return Ok(());
        }
    }

    let current = env::current_exe().map_err(|err| err.to_string())?;
    let file_name = if cfg!(target_os = "windows") {
        "abraxius-daemon.exe"
    } else {
        "abraxius-daemon"
    };
    let daemon = current
        .parent()
        .ok_or("could not resolve executable directory")?
        .join(file_name);
    if !daemon.exists() {
        return Err(format!(
            "Native host not found at {}. Build both binaries with `cargo build --release`.",
            daemon.display()
        ));
    }

    let log_dir = app_data_dir()?;
    fs::create_dir_all(&log_dir).map_err(|err| err.to_string())?;
    let log_path = log_dir.join("abraxius-host.log");
    let stdout = OpenOptions::new()
        .create(true)
        .append(true)
        .open(&log_path)
        .map_err(|err| err.to_string())?;
    let stderr = stdout.try_clone().map_err(|err| err.to_string())?;
    let mut command = Command::new(&daemon);
    command
        .stdin(Stdio::null())
        .stdout(Stdio::from(stdout))
        .stderr(Stdio::from(stderr));
    #[cfg(target_os = "windows")]
    {
        use std::os::windows::process::CommandExt;
        command.creation_flags(0x08000000);
    }
    command
        .spawn()
        .map_err(|err| format!("failed to start native host: {err}"))?;

    for _ in 0..50 {
        std::thread::sleep(Duration::from_millis(100));
        if let Ok(response) = http_request("GET", "/health", None) {
            if response.status < 400 {
                println!("Started Abraxius native host.\n{}", response.body);
                println!("Log: {}", log_path.display());
                return Ok(());
            }
        }
    }
    Err(format!(
        "Native host did not become ready. Check {}",
        log_path.display()
    ))
}

fn app_data_dir() -> Result<PathBuf> {
    if cfg!(target_os = "windows") {
        let base = env::var("LOCALAPPDATA")
            .or_else(|_| env::var("USERPROFILE").map(|home| format!("{home}\\AppData\\Local")))
            .map_err(|_| "LOCALAPPDATA is not set".to_string())?;
        Ok(PathBuf::from(base).join("Abraxius"))
    } else {
        let home = env::var("HOME").map_err(|_| "HOME is not set".to_string())?;
        Ok(PathBuf::from(home)
            .join(".local")
            .join("share")
            .join("abraxius"))
    }
}

struct HttpResponse {
    status: u16,
    body: String,
}

fn http_request(method: &str, path: &str, body: Option<&str>) -> Result<HttpResponse> {
    let mut stream = TcpStream::connect(("127.0.0.1", API_PORT)).map_err(|err| {
        format!("Cannot connect to Abraxius daemon on localhost:{API_PORT}: {err}")
    })?;
    stream
        .set_read_timeout(Some(Duration::from_secs(30)))
        .map_err(|err| err.to_string())?;
    let body = body.unwrap_or("");
    let request = format!(
        "{method} {path} HTTP/1.1\r\nHost: localhost:{API_PORT}\r\nContent-Type: application/json\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{}",
        body.len(),
        body
    );
    stream
        .write_all(request.as_bytes())
        .map_err(|err| err.to_string())?;

    let mut raw = String::new();
    stream
        .read_to_string(&mut raw)
        .map_err(|err| err.to_string())?;
    let (head, body) = raw
        .split_once("\r\n\r\n")
        .ok_or_else(|| "invalid HTTP response".to_string())?;
    let status = head
        .lines()
        .next()
        .and_then(|line| line.split_whitespace().nth(1))
        .and_then(|code| code.parse::<u16>().ok())
        .ok_or_else(|| "invalid HTTP status".to_string())?;
    Ok(HttpResponse {
        status,
        body: body.to_string(),
    })
}

struct Options {
    positionals: Vec<String>,
    tags: Vec<String>,
    path: Option<String>,
    project_dir: Option<String>,
    json: bool,
}

fn parse_options(args: &[String]) -> Options {
    let mut options = Options {
        positionals: Vec::new(),
        tags: Vec::new(),
        path: None,
        project_dir: None,
        json: false,
    };
    let mut i = 0;
    while i < args.len() {
        match args[i].as_str() {
            "--tag" => {
                if let Some(value) = args.get(i + 1) {
                    options.tags.push(value.clone());
                    i += 1;
                }
            }
            "--path" => {
                if let Some(value) = args.get(i + 1) {
                    options.path = Some(value.clone());
                    i += 1;
                }
            }
            "--project" => {
                if let Some(value) = args.get(i + 1) {
                    options.project_dir = Some(value.clone());
                    i += 1;
                }
            }
            "--json" => options.json = true,
            value => options.positionals.push(value.to_string()),
        }
        i += 1;
    }
    options
}

fn read_memory_text(project_dir: &Path) -> String {
    let path = project_dir.join(".abraxius").join("memory.json");
    fs::read_to_string(path).unwrap_or_else(|_| "- No pinned memory yet.".to_string())
}

fn json_string(value: &str) -> String {
    let mut out = String::from("\"");
    for ch in value.chars() {
        match ch {
            '"' => out.push_str("\\\""),
            '\\' => out.push_str("\\\\"),
            '\n' => out.push_str("\\n"),
            '\r' => out.push_str("\\r"),
            '\t' => out.push_str("\\t"),
            c if c.is_control() => out.push_str(&format!("\\u{:04x}", c as u32)),
            c => out.push(c),
        }
    }
    out.push('"');
    out
}

fn url_encode(value: &str) -> String {
    let mut out = String::new();
    for byte in value.bytes() {
        if byte.is_ascii_alphanumeric() || matches!(byte, b'-' | b'_' | b'.' | b'~') {
            out.push(byte as char);
        } else {
            out.push_str(&format!("%{byte:02X}"));
        }
    }
    out
}

fn repo_root() -> Result<PathBuf> {
    let manifest_dir = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
    manifest_dir
        .parent()
        .and_then(Path::parent)
        .map(Path::to_path_buf)
        .ok_or_else(|| "could not resolve repo root".to_string())
}

fn roblox_plugins_dir() -> Result<PathBuf> {
    if cfg!(target_os = "windows") {
        let local_app_data = env::var("LOCALAPPDATA")
            .or_else(|_| env::var("USERPROFILE").map(|home| format!("{home}\\AppData\\Local")))
            .map_err(|_| "LOCALAPPDATA is not set".to_string())?;
        Ok(PathBuf::from(local_app_data).join("Roblox").join("Plugins"))
    } else {
        let home = env::var("HOME").map_err(|_| "HOME is not set".to_string())?;
        Ok(PathBuf::from(home)
            .join("Documents")
            .join("Roblox")
            .join("Plugins"))
    }
}
