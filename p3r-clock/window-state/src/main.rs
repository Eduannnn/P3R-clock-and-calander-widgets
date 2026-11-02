use std::{
    error::Error,
    io::{self, Write},
};
use zbus::blocking::{connection::Builder, Proxy};

struct WindowLayoutState;
#[zbus::interface(name = "org.p3r.ClockWindowState")]
impl WindowLayoutState {
    fn update(&self, payload: &str) -> zbus::fdo::Result<()> {
        let windows: Vec<serde_json::Value> = serde_json::from_str(payload)
            .map_err(|_| zbus::fdo::Error::InvalidArgs("Expected window bounds".into()))?;
        let mut output = io::stdout().lock();
        writeln!(output, "{}", serde_json::json!({"windows": windows}))
            .and_then(|()| output.flush())
            .map_err(|_| zbus::fdo::Error::Failed("Clock output closed".into()))
    }
}
fn main() -> Result<(), Box<dyn Error>> {
    let mut signals = signal_hook::iterator::Signals::new([
        signal_hook::consts::SIGTERM,
        signal_hook::consts::SIGINT,
    ])?;
    let service = format!("org.p3r.ClockWindowState.p{}", std::process::id());
    let plugin = format!("p3r-clock-window-state-{}", std::process::id());
    let connection = Builder::session()?
        .name(service.as_str())?
        .serve_at("/Layout", WindowLayoutState)?
        .build()?;
    let scripting = Proxy::new(
        &connection,
        "org.kde.KWin",
        "/Scripting",
        "org.kde.kwin.Scripting",
    )?;
    let mut script = tempfile::Builder::new()
        .prefix("p3r-clock-")
        .suffix(".js")
        .tempfile_in(std::env::var_os("XDG_RUNTIME_DIR").ok_or("XDG_RUNTIME_DIR is missing")?)?;
    let source = include_str!("../watch-layout.js")
        .replace("SERVICE_NAME", &serde_json::to_string(&service)?);
    script.write_all(source.as_bytes())?;
    let id: i32 = scripting.call(
        "loadScript",
        &(script.path().to_string_lossy().as_ref(), plugin.as_str()),
    )?;
    if id < 0 {
        return Err("KWin could not load the clock monitor".into());
    }
    let path = format!("/Scripting/Script{id}");
    let controller = Proxy::new(
        &connection,
        "org.kde.KWin",
        path.as_str(),
        "org.kde.kwin.Script",
    )?;
    if let Err(error) = controller.call::<_, _, ()>("run", &()) {
        let _: Result<bool, _> = scripting.call("unloadScript", &(plugin.as_str(),));
        return Err(error.into());
    }
    signals.forever().next();
    let _: bool = scripting.call("unloadScript", &(plugin.as_str(),))?;
    Ok(())
}
