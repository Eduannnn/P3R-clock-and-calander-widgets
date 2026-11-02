use super::{calendar, storage};
use chrono::NaiveDate;
use std::{collections::BTreeSet, fs, os::unix::fs::PermissionsExt};

fn event(body: &str) -> String {
    format!("BEGIN:VEVENT\r\nUID:test\r\n{body}\r\nEND:VEVENT")
}

fn feed(events: &[String]) -> Vec<u8> {
    format!(
        "BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//P3R Tests//EN\r\n{}\r\nEND:VCALENDAR\r\n",
        events.join("\r\n")
    )
    .into_bytes()
}

fn dates(events: &[String]) -> BTreeSet<String> {
    calendar::meeting_dates(
        &feed(events),
        NaiveDate::from_ymd_opt(2026, 10, 19).unwrap(),
        NaiveDate::from_ymd_opt(2026, 11, 5).unwrap(),
        chrono_tz::Europe::London,
    )
    .unwrap()
    .into_keys()
    .collect()
}

fn expected(days: &[&str]) -> BTreeSet<String> {
    days.iter().map(|s| s.to_string()).collect()
}

#[test]
fn weekly_and_excluded_occurrence() {
    assert_eq!(dates(&[event("DTSTART:20261020T090000Z\r\nDTEND:20261020T100000Z\r\nRRULE:FREQ=WEEKLY;COUNT=3\r\nEXDATE:20261027T090000Z")]),
        expected(&["2026-10-20", "2026-11-03"]));
}

#[test]
fn moved_occurrence_replaces_original() {
    assert_eq!(dates(&[
        event("DTSTART:20261020T090000Z\r\nDTEND:20261020T100000Z\r\nRRULE:FREQ=WEEKLY;COUNT=3"),
        event("RECURRENCE-ID:20261027T090000Z\r\nDTSTART:20261028T100000Z\r\nDTEND:20261028T110000Z")]),
        expected(&["2026-10-20", "2026-10-28", "2026-11-03"]));
}

#[test]
fn cancelled_recurring_occurrence() {
    assert_eq!(dates(&[
        event("DTSTART:20261020T090000Z\r\nDTEND:20261020T100000Z\r\nRRULE:FREQ=WEEKLY;COUNT=3"),
        event("RECURRENCE-ID:20261027T090000Z\r\nDTSTART:20261027T090000Z\r\nDTEND:20261027T100000Z\r\nSTATUS:CANCELLED")]),
        expected(&["2026-10-20", "2026-11-03"]));
}

#[test]
fn all_day_end_is_exclusive() {
    assert_eq!(
        dates(&[event(
            "DTSTART;VALUE=DATE:20261026\r\nDTEND;VALUE=DATE:20261028"
        )]),
        expected(&["2026-10-26", "2026-10-27"])
    );
}

#[test]
fn midnight_end_does_not_mark_next_day() {
    assert_eq!(
        dates(&[event("DTSTART:20261026T233000Z\r\nDTEND:20261027T000000Z")]),
        expected(&["2026-10-26"])
    );
}

#[test]
fn overnight_marks_both_days() {
    assert_eq!(
        dates(&[event("DTSTART:20261026T233000Z\r\nDTEND:20261027T003000Z")]),
        expected(&["2026-10-26", "2026-10-27"])
    );
}

#[test]
fn recurring_local_times_survive_dst_change() {
    assert_eq!(dates(&[event("DTSTART;TZID=Europe/London:20261020T003000\r\nDTEND;TZID=Europe/London:20261020T013000\r\nRRULE:FREQ=WEEKLY;COUNT=3")]),
        expected(&["2026-10-20", "2026-10-27", "2026-11-03"]));
}

#[test]
fn outlook_windows_timezone_uses_dst() {
    assert_eq!(dates(&[event("DTSTART;TZID=GMT Standard Time:20261020T003000\r\nDTEND;TZID=GMT Standard Time:20261020T013000\r\nRRULE:FREQ=WEEKLY;COUNT=3")]),
        expected(&["2026-10-20", "2026-10-27", "2026-11-03"]));
}

#[test]
fn cancelled_event_and_empty_calendar() {
    assert!(dates(&[event(
        "DTSTART:20261026T090000Z\r\nDTEND:20261026T100000Z\r\nSTATUS:CANCELLED"
    )])
    .is_empty());
    assert!(dates(&[]).is_empty());
}

#[test]
fn range_end_is_exclusive() {
    assert!(dates(&[event("DTSTART:20261105T090000Z\r\nDTEND:20261105T100000Z")]).is_empty());
}

#[test]
fn floating_time_and_zero_duration() {
    assert_eq!(
        dates(&[event("DTSTART:20261026T090000\r\nDTEND:20261026T090000")]),
        expected(&["2026-10-26"])
    );
}

#[test]
fn duration_and_additional_recurrence_dates() {
    assert_eq!(
        dates(&[event(
            "DTSTART:20261026T233000Z\r\nDURATION:PT1H\r\nRDATE:20261028T233000Z"
        )]),
        expected(&["2026-10-26", "2026-10-27", "2026-10-28", "2026-10-29"])
    );
}

#[test]
fn private_files_have_owner_only_permissions() {
    let directory = tempfile::tempdir().unwrap();
    let path = directory.path().join("private/calendar.json");
    storage::private_write(&path, b"{}").unwrap();
    assert_eq!(
        fs::metadata(&path).unwrap().permissions().mode() & 0o777,
        0o600
    );
    assert_eq!(
        fs::metadata(path.parent().unwrap())
            .unwrap()
            .permissions()
            .mode()
            & 0o777,
        0o700
    );
}

#[test]
fn failed_download_uses_cache_and_redacts_private_url() {
    let directory = tempfile::tempdir().unwrap();
    let cache = directory.path().join("calendar.ics");
    let data = feed(&[]);
    storage::private_write(&cache, &data).unwrap();
    assert_eq!(
        storage::cached_feed(&cache, true, || Err(
            "https://example.test/private-feed-token"
        ))
        .unwrap(),
        (data, true)
    );
    fs::remove_file(&cache).unwrap();
    let error = storage::cached_feed(&cache, true, || {
        Err("https://example.test/private-feed-token")
    })
    .unwrap_err();
    assert!(!error.contains("private-feed-token"));
}

#[test]
fn malformed_download_does_not_replace_valid_cache() {
    let directory = tempfile::tempdir().unwrap();
    let cache = directory.path().join("calendar.ics");
    let data = feed(&[]);
    storage::private_write(&cache, &data).unwrap();
    let (actual, stale) =
        storage::cached_feed(&cache, true, || Ok(b"<html>Sign in</html>".to_vec())).unwrap();
    assert_eq!(actual, data);
    assert!(stale);
    assert_eq!(fs::read(cache).unwrap(), data);
}

#[test]
fn legacy_python_config_can_be_read_without_keeping_python() {
    let directory = tempfile::tempdir().unwrap();
    let path = directory.path().join("calendar.json");
    fs::write(
        &path,
        br#"{"ics_url":"https://example.test/calendar.ics","python":"/old/python"}"#,
    )
    .unwrap();
    let mut settings = storage::read_settings(&path).unwrap();
    settings.helper = Some("/new/p3r-calendar-sync".into());
    storage::save_settings(&path, &settings).unwrap();
    let text = fs::read_to_string(path).unwrap();
    assert!(text.contains("p3r-calendar-sync"));
    assert!(!text.contains("python"));
}
