#!/usr/bin/env python3
"""Bidirectional Redmine/Radicale sync adapter.

This sidecar uses only Python's standard library. It runs entirely inside the
Redmine pod and periodically synchronizes Redmine tasks with start/due dates
and VEVENT/VTODO items in the dedicated Radicale collection. It has no HTTP
server, public route, capture endpoint, or MCP implementation.
"""

from __future__ import annotations

import base64
import datetime as dt
import hashlib
import http.client
import json
import os
import re
import sqlite3
import ssl
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from concurrent.futures import ThreadPoolExecutor
from typing import Any


REDMINE_URL = os.environ.get("REDMINE_URL", "http://redmine:3000").rstrip("/")
REDMINE_PROJECT = os.environ.get("REDMINE_PROJECT", "inbox")
REDMINE_API_KEY = os.environ.get("REDMINE_API_KEY", "")
RADICALE_URL = os.environ.get("RADICALE_URL", "http://radicale:5232").rstrip("/")
RADICALE_TLS_SERVER_NAME = os.environ.get("RADICALE_TLS_SERVER_NAME", "").strip()
RADICALE_CALENDAR = os.environ.get("RADICALE_CALENDAR", "redmine-tasks")
RADICALE_USERNAME = os.environ.get("RADICALE_USERNAME", "")
RADICALE_PASSWORD = os.environ.get("RADICALE_PASSWORD", "")
STATE_DB = os.environ.get("STATE_DB", "/data/state.sqlite3")
REDMINE_CLOSED_STATUS_ID = int(os.environ.get("REDMINE_CLOSED_STATUS_ID", "5"))
CALENDAR_DELETE_CLOSE = os.environ.get("CALENDAR_DELETE_CLOSE", "true").lower() in {"1", "true", "yes"}
SYNC_INTERVAL_SECONDS = max(int(os.environ.get("SYNC_INTERVAL_SECONDS", "300")), 1)
SYNC_LOCK = threading.Lock()
CALENDAR_CACHE = {}  # href -> (ETag, raw iCalendar bytes); valid only in this process.
# Legacy DAV blocks are removed when a description is next synchronized.
LEGACY_METADATA_START = "----- Redmine metadata (read-only) -----"
LEGACY_METADATA_END = "----- End Redmine metadata -----"
METADATA_START = "<!-- METADATA"
METADATA_END = "-->"
METADATA_BLOCK = re.compile(r"^<!-- METADATA[ \t]*\n.*?^-->[ \t]*$", re.MULTILINE | re.DOTALL)


def json_response(handler: BaseHTTPRequestHandler, status: int, payload: Any) -> None:
    body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    handler.send_response(status)
    handler.send_header("Content-Type", "application/json; charset=utf-8")
    handler.send_header("Content-Length", str(len(body)))
    handler.end_headers()
    handler.wfile.write(body)


def read_json(handler: BaseHTTPRequestHandler) -> dict[str, Any]:
    length = int(handler.headers.get("Content-Length", "0"))
    if length <= 0 or length > 1024 * 1024:
        raise ValueError("request body must be between 1 byte and 1 MiB")
    value = json.loads(handler.rfile.read(length))
    if not isinstance(value, dict):
        raise ValueError("request body must be a JSON object")
    return value


def http_json(
    url: str,
    method: str = "GET",
    payload: dict[str, Any] | None = None,
    headers: dict[str, str] | None = None,
) -> Any:
    request_headers = {"Accept": "application/json"}
    request_headers.update(headers or {})
    data = None
    if payload is not None:
        data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        request_headers["Content-Type"] = "application/json"
    request = urllib.request.Request(url, data=data, method=method, headers=request_headers)
    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            raw = response.read()
            if not raw:
                return None
            return json.loads(raw.decode("utf-8"))
    except urllib.error.HTTPError as error:
        detail = error.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"upstream returned HTTP {error.code}: {detail[:500]}") from error
    except urllib.error.URLError as error:
        raise RuntimeError(f"upstream unavailable: {error.reason}") from error


def redmine_headers() -> dict[str, str]:
    if not REDMINE_API_KEY:
        raise RuntimeError("REDMINE_API_KEY is not configured")
    return {"X-Redmine-API-Key": REDMINE_API_KEY}


def redmine_request(path: str, method: str = "GET", payload: dict[str, Any] | None = None) -> Any:
    return http_json(f"{REDMINE_URL}{path}", method, payload, redmine_headers())


def make_subject(text: str, title: str | None) -> str:
    if title and title.strip():
        return title.strip()[:255]
    first_line = next((line.strip() for line in text.splitlines() if line.strip()), "Inbox capture")
    return first_line[:255]


