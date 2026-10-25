// Velocity - build.rs
// Constantin Clerc (c22dev) - 0.1
fn main() {
    if let Ok(args) = std::env::var("DEP_NXHOST_LINK_ARGS") {
        for a in args.split_whitespace() {
            println!("cargo:rustc-link-arg-bins={a}");
        }
    }
}
