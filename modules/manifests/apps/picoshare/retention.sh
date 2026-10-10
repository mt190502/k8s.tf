#!/bin/sh
#
# Enforces the PicoShare retention cap.
#
# PicoShare only deletes entries whose expiration_time has passed, and per-upload
# lifetimes (including "Never") can exceed the retention window. This script:
#   1. keeps the default upload lifetime at MAX_EXPIRATION_DAYS days, and
#   2. clamps every entry's expiration_time to at most upload_time + MAX_EXPIRATION_DAYS.
# PicoShare's garbage collector (every 7 hours) then removes the expired rows.
#
# Timestamps must be written in RFC3339 format: PicoShare parses them with
# time.RFC3339, so strftime() is used instead of datetime() (which would emit a
# space-separated format the application cannot parse).

set -eu

DB_PATH="${DB_PATH:-/data/store.db}"
MAX_EXPIRATION_DAYS="${MAX_EXPIRATION_DAYS:-7}"
VACUUM="${VACUUM:-true}"

echo "enforcing a ${MAX_EXPIRATION_DAYS}-day retention cap on ${DB_PATH}"

sqlite3 -cmd ".timeout 30000" "${DB_PATH}" <<SQL
UPDATE settings
   SET default_expiration_in_days = ${MAX_EXPIRATION_DAYS}
 WHERE id = 1;

UPDATE entries
   SET expiration_time = strftime('%Y-%m-%dT%H:%M:%SZ', upload_time, '+${MAX_EXPIRATION_DAYS} days')
 WHERE expiration_time IS NULL
    OR datetime(expiration_time) > datetime(upload_time, '+${MAX_EXPIRATION_DAYS} days');
SQL

if [ "${VACUUM}" = "true" ]; then
  # Best effort: VACUUM needs brief exclusive access, and is what actually returns
  # the deleted content's space to the filesystem.
  sqlite3 -cmd ".timeout 30000" "${DB_PATH}" "VACUUM;" \
    || echo "VACUUM skipped (database busy); space is reclaimed on a later run"
fi

echo "retention enforced"