def create_issue(item: dict[str, Any]) -> dict[str, Any]:
    text = str(item.get("text", item.get("description", ""))).strip()
    if not text and not str(item.get("title", "")).strip():
        raise ValueError("text or title is required")
    issue = {
        "project_id": item.get("project") or REDMINE_PROJECT,
        "subject": make_subject(text, item.get("title")),
        "description": text,
    }
    for field in ("start_date", "due_date"):
        value = item.get(field)
        if value:
            try:
                dt.date.fromisoformat(str(value))
            except ValueError as error:
                raise ValueError(f"{field} must use YYYY-MM-DD") from error
            issue[field] = str(value)
    if item.get("status_id") is not None:
        issue["status_id"] = int(item["status_id"])
    result = redmine_request("/issues.json", "POST", {"issue": issue})
    return result.get("issue", result)


def update_issue(issue_id: int, fields: dict[str, Any]) -> dict[str, Any]:
    allowed = {"subject", "description", "start_date", "due_date", "status_id"}
    payload = {key: value for key, value in fields.items() if key in allowed}
    result = redmine_request(f"/issues/{int(issue_id)}.json", "PUT", {"issue": payload})
    if result is None:
        # Redmine returns HTTP 204 with an empty body after a successful update.
        return {"id": int(issue_id), **payload}
    return result.get("issue", result)


def issue_is_closed(issue):
    status = issue.get("status") or {}
    status_id = status.get("id") if isinstance(status, dict) else None
    if status_id is None:
        status_id = issue.get("status_id")
    return (
        (isinstance(status, dict) and bool(status.get("is_closed")))
        or str(status_id) == str(REDMINE_CLOSED_STATUS_ID)
        or bool(issue.get("closed_on"))
    )


def close_issue(issue_id: int, clear_dates: bool = False) -> dict[str, Any]:
    fields = {"status_id": REDMINE_CLOSED_STATUS_ID}
    if clear_dates:
        fields.update({"start_date": None, "due_date": None})
    return update_issue(issue_id, fields)


def get_issues(limit: int = 100) -> list[dict[str, Any]]:
    page_size = min(max(limit, 1), 100)
    issues = []
    offset = 0
    while True:
        query = urllib.parse.urlencode({
            "project_id": REDMINE_PROJECT,
            "status_id": "*",
            "limit": page_size,
            "offset": offset,
        })
        result = redmine_request(f"/issues.json?{query}")
        page = result.get("issues", [])
        issues.extend(page)
        offset += len(page)
        total_count = result.get("total_count")
        if not page or (total_count is not None and offset >= total_count) or len(page) < page_size:
            return issues


def search_issues(query: str, limit: int = 25) -> list[dict[str, Any]]:
    if not query.strip():
        return []
    params = urllib.parse.urlencode({"q": query, "issues": 1, "limit": min(max(limit, 1), 100)})
    result = redmine_request(f"/search.json?{params}")
    return result.get("results", result.get("issues", []))


def get_issue(issue_id: int) -> dict[str, Any]:
    result = redmine_request(f"/issues/{int(issue_id)}.json")
    return result.get("issue", result)


def database():
    parent = os.path.dirname(STATE_DB)
    if parent:
        os.makedirs(parent, exist_ok=True)
    connection = sqlite3.connect(STATE_DB)
    connection.execute("""CREATE TABLE IF NOT EXISTS event_map (
        uid TEXT PRIMARY KEY,
        href TEXT NOT NULL,
        etag TEXT,
        redmine_id INTEGER,
        content_hash TEXT NOT NULL,
        last_seen INTEGER NOT NULL,
        date_hash TEXT,
        pending_close INTEGER NOT NULL DEFAULT 0
    )""")
    columns = {row[1] for row in connection.execute("PRAGMA table_info(event_map)")}
    if "date_hash" not in columns:
        connection.execute("ALTER TABLE event_map ADD COLUMN date_hash TEXT")
    if "pending_close" not in columns:
        connection.execute("ALTER TABLE event_map ADD COLUMN pending_close INTEGER NOT NULL DEFAULT 0")
    connection.commit()
    return connection


def state_rows(connection):
    rows = connection.execute(
        "SELECT uid, href, etag, redmine_id, content_hash, last_seen, date_hash, pending_close FROM event_map"
    ).fetchall()
    return {
        row[0]: {
            "uid": row[0],
            "href": row[1],
            "etag": row[2],
            "redmine_id": row[3],
            "content_hash": row[4],
            "last_seen": row[5],
            "date_hash": row[6],
            "pending_close": bool(row[7]),
        }
        for row in rows
    }


def save_state(connection, event, redmine_id, redmine_updated_on=None, pending_close=False):
    last_seen = redmine_updated_on if redmine_updated_on is not None else int(time.time())
    connection.execute("""INSERT INTO event_map(uid, href, etag, redmine_id, content_hash, last_seen, date_hash, pending_close)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(uid) DO UPDATE SET href=excluded.href, etag=excluded.etag,
        redmine_id=excluded.redmine_id, content_hash=excluded.content_hash,
        last_seen=excluded.last_seen, date_hash=excluded.date_hash,
        pending_close=excluded.pending_close""", (
        event["uid"], event["href"], event.get("etag"), redmine_id,
        calendar_item_hash(event), last_seen, calendar_date_hash(event), int(pending_close),
    ))
    connection.commit()


