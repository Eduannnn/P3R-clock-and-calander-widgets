use crate::Result;
use chrono::{DateTime, Duration, NaiveDate, NaiveDateTime, Offset, TimeZone, Utc};
use chrono_tz::Tz;
use ical::{parser::ical::component::IcalEvent, property::Property, IcalParser};
use rrule::{RRule, RRuleSet, Unvalidated};
use std::{
    collections::{BTreeMap, BTreeSet},
    io::BufReader,
};
use windows_timezones::WindowsTimezone;

#[derive(Clone)]
struct Moment {
    local: NaiveDateTime,
    zone: Tz,
    all_day: bool,
}

pub fn timezone(name: &str) -> Result<Tz> {
    name.trim_matches('"')
        .parse::<Tz>()
        .or_else(|_| {
            name.trim_matches('"')
                .parse::<WindowsTimezone>()
                .map(Tz::from)
        })
        .map_err(|_| "Unrecognized calendar timezone")
}

fn parameter<'a>(property: &'a Property, key: &str) -> Option<&'a str> {
    property
        .params
        .as_ref()?
        .iter()
        .find(|(name, _)| name.eq_ignore_ascii_case(key))?
        .1
        .first()
        .map(String::as_str)
}

fn property<'a>(properties: &'a [Property], name: &str) -> Option<&'a Property> {
    properties
        .iter()
        .find(|property| property.name.eq_ignore_ascii_case(name))
}

fn value<'a>(properties: &'a [Property], name: &str) -> Option<&'a str> {
    property(properties, name)?.value.as_deref()
}

fn moment(property: &Property, text: &str, default_zone: Tz) -> Result<Moment> {
    let all_day = text.len() == 8;
    let zone = if text.ends_with('Z') {
        chrono_tz::UTC
    } else if let Some(name) = parameter(property, "TZID") {
        timezone(name)?
    } else {
        default_zone
    };
    let local = if all_day {
        NaiveDate::parse_from_str(text, "%Y%m%d")
            .map_err(|_| "Invalid calendar date")?
            .and_hms_opt(0, 0, 0)
            .ok_or("Invalid calendar date")?
    } else {
        NaiveDateTime::parse_from_str(text.trim_end_matches('Z'), "%Y%m%dT%H%M%S")
            .map_err(|_| "Invalid calendar time")?
    };
    Ok(Moment {
        local,
        zone,
        all_day,
    })
}

fn resolve(zone: Tz, local: NaiveDateTime) -> Result<DateTime<Utc>> {
    if let Some(date) = zone.from_local_datetime(&local).earliest() {
        return Ok(date.with_timezone(&Utc));
    }
    // RFC 5545: nonexistent spring-forward times use the offset before the gap.
    for minutes in 1..=180 {
        if let Some(before) = zone
            .from_local_datetime(&(local - Duration::minutes(minutes)))
            .earliest()
        {
            let offset = before.offset().fix().local_minus_utc();
            return Ok((local - Duration::seconds(i64::from(offset))).and_utc());
        }
    }
    Err("Could not resolve calendar time")
}

fn duration(text: &str) -> Result<Duration> {
    let text = text.strip_prefix('P').ok_or("Invalid event duration")?;
    let mut seconds = 0_i64;
    let mut number = String::new();
    let mut time = false;
    let mut parts = 0;
    for ch in text.chars() {
        if ch == 'T' && number.is_empty() {
            time = true;
            continue;
        }
        if ch.is_ascii_digit() {
            number.push(ch);
            continue;
        }
        let multiplier = match (ch, time) {
            ('W', false) => 604800,
            ('D', false) => 86400,
            ('H', true) => 3600,
            ('M', true) => 60,
            ('S', true) => 1,
            _ => return Err("Invalid event duration"),
        };
        let amount = number
            .parse::<i64>()
            .map_err(|_| "Invalid event duration")?;
        seconds = seconds
            .checked_add(
                amount
                    .checked_mul(multiplier)
                    .ok_or("Event duration too large")?,
            )
            .ok_or("Event duration too large")?;
        number.clear();
        parts += 1;
    }
    if !number.is_empty() || parts == 0 {
        return Err("Invalid event duration");
    }
    Duration::try_seconds(seconds).ok_or("Event duration too large")
}

