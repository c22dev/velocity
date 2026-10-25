// Velocity - main.rs
// Constantin Clerc (c22dev) - 0.1
use anyhow::Result;
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
}

fn main() -> Result<()> {
    let args = Args::parse();
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
    nxhost::start(nxhost::Config {
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
        precompile: false,
        convert_movies: false,
        fill_layouts: false,
    })?;
    gfx::run_app("Velocity", 1280.0, 720.0)
}
