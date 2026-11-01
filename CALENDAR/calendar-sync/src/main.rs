mod calendar;
mod storage;

use chrono::{Duration, NaiveDate};
use serde::Serialize;
use std::{collections::BTreeMap, env, path::PathBuf};

type Result<T> = std::result::Result<T, &'static str>;

#[derive(Serialize)]
struct SyncResult {
    #[serde(rename = "meetingDates")]
    meeting_dates: BTreeMap<String, bool>,
    stale: bool,
}

fn run() -> Result<()> {
    let mut args: Vec<_> = env::args().skip(1).collect();
    let mut config_path = storage::config_path()?;
    if args.first().is_some_and(|arg| arg == "--config") {
        if args.len() < 3 {
            return Err("Missing configuration path or command");
        }
        config_path = PathBuf::from(args.remove(1));
        args.remove(0);
    }
    match args.first().map(String::as_str) {
        Some("configure") => {
            let input =
                rpassword::prompt_password("Paste your Outlook ICS subscription URL (hidden): ")
                    .map_err(|_| "Could not read calendar subscription URL")?;
            let url = storage::validate_url(&input)?;
            storage::load_feed(&url, true)?;
            let settings = storage::Settings {
                ics_url: url,
                helper: Some(env::current_exe().map_err(|_| "Could not locate calendar helper")?),
                timezone: None,
            };
            storage::save_settings(&config_path, &settings)?;
            println!("Calendar configured. The widgets will pick it up within ten seconds.");
        }
        Some("migrate") => {
            let mut settings = storage::read_settings(&config_path)?;
            settings.helper =
                Some(env::current_exe().map_err(|_| "Could not locate calendar helper")?);
            storage::save_settings(&config_path, &settings)?;
            println!("Existing calendar subscription migrated to the Rust helper.");
        }
        Some("sync") => {
            if args.len() != 5 || args[1] != "--start" || args[3] != "--end" {
                return Err("Usage: p3r-calendar-sync sync --start YYYY-MM-DD --end YYYY-MM-DD");
            }
            let start = NaiveDate::parse_from_str(&args[2], "%Y-%m-%d")
                .map_err(|_| "Invalid start date")?;
            let end =
                NaiveDate::parse_from_str(&args[4], "%Y-%m-%d").map_err(|_| "Invalid end date")?;
            if end <= start || end - start > Duration::days(370) {
                return Err("Request between 1 and 370 days");
            }
            let settings = storage::read_settings(&config_path)?;
            let name = settings
                .timezone
                .or_else(|| env::var("TZ").ok())
                .or_else(|| iana_time_zone::get_timezone().ok())
                .ok_or("Could not detect local timezone")?;
            let zone = calendar::timezone(&name)?;
            let url = storage::validate_url(&settings.ics_url)?;
            let (data, stale) = storage::load_feed(&url, false)?;
            let result = SyncResult {
                meeting_dates: calendar::meeting_dates(&data, start, end, zone)?,
                stale,
            };
            println!(
                "{}",
                serde_json::to_string(&result).map_err(|_| "Could not encode meeting dates")?
            );
        }
        _ => return Err(
            "Usage: p3r-calendar-sync {configure|migrate|sync --start YYYY-MM-DD --end YYYY-MM-DD}",
        ),
    }
    Ok(())
}

fn main() {
    if let Err(message) = run() {
        // Errors are deliberately static: never expose subscription URLs or event contents.
        eprintln!("Calendar sync failed: {message}");
        std::process::exit(1);
    }
}

#[cfg(test)]
mod tests;
