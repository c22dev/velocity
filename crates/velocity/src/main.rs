// Velocity - main.rs
// Constantin Clerc (c22dev) - 0.1
use clap::Parser;
use nxhost::gfx;
use std::path::PathBuf;

#[derive(Parser)]
#[command(about = "Run Sonic Colors: Ultimate natively")]
struct Args {
    #[arg(long, default_value = "work/v109/patched")]
    patched: PathBuf,
    #[arg(long, default_value = "work/v109/exefs/main.npdm")]
    npdm: PathBuf,
    #[arg(long, default_value = "prod.keys")]
    keys: PathBuf,
    #[arg(long, default_value = "base.nsp")]
    base: PathBuf,
    #[arg(long, default_value = "upd.nsp")]
    update: PathBuf,
    #[arg(long, default_value = "work/save")]
    save: PathBuf,
    #[arg(long, default_value = "work/sdmc")]
    sdmc: PathBuf,
    #[arg(long, default_value = "system")]
    system: PathBuf,
    #[arg(long, default_value = "Firmware")]
    firmware: PathBuf,
    #[arg(long)]
    dlc: Vec<PathBuf>,
    #[arg(long)]
    precompile: bool,
}

fn keymap() {
    use nxhost::input::*;
    set_keymap(&[
        ("space", B),
        ("shift", Y),
        ("c", Y),
        ("e", A),
        ("f", X),
        ("q", L),
        ("r", R),
        ("1", ZL),
        ("3", ZR),
        ("enter", A),
        ("escape", B),
        ("backspace", B),
        ("tab", PLUS),
        ("=", PLUS),
        ("-", MINUS),
        ("left", LEFT),
        ("up", UP),
        ("right", RIGHT),
        ("down", DOWN),
    ]);
}

fn config(args: Args) -> nxhost::Config {
    nxhost::Config {
        patched: args.patched,
        npdm: args.npdm,
        keys: args.keys,
        base: args.base,
        update: args.update,
        save: args.save,
        sdmc: args.sdmc,
        system: args.system,
        firmware: args.firmware,
        dlc: args.dlc,
        modules: ["main", "subsdk2", "subsdk3"].map(String::from).to_vec(),
        nvn_sdk: Some("subsdk2".into()),
        movies: true,
        hle: Vec::new(),
        precompile: args.precompile,
        convert_movies: false,
        fill_layouts: false,
    }
}

#[cfg(target_os = "macos")]
fn main() -> anyhow::Result<()> {
    keymap();
    nxhost::start(config(Args::parse()))?;
    gfx::run_app("Velocity", 1280.0, 720.0)
}

#[cfg(target_os = "ios")]
fn main() {
    let home = PathBuf::from(std::env::var_os("HOME").expect("HOME"));
    let docs = home.join("Documents");
    let _ = std::env::set_current_dir(&docs);
    let _ = std::fs::create_dir_all("work");
    let _ = std::fs::rename("work/velocity.log", "work/velocity.prev.log");
    if let Ok(log) = std::fs::File::create("work/velocity.log") {
        use std::os::fd::AsRawFd;
        unsafe { libc::dup2(log.as_raw_fd(), 2) };
    }
    let bundle = std::env::current_exe().ok().and_then(|e| e.parent().map(PathBuf::from)).unwrap_or_default();
    let mut env: Vec<(String, String)> = vec![
        ("NX_NO_SCHED".into(), "1".into()),
        ("NX_SHADER_CACHE".into(), bundle.join("shaders").display().to_string()),
        ("NX_PIPELINE_LIST".into(), bundle.join("shaders/pipelines.tsv").display().to_string()),
    ];
    for line in std::fs::read_to_string("env.txt").unwrap_or_default().lines() {
        if let Some((k, v)) = line.trim().split_once('=').filter(|(k, _)| !k.is_empty() && !k.starts_with('#')) {
            env.push((k.trim().into(), v.trim().into()));
        }
    }
    for (k, v) in env {
        unsafe { std::env::set_var(k, v) };
    }
    eprintln!("[velocity] iOS: files in {}, bundle {}", docs.display(), bundle.display());
    let modules = bundle.join("modules");
    let mut args = Args::parse_from([
        "velocity".into(),
        "--patched".into(),
        modules.display().to_string(),
        "--npdm".into(),
        modules.join("main.npdm").display().to_string(),
        "--update".into(),
        "update.nsp".into(),
    ]);
    keymap();
    gfx::run_app("Velocity", move || {
        apply_launcher_settings();
        let missing: Vec<&str> = ["prod.keys", "base.nsp", "update.nsp"].into_iter().filter(|f| !std::path::Path::new(f).exists()).collect();
        anyhow::ensure!(
            missing.is_empty(),
            "Missing {}.\n\nCopy prod.keys, base.nsp, the update .nsp (and optionally the Firmware folder) into this app's folder: Finder → your iPhone or iPad → Files → Velocity, or the Files app → On My iPhone → Velocity.",
            missing.join(", ")
        );
        args.dlc = std::fs::read_dir(".")
            .into_iter()
            .flatten()
            .flatten()
            .map(|e| e.path())
            .filter(|p| p.file_name().and_then(|n| n.to_str()).is_some_and(|n| n.starts_with("dlc") && n.ends_with(".nsp")))
            .collect();
        nxhost::start(config(args))
    })
}

#[cfg(target_os = "ios")]
fn apply_launcher_settings() {
    let config = std::fs::read_to_string("config.json").unwrap_or_default();
    let field = |key: &str| {
        let rest = config.split(&format!("\"{key}\"")).nth(1)?;
        let rest = rest.trim_start().strip_prefix(':')?.trim_start();
        Some(rest.trim_start_matches('"').split([',', '\n', '}', '"']).next()?.trim().to_string())
    };
    let set = |k: &str, v: &str| unsafe { std::env::set_var(k, v) };
    if field("prewarm_pipelines").as_deref() != Some("false") {
        set("NX_PREWARM", "1");
    }
    if field("background_compile").as_deref() == Some("false") {
        set("NX_SYNC_SHADERS", "1");
    }
    if field("rumble").as_deref() == Some("false") {
        set("NX_RUMBLE", "0");
    }
    if field("spatial_audio").as_deref() == Some("false") {
        set("NX_SPATIAL", "0");
    }
    if field("handheld").as_deref() != Some("false") {
        set("NX_HANDHELD", "1");
    }
}