def delete_state(connection, uid):
    connection.execute("DELETE FROM event_map WHERE uid = ?", (uid,))
    connection.commit()


def unescape_ical(value):
    return value.replace("\\n", "\n").replace("\\N", "\n").replace("\\,", ",").replace("\\;", ";").replace("\\\\", "\\")


def ical_prop(lines, name):
    for line in lines:
        if ":" not in line:
            continue
        head, value = line.split(":", 1)
        parts = head.split(";")
        if parts[0].upper() == name.upper():
            return unescape_ical(value), any(part.upper() == "VALUE=DATE" for part in parts[1:])
    return None, False


def ical_prop_line(lines, name):
    for line in lines:
        if ":" not in line:
            continue
        head, value = line.split(":", 1)
        if head.split(";", 1)[0].upper() == name.upper():
            return head, unescape_ical(value)
    return None, None


def ical_datetime_info(header, value):
    if not header or not value or len(value) <= 8 or value[8:9].upper() != "T":
        return None
    if parse_ical_date(value) is None:
        return None
    params = [param for param in header.split(";")[1:] if param.upper() != "VALUE=DATE"]
    return {"time": value[8:], "params": params}


def format_ical_date_property(name, value, timing=None, exclusive_end=False):
    if timing:
        params = "".join(f";{param}" for param in timing.get("params", []))
        return f"{name}{params}:{value.strftime('%Y%m%d')}{timing['time']}"
    day = value + dt.timedelta(days=1) if exclusive_end else value
    return f"{name};VALUE=DATE:{day.strftime('%Y%m%d')}"


def parse_ical_date(value):
    if not value or len(value) < 8 or not value[:8].isdigit():
        return None
    try:
        return dt.date.fromisoformat(f"{value[:4]}-{value[4:6]}-{value[6:8]}")
    except ValueError:
        return None


def parse_redmine_date(value):
    if not value:
        return None
    if isinstance(value, dt.datetime):
        return value.date()
    if isinstance(value, dt.date):
        return value
    try:
        return dt.date.fromisoformat(str(value)[:10])
    except ValueError:
        return None


def parse_redmine_timestamp(value):
    if not value:
        return None
    try:
        parsed = dt.datetime.fromisoformat(str(value).replace("Z", "+00:00"))
        if parsed.tzinfo is None:
            parsed = parsed.replace(tzinfo=dt.timezone.utc)
        return int(parsed.timestamp())
    except ValueError:
        return None


def strip_redmine_status_prefix(summary):
    if not summary or not summary.startswith("["):
        return summary
    end = summary.find("]")
    if end <= 1 or end + 1 >= len(summary) or not summary[end + 1].isspace():
        return summary
    return summary[end + 1:].lstrip()


def normalize_description(description):
    return str(description or "").replace("\r\n", "\n").replace("\r", "\n").rstrip()


