# SQLite Database Integration + Per-App Time Limits

Replace the in-memory `AppDatabase` with a real SQLite database using `sqflite`. Also add per-app time limits for only specific apps (not all).

## Database Schema

### Table: `child_settings`
Single-row table for global child config.

| Column | Type | Default | Purpose |
|--------|------|---------|---------|
| `id` | INTEGER PK | 1 | Always 1 (single row) |
| `total_allowed_screen_time_minutes` | INTEGER | 240 | Global daily limit (4h) |
| `total_points` | INTEGER | 10 | Reward points balance |

### Table: `tasks`
Tasks loaded from JSON on first run, then persisted in SQLite.

| Column | Type | Purpose |
|--------|------|---------|
| `id` | INTEGER PK | Task ID |
| `name` | TEXT | e.g. "MORNING READING" |
| `category` | TEXT | e.g. "Daily Task" |
| `timer_time` | TEXT | e.g. "5s", "15m" |
| `state` | TEXT | "initial" / "accepted" / "completed" |

### Table: `app_limits`
Per-app time limits — **only** for apps that have a limit set. Apps without a row here have **no limit**.

| Column | Type | Purpose |
|--------|------|---------|
| `package_name` | TEXT PK | e.g. "com.whatsapp" |
| `app_name` | TEXT | Display name e.g. "WhatsApp" |
| `allowed_minutes` | INTEGER | Daily limit in minutes |

**Seed data** (inserted on first DB creation):

| Package | Name | Limit |
|---------|------|-------|
| `com.whatsapp` | WhatsApp | 180 min (3h) |
| `com.instagram.android` | Instagram | 300 min (5h) |
| `com.google.android.youtube` | YouTube | 120 min (2h) |
| `com.zhiliaoapp.musically` | TikTok | 90 min (1.5h) |

## Proposed Changes

### Dependencies

#### [MODIFY] [pubspec.yaml](file:///home/aziyan/Desktop/guardian-ai-ui/pubspec.yaml)
Add `sqflite: ^2.4.2` and `path: ^1.9.0` dependencies.

---

### Database Layer

#### [MODIFY] [app_database.dart](file:///home/aziyan/Desktop/guardian-ai-ui/lib/services/app_database.dart)
Rewrite to use `sqflite`:
- `initialize()` opens/creates the SQLite DB
- Creates tables `child_settings`, `tasks`, `app_limits`
- Seeds `child_settings` defaults + seed app limits + tasks from JSON on first run
- `ChildData` methods become async DB reads/writes:
  - `getPoints()` / `setPoints()`
  - `getAllowedScreenTime()` / `setAllowedScreenTime()`
  - `getTasks()` / `updateTaskState()`
  - `getAppLimit(packageName)` → returns `int?` (null = no limit)
  - `getAllAppLimits()` → `Map<String, int>`
- Keeps in-memory cache for `appUsageList` and `totalUsedScreenTime` (these come from native, not SQLite)

---

### Screen Updates

#### [MODIFY] [screen_time_screen.dart](file:///home/aziyan/Desktop/guardian-ai-ui/lib/screens/child/screen_time_screen.dart)
- In `_buildRealAppUsageItem()`: look up `AppDatabase().child.getAppLimit(app.packageName)` instead of hardcoded `const allowedHours = 5`
- If no limit → show just the used time (e.g. "2h 15m")
- If limit exists → show "2hr / 5hr" format
- Only show the red "+" (buy time) button for apps that have a limit

#### [MODIFY] [home_screen.dart](file:///home/aziyan/Desktop/guardian-ai-ui/lib/screens/child/home_screen.dart)
- Read `totalAllowedScreenTimeMinutes` from DB (async) instead of direct field access
- Read `totalPoints` from DB

#### [MODIFY] [tasks_screen.dart](file:///home/aziyan/Desktop/guardian-ai-ui/lib/screens/child/tasks_screen.dart)
- Read tasks from DB
- Update task state in DB on completion
- Update points in DB on task completion

#### [MODIFY] [buy_additional_time_dialog.dart](file:///home/aziyan/Desktop/guardian-ai-ui/lib/widgets/child/buy_additional_time_dialog.dart)
- Read points from DB

#### [MODIFY] [main_layout.dart](file:///home/aziyan/Desktop/guardian-ai-ui/lib/screens/child/main_layout.dart)
- `await AppDatabase().initialize()` (now async with SQLite open)

## Verification Plan

### Automated Tests
- `flutter pub get` to install sqflite + path
- `flutter analyze` — 0 errors
- Hot restart and verify the app runs, loads tasks/points from SQLite
- Check that WhatsApp/Instagram show per-app limits while other apps show only used time