struct Event {
    properties: Vec<Property>,
    start: Moment,
    duration: Duration,
    recurrence_id: Option<i64>,
    cancelled: bool,
    revision: (i64, String),
}

impl Event {
    fn parse(event: IcalEvent, default_zone: Tz) -> Result<Self> {
        let properties = event.properties;
        let cancelled =
            value(&properties, "STATUS").is_some_and(|s| s.eq_ignore_ascii_case("CANCELLED"));
        let beginning = property(&properties, "DTSTART")
            .or_else(|| {
                if cancelled {
                    property(&properties, "RECURRENCE-ID")
                } else {
                    None
                }
            })
            .ok_or("Event has no start date")?;
        let start = moment(
            beginning,
            beginning.value.as_deref().ok_or("Invalid event start")?,
            default_zone,
        )?;
        let duration = if let Some(ending) = property(&properties, "DTEND") {
            let end = moment(
                ending,
                ending.value.as_deref().ok_or("Invalid event end")?,
                default_zone,
            )?;
            if end.zone == start.zone {
                end.local - start.local
            } else {
                resolve(end.zone, end.local)? - resolve(start.zone, start.local)?
            }
        } else if let Some(text) = value(&properties, "DURATION") {
            duration(text)?
        } else if start.all_day {
            Duration::days(1)
        } else {
            Duration::zero()
        };
        if duration < Duration::zero() {
            return Err("Event ends before it starts");
        }
        let recurrence_id = if let Some(id) = property(&properties, "RECURRENCE-ID") {
            let original = moment(
                id,
                id.value.as_deref().ok_or("Invalid recurrence ID")?,
                default_zone,
            )?;
            Some(resolve(original.zone, original.local)?.timestamp())
        } else {
            None
        };
        let revision = (
            value(&properties, "SEQUENCE")
                .unwrap_or("0")
                .parse()
                .unwrap_or(0),
            value(&properties, "LAST-MODIFIED")
                .or_else(|| value(&properties, "DTSTAMP"))
                .unwrap_or("")
                .to_owned(),
        );
        Ok(Self {
            properties,
            start,
            duration,
            recurrence_id,
            cancelled,
            revision,
        })
    }

    fn occurrences(&self, first: DateTime<Utc>, stop: DateTime<Utc>) -> Result<Vec<DateTime<Utc>>> {
        let zone = rrule::Tz::from(self.start.zone);
        let start = resolve(self.start.zone, self.start.local)?.with_timezone(&zone);
        let mut set = RRuleSet::new(start).rdate(start);
        for property in &self.properties {
            let text = property.value.as_deref().unwrap_or("");
            match property.name.as_str() {
                "RRULE" | "EXRULE" => {
                    let rule = text
                        .parse::<RRule<Unvalidated>>()
                        .map_err(|_| "Invalid recurrence rule")?
                        .validate(start)
                        .map_err(|_| "Invalid recurrence rule")?;
                    set = if property.name == "RRULE" {
                        set.rrule(rule)
                    } else {
                        set.exrule(rule)
                    };
                }
                "RDATE" | "EXDATE" => {
                    for text in text.split(',') {
                        let date = moment(property, text, self.start.zone)?;
                        let date = resolve(date.zone, date.local)?.with_timezone(&zone);
                        set = if property.name == "RDATE" {
                            set.rdate(date)
                        } else {
                            set.exdate(date)
                        };
                    }
                }
                _ => {}
            }
        }
        // Include long events starting before the requested range, with room for DST changes.
        let lookback = self.duration + Duration::days(2);
        let result = set
            .after((first - lookback).with_timezone(&zone))
            .before(stop.with_timezone(&zone))
            .all(50000);
        if result.limited {
            return Err("Calendar recurrence limit exceeded");
        }
        Ok(result
            .dates
            .into_iter()
            .map(|date| date.with_timezone(&Utc))
            .collect())
    }
}