def calendar_item_hash(event):
    fields = {
        "kind": event.get("kind"),
        "summary": event.get("summary", ""),
        "description": strip_metadata(event.get("description")),
        "start_date": event.get("start_date"),
        "due_date": event.get("due_date"),
        "start_timing": event.get("start_timing"),
        "end_timing": event.get("end_timing"),
        "status": str(event.get("status") or "").upper(),
    }
    payload = json.dumps(fields, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return "semantic:" + hashlib.sha256(payload.encode("utf-8")).hexdigest()


def calendar_date_hash(event):
    fields = {
        "start_date": event.get("start_date"),
        "due_date": event.get("due_date"),
    }
    payload = json.dumps(fields, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def calendar_dates_changed(item, mapping):
    previous_date_hash = mapping.get("date_hash")
    return previous_date_hash is not None and calendar_date_hash(item) != previous_date_hash


def strip_metadata(description):
    """Keep only user text; never mirror either side's generated metadata."""
    text = normalize_description(description)
    while match := METADATA_BLOCK.search(text):
        before = text[:match.start()].rstrip()
        after = text[match.end():].strip()
        text = "\n\n".join(part for part in (before, after) if part)
    while (start := text.find(LEGACY_METADATA_START)) >= 0:
        end = text.find(LEGACY_METADATA_END, start)
        before = text[:start].rstrip()
        after = text[end + len(LEGACY_METADATA_END):].strip() if end >= 0 else ""
        text = "\n\n".join(part for part in (before, after) if part)
    return text


def metadata_value(value):
    value = "Not set" if value is None or value == "" else str(value)
    return " ".join(value.replace("--", "- -").split())


def with_metadata(description, entries):
    content = strip_metadata(description)
    block = "\n".join((METADATA_START, *(f"  {entry}" for entry in entries), METADATA_END))
    return "\n\n".join(part for part in (content, block) if part)


def redmine_description(item):
    entries = [
        f"Calendar UID: {metadata_value(item.get('uid'))}",
        f"Calendar type: {metadata_value(item.get('kind'))}",
    ]
    if item.get("kind") == "VTODO":
        entries.extend(
            f"Recurrence: {metadata_value(prop)}" for prop in item.get("recurrence", [])
        )
        entries.extend(
            f"Reminder {index}: {metadata_value(' | '.join(alarm)) if alarm else 'VALARM'}"
            for index, alarm in enumerate(item.get("reminders", []), start=1)
        )
    return with_metadata(item.get("description"), entries)


def vtodo_schedule(lines):
    """Read task schedule details; timezone RRULEs are outside VTODO."""
    recurrence = []
    reminders = []
    in_todo = False
    alarm = None
    for line in lines:
        if line == "BEGIN:VTODO":
            in_todo = True
            continue
        if line == "END:VTODO":
            in_todo = False
            continue
        if not in_todo:
            continue
        if line == "BEGIN:VALARM":
            alarm = []
            continue
        if line == "END:VALARM" and alarm is not None:
            reminders.append(alarm)
            alarm = None
            continue
        if ":" not in line:
            continue
        name = line.split(":", 1)[0].split(";", 1)[0].upper()
        if alarm is not None:
            if name in {"TRIGGER", "ACTION", "DESCRIPTION", "SUMMARY", "REPEAT", "DURATION"}:
                alarm.append(line)
        elif name in {"RRULE", "RDATE", "EXDATE", "RECURRENCE-ID"}:
            recurrence.append(line)
    recurring = any(
        prop.split(":", 1)[0].split(";", 1)[0].upper() in {"RRULE", "RDATE", "RECURRENCE-ID"}
        for prop in recurrence
    )
    return recurring, recurrence, reminders


def parse_calendar_item(raw, href, etag):
    text = raw.decode("utf-8", errors="replace").replace("\r\n", "\n").replace("\r", "\n")
    lines = []
    for line in text.split("\n"):
        if line.startswith((" ", "\t")) and lines:
            lines[-1] += line[1:]
        else:
            lines.append(line)
    begin = next((i for i, line in enumerate(lines) if line in {"BEGIN:VEVENT", "BEGIN:VTODO"}), None)
    if begin is None:
        return None
    kind = "VTODO" if lines[begin] == "BEGIN:VTODO" else "VEVENT"
    end = next((i for i in range(begin + 1, len(lines)) if lines[i] == f"END:{kind}"), len(lines))
    component = []
    nested = 0
    for line in lines[begin + 1:end]:
        if line.startswith("BEGIN:"):
            nested += 1
        elif line.startswith("END:"):
            nested -= 1
        elif not nested:
            component.append(line)
    uid, _ = ical_prop(component, "UID")
    if not uid:
        return None
    start_value, _ = ical_prop(component, "DTSTART")
    due_value, due_is_date = ical_prop(component, "DUE")
    end_value, end_is_date = ical_prop(component, "DTEND")
    start_header, start_raw = ical_prop_line(component, "DTSTART")
    start_timing = ical_datetime_info(start_header, start_raw)
    if kind == "VTODO":
        end_header, end_raw = ical_prop_line(component, "DUE")
    else:
        end_header, end_raw = ical_prop_line(component, "DTEND")
    end_timing = ical_datetime_info(end_header, end_raw)
    start = parse_ical_date(start_value)
    due = parse_ical_date(due_value)
    if kind == "VEVENT":
        due = due or parse_ical_date(end_value)
        if due and end_value and (end_is_date or due_is_date):
            due -= dt.timedelta(days=1)
    summary, _ = ical_prop(component, "SUMMARY")
    description, _ = ical_prop(component, "DESCRIPTION")
    status, _ = ical_prop(component, "STATUS")
    completed_at, _ = ical_prop(component, "COMPLETED")
    if kind == "VTODO" and not status and parse_ical_date(completed_at):
        # Older syncs could remove STATUS while leaving the historical completion time.
        status = "COMPLETED"
    linked_id, _ = ical_prop(component, "X-REDMINE-ISSUE-ID")
    redmine_id = int(linked_id) if linked_id and linked_id.isdigit() else None
    recurring, recurrence, reminders = (
        vtodo_schedule(lines) if kind == "VTODO" else (False, [], [])
    )
    summary = summary or "Calendar task"
    calendar_summary = summary
    if redmine_id:
        summary = strip_redmine_status_prefix(summary)
    return {
        "uid": uid, "href": href, "etag": etag, "raw": raw, "kind": kind,
        "summary": summary[:255], "calendar_summary": calendar_summary,
        "description": strip_metadata(description or ""),
        "calendar_description": normalize_description(description),
        "completed_at": completed_at,
        "start_date": start.isoformat() if start else None,
        "due_date": due.isoformat() if due else (start.isoformat() if start and kind == "VEVENT" else None),
        "start_timing": start_timing,
        "end_timing": end_timing,
        "status": (status or "").upper(),
        "redmine_id": redmine_id,
        "recurring": recurring,
        "recurrence": recurrence,
        "reminders": reminders,
    }


class _RadicaleHTTPSConnection(http.client.HTTPSConnection):
    def __init__(self, host, *, server_hostname, **kwargs):
        self._radicale_server_hostname = server_hostname
        super().__init__(host, **kwargs)

    def connect(self):
        http.client.HTTPConnection.connect(self)
        self.sock = self._context.wrap_socket(self.sock, server_hostname=self._radicale_server_hostname)


class _RadicaleHTTPSHandler(urllib.request.HTTPSHandler):
    def __init__(self, server_hostname):
        self.server_hostname = server_hostname
        super().__init__()

    def https_open(self, request):
        def connection(host, **kwargs):
            return _RadicaleHTTPSConnection(host, server_hostname=self.server_hostname, **kwargs)

        return self.do_open(connection, request, context=self._context)


def radicale_raw(url, method, body=None, content_type=None, extra_headers=None):
    if not RADICALE_USERNAME or not RADICALE_PASSWORD:
        raise RuntimeError("Radicale credentials are not configured")
    credentials = base64.b64encode(f"{RADICALE_USERNAME}:{RADICALE_PASSWORD}".encode()).decode()
    headers = {"Authorization": f"Basic {credentials}"}
    if content_type:
        headers["Content-Type"] = content_type
    headers.update(extra_headers or {})
    parsed_url = urllib.parse.urlsplit(url)
    use_radicale_tls_name = parsed_url.scheme == "https" and RADICALE_TLS_SERVER_NAME
    if use_radicale_tls_name:
        headers["Host"] = RADICALE_TLS_SERVER_NAME
    request = urllib.request.Request(url, data=body, method=method, headers=headers)
    opener = (
        urllib.request.build_opener(_RadicaleHTTPSHandler(RADICALE_TLS_SERVER_NAME))
        if use_radicale_tls_name
        else None
    )
    try:
        open_request = opener.open if opener else urllib.request.urlopen
        with open_request(request, timeout=20) as response:
            return response.status, dict(response.headers), response.read()
    except urllib.error.HTTPError as error:
        if method == "MKCOL" and error.code in (405, 409):
            return error.code, dict(error.headers), b""
        detail = error.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"Radicale returned HTTP {error.code}: {detail[:500]}") from error


def bidirectional_calendar_url():
    user = urllib.parse.quote(RADICALE_USERNAME, safe="")
    calendar = urllib.parse.quote(RADICALE_CALENDAR, safe="")
    return f"{RADICALE_URL}/{user}/{calendar}".rstrip("/")


def list_calendar_items():
    collection = bidirectional_calendar_url()
    body = b"""<?xml version="1.0" encoding="utf-8"?><D:propfind xmlns:D="DAV:"><D:prop><D:getetag /></D:prop></D:propfind>"""
    try:
        _, _, response_body = radicale_raw(collection + "/", "PROPFIND", body, "application/xml; charset=utf-8", {"Depth": "1"})
    except RuntimeError as error:
        if not str(error).startswith("Radicale returned HTTP 404:"):
            raise
        radicale_raw(collection + "/", "MKCOL", content_type="application/xml")
        _, _, response_body = radicale_raw(collection + "/", "PROPFIND", body, "application/xml; charset=utf-8", {"Depth": "1"})
    root = ET.fromstring(response_body)
    entries = []
    for response in root.findall("{DAV:}response"):
        href_node = response.find("{DAV:}href")
        if href_node is None or not href_node.text or not href_node.text.endswith(".ics"):
            continue
        href = urllib.parse.urljoin(collection + "/", href_node.text)
        etag_node = response.find(".//{DAV:}getetag")
        etag = etag_node.text.strip('"') if etag_node is not None and etag_node.text else None
        entries.append((href, etag))

    missing = [entry for entry in entries if not entry[1] or CALENDAR_CACHE.get(entry[0], (None,))[0] != entry[1]]

    def fetch(entry):
        href, etag = entry
        _, headers, raw = radicale_raw(href, "GET", extra_headers={"Accept": "text/calendar"})
        return href, (headers.get("ETag") or etag or "").strip('"') or None, raw

    if missing:
        with ThreadPoolExecutor(max_workers=min(6, len(missing))) as executor:
            for href, etag, raw in executor.map(fetch, missing):
                CALENDAR_CACHE[href] = (etag, raw)
    seen = {href for href, _ in entries}
    for href in set(CALENDAR_CACHE) - seen:
        CALENDAR_CACHE.pop(href, None)
    items = []
    for href, etag in entries:
        cached_etag, raw = CALENDAR_CACHE[href]
        item = parse_calendar_item(raw, href, etag or cached_etag)
        if item:
            items.append(item)
    return items


def patch_vtodo(raw, properties, date_properties=None, clear_completed=False):
    """Update the VTODO without dropping recurrence, alarms, or timezone data."""
    text = raw.decode("utf-8", errors="replace").replace("\r\n", "\n").replace("\r", "\n")
    lines = []
    for line in text.split("\n"):
        if line.startswith((" ", "\t")) and lines:
            lines[-1] += line[1:]
        else:
            lines.append(line)
    begin = lines.index("BEGIN:VTODO")
    end = lines.index("END:VTODO", begin + 1)
    body = []
    nested = 0
    for line in lines[begin + 1:end]:
        if line.startswith("BEGIN:"):
            nested += 1
        if not nested and ":" in line:
            name = line.split(":", 1)[0].split(";", 1)[0].upper()
            if name in properties or (date_properties is not None and name in {
                "DTSTART", "DUE", "DTEND", "DURATION"
            }):
                continue
            if clear_completed and name == "COMPLETED":
                # A reopened issue must not be closed again by a stale DAV timestamp.
                continue
            if name == "STATUS" and line.upper() == "STATUS:COMPLETED":
                # A reopened Redmine issue must not stay completed in Evolution.
                continue
        body.append(line)
        if line.startswith("END:"):
            nested -= 1
    additions = list(properties.values())
    if date_properties is not None:
        additions.extend(date_properties)
    insert_at = next((i for i, line in enumerate(body) if line.startswith("BEGIN:")), len(body))
    body[insert_at:insert_at] = additions
    return ("\r\n".join(lines[:begin + 1] + body + lines[end:]).rstrip("\r\n") + "\r\n").encode()


def bidirectional_ical(issue, item=None, clear_task_dates=False):
    status = issue.get("status") or {}
    status_name = str(status.get("name") or "") if isinstance(status, dict) else str(status)
    closed_date = parse_redmine_date(issue.get("closed_on"))
    is_closed = issue_is_closed(issue)
    kind = item.get("kind", "VEVENT") if item else "VEVENT"
    uid = item.get("uid") if item else f"redmine-issue-{issue['id']}@task-sync-adapter"
    start_timing = item.get("start_timing") if item else None
    end_timing = item.get("end_timing") if item else None
    rewrite_task_dates = False
    if kind == "VTODO":
        issue_start = parse_redmine_date(issue.get("start_date"))
        issue_due = parse_redmine_date(issue.get("due_date"))
        item_start = parse_redmine_date(item.get("start_date")) if item else None
        item_due = parse_redmine_date(item.get("due_date")) if item else None
        rewrite_task_dates = clear_task_dates or bool(issue_start or issue_due) and (
            issue_start != item_start or issue_due != item_due
        )
        start_date = None if clear_task_dates else issue_start or item_start
        due_date = None if clear_task_dates else issue_due or item_due
        if rewrite_task_dates and not clear_task_dates:
            start_date, due_date = issue_start, issue_due
        start_property = (
            format_ical_date_property("DTSTART", start_date, start_timing)
            if start_date else None
        )
        end_property = (
            format_ical_date_property("DUE", due_date, end_timing)
            if due_date else None
        )
    else:
        start = issue.get("start_date") or issue.get("due_date") or (closed_date.isoformat() if is_closed and closed_date else None)
        due = (closed_date.isoformat() if is_closed and closed_date else None) or issue.get("due_date") or issue.get("start_date")
        if not start or not due:
            raise ValueError("issue has no start_date, due_date, or closed_on date")
        start_date = dt.date.fromisoformat(str(start)[:10])
        due_date = dt.date.fromisoformat(str(due)[:10])
        if due_date < start_date:
            if is_closed and closed_date:
                start_date = due_date
            else:
                start_date, due_date = due_date, start_date
        timed_item = bool(start_timing and end_timing)
        start_property = format_ical_date_property("DTSTART", start_date, start_timing if timed_item else None)
        end_property = format_ical_date_property("DTEND", due_date, end_timing if timed_item else None, exclusive_end=not timed_item)
    esc = lambda value: str(value).replace("\\", "\\\\").replace(";", "\\;").replace(",", "\\,").replace("\n", "\\n")
    subject = str(issue.get("subject") or f"Redmine #{issue['id']}")
    summary = f"[{status_name}] {subject}" if status_name else subject
    estimated_hours = issue.get("estimated_hours")
    metadata = [
        f"Redmine issue ID: {issue['id']}",
        f"Redmine status: {metadata_value(status_name or 'Unknown')}",
    ]
    if estimated_hours is not None:
        metadata.append(f"Estimated hours: {metadata_value(estimated_hours)}")
    full_description = with_metadata(issue.get("description"), metadata)
    if kind == "VTODO" and item and item.get("raw"):
        properties = {
            "SUMMARY": f"SUMMARY:{esc(summary)}",
            "DESCRIPTION": f"DESCRIPTION:{esc(full_description)}",
            "X-REDMINE-ISSUE-ID": f"X-REDMINE-ISSUE-ID:{issue['id']}",
        }
        if is_closed:
            properties["STATUS"] = "STATUS:COMPLETED"
        date_properties = (
            [line for line in (start_property, end_property) if line]
            if rewrite_task_dates else None
        )
        return patch_vtodo(
            item["raw"], properties, date_properties, clear_completed=not is_closed
        )
    lines = [
        "BEGIN:VCALENDAR", "VERSION:2.0", "PRODID:-//task-sync-adapter//EN", "CALSCALE:GREGORIAN",
        f"BEGIN:{kind}", f"UID:{uid}", f"DTSTAMP:{dt.datetime.now(dt.timezone.utc).strftime('%Y%m%dT%H%M%SZ')}",
        f"SUMMARY:{esc(summary)}",
        f"DESCRIPTION:{esc(full_description)}", f"X-REDMINE-ISSUE-ID:{issue['id']}",
    ]
    if start_property:
        lines.append(start_property)
    if end_property:
        lines.append(end_property)
    if is_closed:
        lines.append("STATUS:COMPLETED")
    lines.extend([f"END:{kind}", "END:VCALENDAR"])
    return ("\r\n".join(lines) + "\r\n").encode()


CALENDAR_COMPARE_FIELDS = (
    "uid", "kind", "redmine_id", "calendar_summary", "calendar_description",
    "start_date", "due_date", "start_timing", "end_timing", "status",
    "completed_at", "recurrence", "reminders",
)


def calendar_payload_changed(item, desired_raw, href):
    desired = parse_calendar_item(desired_raw, href, None)
    return desired is None or any(
        item.get(field) != desired.get(field) for field in CALENDAR_COMPARE_FIELDS
    )


def upsert_calendar_item(issue, item=None, clear_task_dates=False):
    collection = bidirectional_calendar_url()
    raw = bidirectional_ical(issue, item, clear_task_dates=clear_task_dates)
    href = item["href"] if item else f"{collection}/redmine-issue-{issue['id']}.ics"
    if item and item.get("raw") and not calendar_payload_changed(item, raw, href):
        return item
    radicale_raw(href, "PUT", raw, "text/calendar; charset=utf-8")
    CALENDAR_CACHE.pop(href, None)
    normalized = parse_calendar_item(raw, href, None)
    return normalized or {"uid": item["uid"] if item else f"redmine-issue-{issue['id']}@task-sync-adapter", "href": href, "etag": None, "raw": raw, "kind": item.get("kind", "VEVENT") if item else "VEVENT"}


def calendar_item_fields(item, include_dates=True):
    fields = {
        "subject": item["summary"],
        "description": redmine_description(item),
    }
    if include_dates:
        fields.update(
            {"start_date": item.get("start_date"), "due_date": item.get("due_date")}
        )
    return fields


def item_differs(item, issue, include_dates=True):
    content_differs = (
        item.get("summary", "") != str(issue.get("subject", ""))
        or redmine_description(item) != normalize_description(issue.get("description"))
    )
    return content_differs or (
        include_dates
        and (
            item.get("start_date") != issue.get("start_date")
            or item.get("due_date") != issue.get("due_date")
        )
    )


def redmine_change_wins(item, issue, mapping):
    redmine_updated = parse_redmine_timestamp(issue.get("updated_on"))
    last_seen = mapping.get("last_seen")
    redmine_changed = redmine_updated is not None and (
        last_seen is None or redmine_updated > last_seen
    )
    previous_hash = mapping.get("content_hash")
    calendar_hash = calendar_item_hash(item)
    # Old state entries hashed raw ICS bytes; Radicale may rewrite those without a user edit.
    calendar_changed = (
        previous_hash is not None
        and previous_hash.startswith("semantic:")
        and calendar_hash != previous_hash
    )
    # On a one-sided change, that side wins. If both changed, keep the calendar edit.
    return redmine_updated, redmine_changed and not calendar_changed


ISSUE_DETAIL_FIELDS = {
    "subject", "description", "start_date", "due_date", "status", "priority",
    "done_ratio", "estimated_hours", "closed_on", "updated_on",
}


def sync_calendar():
    with SYNC_LOCK:
        connection = database()
        try:
            previous = state_rows(connection)
            items = list_calendar_items()
            current = {item["uid"]: item for item in items}
            redmine_snapshot = get_issues()
            redmine_by_id = {int(issue["id"]): issue for issue in redmine_snapshot}
            redmine_ids = set(redmine_by_id)
            confirmed_closed_issues = {}
            created = updated = closed = 0
            for item in items:
                mapping = previous.get(item["uid"], {})
                issue_id = item.get("redmine_id") or mapping.get("redmine_id")
                if issue_id:
                    item["summary"] = strip_redmine_status_prefix(item.get("summary", ""))
                    if int(issue_id) not in redmine_ids:
                        radicale_raw(item["href"], "DELETE")
                        CALENDAR_CACHE.pop(item["href"], None)
                        delete_state(connection, item["uid"])
                        continue
                    issue = redmine_by_id[int(issue_id)]
                    if not ISSUE_DETAIL_FIELDS.issubset(issue):
                        issue = get_issue(int(issue_id))
                    redmine_updated, redmine_wins = redmine_change_wins(item, issue, mapping)
                    sync_dates = item.get("kind") != "VTODO" or calendar_dates_changed(
                        item, mapping
                    )
                    if item.get("status") == "COMPLETED":
                        if (not redmine_wins or mapping.get("pending_close")) and not issue_is_closed(issue):
                            close_issue(int(issue_id))
                            confirmed = get_issue(int(issue_id))
                            if not issue_is_closed(confirmed):
                                raise RuntimeError(f"Redmine issue {issue_id} was not closed")
                            confirmed_closed_issues[int(issue_id)] = confirmed
                            closed += 1
                    elif (
                        item_differs(item, issue, include_dates=sync_dates)
                        and not redmine_wins
                    ):
                        update_issue(
                            int(issue_id),
                            calendar_item_fields(item, include_dates=sync_dates),
                        )
                        updated += 1
                    if not redmine_wins or mapping.get("pending_close"):
                        save_state(connection, item, int(issue_id), redmine_updated)
                else:
                    is_task = item.get("kind") == "VTODO"
                    completed_task = is_task and item.get("status") == "COMPLETED"
                    clear_task_dates = is_task and not item.get("recurring")
                    description_item = (
                        {**item, "start_date": None, "due_date": None}
                        if clear_task_dates else item
                    )
                    issue = create_issue(
                        {
                            "title": item["summary"],
                            "text": redmine_description(description_item),
                            "start_date": None if is_task else item.get("start_date"),
                            "due_date": None if is_task else item.get("due_date"),
                            "status_id": REDMINE_CLOSED_STATUS_ID if completed_task else None,
                        }
                    )
                    issue_id = int(issue["id"])
                    # Keep the mapping if a later Redmine GET/PUT or CalDAV PUT fails;
                    # retrying must not create a second issue for the same task.
                    save_state(
                        connection, item, issue_id, parse_redmine_timestamp(issue.get("updated_on")),
                        pending_close=completed_task,
                    )
                    if completed_task:
                        issue = get_issue(issue_id)
                        if not issue_is_closed(issue):
                            close_issue(issue_id)
                            issue = get_issue(issue_id)
                        if not issue_is_closed(issue):
                            raise RuntimeError(f"Redmine issue {issue_id} was not closed")
                        confirmed_closed_issues[issue_id] = issue
                        closed += 1
                    normalized = upsert_calendar_item(
                        issue, item, clear_task_dates=clear_task_dates
                    )
                    # The end-of-cycle pass must use the cleaned-up task, not the
                    # initial Evolution snapshot with dates still attached.
                    item.update(normalized)
                    item["redmine_id"] = issue_id
                    save_state(connection, normalized, issue_id, parse_redmine_timestamp(issue.get("updated_on")))
                    created += 1
            if CALENDAR_DELETE_CLOSE and items:
                for uid, mapping in previous.items():
                    if uid in current or not mapping.get("redmine_id"):
                        continue
                    try:
                        issue = get_issue(int(mapping["redmine_id"]))
                        if issue.get("start_date") or issue.get("due_date"):
                            close_issue(int(mapping["redmine_id"]), clear_dates=True)
                            closed += 1
                    except RuntimeError:
                        continue
                    delete_state(connection, uid)
            issues = get_issues()
            for issue in issues:
                issue_id = int(issue["id"])
                issue = confirmed_closed_issues.get(issue_id, issue)
                mapped = next((item for item in items if item.get("redmine_id") == issue_id), None)
                if mapped is None:
                    mapped = next((item for item in items if previous.get(item["uid"], {}).get("redmine_id") == issue_id), None)
                if issue.get("start_date") or issue.get("due_date") or issue.get("closed_on"):
                    normalized = upsert_calendar_item(issue, mapped)
                    save_state(connection, normalized, issue_id, parse_redmine_timestamp(issue.get("updated_on")))
                elif mapped and mapped.get("kind") == "VTODO":
                    calendar_issue = {
                        **issue,
                        "start_date": mapped.get("start_date"),
                        "due_date": mapped.get("due_date"),
                    }
                    normalized = upsert_calendar_item(calendar_issue, mapped)
                    save_state(connection, normalized, issue_id, parse_redmine_timestamp(issue.get("updated_on")))
                elif mapped:
                    radicale_raw(mapped["href"], "DELETE")
                    CALENDAR_CACHE.pop(mapped["href"], None)
                    delete_state(connection, mapped["uid"])
            return {"events": len(items), "created": created, "updated": updated, "closed": closed}
        finally:
            connection.close()


def sync_loop():
    while True:
        started = time.monotonic()
        failed = False
        try:
            result = sync_calendar()
            print(f"bidirectional sync completed: {result}", flush=True)
        except Exception as error:  # noqa: BLE001
            # Temporary upstream failures must not terminate the sidecar.
            print(f"bidirectional sync failed: {error}", flush=True)
            failed = True
        delay = SYNC_INTERVAL_SECONDS if failed else max(0, SYNC_INTERVAL_SECONDS - (time.monotonic() - started))
        time.sleep(delay)


if __name__ == "__main__":
    sync_loop()
