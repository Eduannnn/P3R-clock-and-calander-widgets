use crate::{calendar, Result};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::{
    env, fs,
    io::{Read, Write},
    os::unix::fs::PermissionsExt,
    path::{Path, PathBuf},
    time::Duration,
};
use tempfile::NamedTempFile;

#[derive(Deserialize, Serialize)]
pub struct Settings {
    pub ics_url: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub helper: Option<PathBuf>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub timezone: Option<String>,
}

pub fn config_path() -> Result<PathBuf> {
    Ok(base_dir("XDG_CONFIG_HOME", ".config")?.join("p3r-widgets/calendar.json"))
}

fn base_dir(variable: &str, fallback: &str) -> Result<PathBuf> {
    match env::var_os(variable) {
        Some(path) if !path.is_empty() => Ok(PathBuf::from(path)),
        _ => Ok(
            PathBuf::from(env::var_os("HOME").ok_or("Home directory unavailable")?).join(fallback),
        ),
    }
}

pub fn private_write(path: &Path, data: &[u8]) -> Result<()> {
    let parent = path.parent().ok_or("Invalid private file path")?;
    fs::create_dir_all(parent).map_err(|_| "Could not create private directory")?;
    fs::set_permissions(parent, fs::Permissions::from_mode(0o700))
        .map_err(|_| "Could not protect private directory")?;
    let mut file = NamedTempFile::new_in(parent).map_err(|_| "Could not create private file")?;
    file.as_file()
        .set_permissions(fs::Permissions::from_mode(0o600))
        .map_err(|_| "Could not protect private file")?;
    file.write_all(data)
        .map_err(|_| "Could not write private file")?;
    file.persist(path)
        .map_err(|_| "Could not save private file")?;
    Ok(())
}

pub fn read_settings(path: &Path) -> Result<Settings> {
    let data = fs::read(path).map_err(|_| "Calendar is not configured; run setup-calendar.sh")?;
    serde_json::from_slice(&data).map_err(|_| "Invalid private calendar configuration")
}

pub fn save_settings(path: &Path, settings: &Settings) -> Result<()> {
    let data =
        serde_json::to_vec_pretty(settings).map_err(|_| "Could not encode private settings")?;
    private_write(path, &data)
}

pub fn validate_url(value: &str) -> Result<String> {
    let value = value.trim().replacen("webcal://", "https://", 1);
    let url = url::Url::parse(&value).map_err(|_| "Invalid calendar subscription URL")?;
    if url.scheme() != "https"
        || url.host_str().is_none()
        || !url.username().is_empty()
        || url.password().is_some()
    {
        return Err("Use an HTTPS calendar subscription link");
    }
    Ok(url.to_string())
}

pub fn cache_path(url: &str) -> Result<PathBuf> {
    Ok(base_dir("XDG_CACHE_HOME", ".cache")?
        .join("p3r-widgets")
        .join(format!("calendar-{:x}.ics", Sha256::digest(url.as_bytes()))))
}

fn download(url: &str) -> Result<Vec<u8>> {
    const MAX_BYTES: u64 = 20 * 1024 * 1024;
    let agent = ureq::AgentBuilder::new()
        .https_only(true)
        .timeout(Duration::from_secs(20))
        .build();
    let response = agent
        .get(url)
        .set("User-Agent", "p3r-widgets-calendar/1.0")
        .call()
        .map_err(|_| "Could not download calendar")?;
    let mut data = Vec::new();
    response
        .into_reader()
        .take(MAX_BYTES + 1)
        .read_to_end(&mut data)
        .map_err(|_| "Could not read calendar")?;
    if data.len() as u64 > MAX_BYTES {
        return Err("Calendar feed is too large");
    }
    calendar::validate(&data)?;
    Ok(data)
}

// Kept separate so offline and invalid-response behavior can be tested without a network.
pub fn cached_feed(
    cache: &Path,
    force: bool,
    fetch: impl FnOnce() -> Result<Vec<u8>>,
) -> Result<(Vec<u8>, bool)> {
    let fresh = fs::metadata(cache)
        .and_then(|metadata| metadata.modified())
        .ok()
        .and_then(|modified| modified.elapsed().ok())
        .is_some_and(|age| age < Duration::from_secs(300));
    if !force && fresh {
        return Ok((
            fs::read(cache).map_err(|_| "Could not read calendar cache")?,
            false,
        ));
    }
    match fetch().and_then(|data| {
        calendar::validate(&data)?;
        Ok(data)
    }) {
        Ok(data) => {
            private_write(cache, &data)?;
            Ok((data, false))
        }
        Err(_) => fs::read(cache)
            .map(|data| (data, true))
            .map_err(|_| "Could not download calendar; check the subscription link and network"),
    }
}

pub fn load_feed(url: &str, force: bool) -> Result<(Vec<u8>, bool)> {
    cached_feed(&cache_path(url)?, force, || download(url))
}