pub fn validate(data: &[u8]) -> Result<()> {
    let calendars = IcalParser::new(BufReader::new(data))
        .collect::<std::result::Result<Vec<_>, _>>()
        .map_err(|_| "Invalid ICS calendar")?;
    if calendars.is_empty() {
        return Err("Expected an ICS calendar");
    }
    Ok(())
}

fn mark(
    result: &mut BTreeMap<String, bool>,
    event: &Event,
    beginning: DateTime<Utc>,
    first: DateTime<Utc>,
    stop: DateTime<Utc>,
    local_zone: Tz,
) -> Result<()> {
    let ending = resolve(
        event.start.zone,
        beginning.with_timezone(&event.start.zone).naive_local() + event.duration,
    )?;
    if beginning == ending {
        if first <= beginning && beginning < stop {
            result.insert(
                beginning
                    .with_timezone(&local_zone)
                    .date_naive()
                    .to_string(),
                true,
            );
        }
        return Ok(());
    }
    let beginning = beginning.max(first);
    let ending = ending.min(stop);
    if ending <= beginning {
        return Ok(());
    }
    let mut day = beginning.with_timezone(&local_zone).date_naive();
    let last = (ending - Duration::microseconds(1))
        .with_timezone(&local_zone)
        .date_naive();
    while day <= last {
        result.insert(day.to_string(), true);
        day = day.succ_opt().ok_or("Calendar date out of range")?;
    }
    Ok(())
}

pub fn meeting_dates(
    data: &[u8],
    start: NaiveDate,
    end: NaiveDate,
    local_zone: Tz,
) -> Result<BTreeMap<String, bool>> {
    let first = resolve(
        local_zone,
        start.and_hms_opt(0, 0, 0).ok_or("Invalid range start")?,
    )?;
    let stop = resolve(
        local_zone,
        end.and_hms_opt(0, 0, 0).ok_or("Invalid range end")?,
    )?;
    let mut result = BTreeMap::new();
    let mut found = false;
    for calendar in IcalParser::new(BufReader::new(data)) {
        let calendar = calendar.map_err(|_| "Invalid ICS calendar")?;
        found = true;
        let default_zone = value(&calendar.properties, "X-WR-TIMEZONE")
            .map(timezone)
            .transpose()?
            .unwrap_or(local_zone);
        let mut groups: BTreeMap<String, Vec<Event>> = BTreeMap::new();
        for (index, event) in calendar.events.into_iter().enumerate() {
            let uid = value(&event.properties, "UID")
                .map(str::to_owned)
                .unwrap_or_else(|| format!("anonymous-{index}"));
            groups
                .entry(uid)
                .or_default()
                .push(Event::parse(event, default_zone)?);
        }
        for events in groups.values() {
            let mut overrides = BTreeMap::new();
            for event in events.iter().filter(|event| event.recurrence_id.is_some()) {
                let key = event.recurrence_id.ok_or("Invalid recurrence ID")?;
                if overrides
                    .get(&key)
                    .is_none_or(|old: &&Event| old.revision <= event.revision)
                {
                    overrides.insert(key, event);
                }
            }
            let excluded: BTreeSet<_> = overrides.keys().copied().collect();
            if let Some(master) = events
                .iter()
                .filter(|event| event.recurrence_id.is_none())
                .max_by_key(|event| &event.revision)
            {
                if !master.cancelled {
                    for beginning in master.occurrences(first, stop)? {
                        if !excluded.contains(&beginning.timestamp()) {
                            mark(&mut result, master, beginning, first, stop, local_zone)?;
                        }
                    }
                }
            }
            for event in overrides.values().filter(|event| !event.cancelled) {
                mark(
                    &mut result,
                    event,
                    resolve(event.start.zone, event.start.local)?,
                    first,
                    stop,
                    local_zone,
                )?;
            }
        }
    }
    if !found {
        return Err("Expected an ICS calendar");
    }
    Ok(result)
}
