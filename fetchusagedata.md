# Fetch Usage Data — App Usage & Screen Time

This document covers which files fetch, process, and display app usage statistics and screen time data on the child device.

---

## Architecture Overview

```
Native Android (UsageStatsManager)
         │
         ▼
MethodChannel('guardian/monitoring')
         │
         ▼
AppUsageService  ← Fetches raw data
         │
         ▼
AppUsageScreen   ← Displays formatted data
         │
         ▼
FeedbackLoopController  ← Consumes real-time launch events (no duration)
```

---

## `lib/services/app_usage_service.dart` — Data Fetching Layer

**Role:** Gateway to native Android `UsageStatsManager`. All app usage and screen time data originates here via `MethodChannel('guardian/monitoring')`.

### Data Models

| Model | Fields | Purpose |
|-------|--------|---------|
| `AppUsageInfo` | `packageName` (String), `appName` (String), `totalTimeInForeground` (Duration), `lastTimeUsed` (DateTime) | Per-app usage stats with foreground duration |
| `DailyScreenTime` | `date` (DateTime), `totalTime` (Duration) | Total screen time for a single calendar day |
| `AppLaunchEvent` | `packageName` (String), `timestamp` (DateTime) | Single app launch event with timestamp |

**All models** use `fromMap()` factory constructors to deserialize from platform channel data.

### Methods — Usage Data Fetching

| Method | Native Method Call | Return Type | Description |
|--------|-------------------|-------------|-------------|
| `getTodayUsage()` | `getTodayUsageStats` | `Future<List<AppUsageInfo>>` | Fetches today's per-app usage with foreground time. Iterates through the returned list, converts each map to `AppUsageInfo` via `fromMap()`. Includes extensive debug logging for each item. |
| `getWeeklyUsage()` | `getWeeklyUsageStats` | `Future<List<AppUsageInfo>>` | Fetches weekly aggregated per-app usage. Same format as today's data but covers 7 days. |
| `getWeeklyDailyBreakdown()` | `getWeeklyDailyBreakdown` | `Future<List<DailyScreenTime>>` | Fetches per-day total screen time for the past week. Returns 7 `DailyScreenTime` objects, one per day. |
| `getAppLimits()` | `getAppLimits` | `Future<Map<String, Duration>>` | Fetches stored time limits per app package name. Returns `Map<packageName, Duration>`. Native side returns milliseconds, converted to `Duration`. |

### Real-Time Stream

| Stream | Channel Type | Event Channel | Description |
|--------|-------------|---------------|-------------|
| `appLaunchStream` | `Stream<AppLaunchEvent>` | `EventChannel('guardian/app_launch_stream')` | Fires an `AppLaunchEvent` every time any app is launched. Emits `packageName` + `timestamp`. Lazily initialized as broadcast stream. Filters out events where `packageName` is null. |

### Usage Data Flow (`getTodayUsage`)

```
1. InvokeMethod('getTodayUsageStats') → native Android
2. Native returns List<Map> (raw usage stats)
3. Flutter iterates through list:
   a. Checks each item is a Map
   b. Calls AppUsageInfo.fromMap(item)
   c. Catches parse errors per-item (won't crash on bad data)
   d. Logs first 10 items with duration in minutes
4. Returns List<AppUsageInfo>
```

---

## `lib/screens/app_usage_screen.dart` — Data Display Layer

**Role:** Fetches data from `AppUsageService`, computes aggregates, and renders the UI with charts, lists, and controls.

### State Variables

```dart
List<AppUsageInfo> _todayUsage = [];          // Per-app usage for today
List<DailyScreenTime> _weeklyBreakdown = [];  // Daily totals for the week
Map<String, Duration> _appLimits = {};        // Time limits per app
Duration _totalScreenTime = Duration.zero;    // Computed aggregate
bool _blockerRunning = false;                 // Blocker service status
```

### Data Fetching (`_loadData()`)

```dart
final hasPermission = await _service.hasUsageStatsPermission();  // Must be granted first
final today = await _service.getTodayUsage();                     // Per-app today
final weekly = await _service.getWeeklyDailyBreakdown();          // Daily totals
final limits = await _service.getAppLimits();                     // Set limits
final blockerRunning = await _service.isBlockerRunning();         // Blocker status

// Compute total screen time
final totalMs = today.fold<int>(
  0,
  (sum, app) => sum + app.totalTimeInForeground.inMilliseconds,
);
```

### Data Display Methods

| Method | Data Used | Description |
|--------|-----------|-------------|
| `_buildScreenTimeHeader()` | `_totalScreenTime` | Displays total screen time in large text (e.g. "3h 45m") |
| `_buildWeeklyChart()` | `_weeklyBreakdown` | Bar chart showing daily screen time for the week. Calculates `maxMs` to scale bars. Highlights today's bar with gradient. |
| `_buildAppList()` | `_todayUsage`, `_appLimits` | ListView of apps (max 25). Each tile shows app name, usage duration, progress bar (relative to most-used app), and limit status. |
| `_buildBlockerToggle()` | `_blockerRunning`, `_appLimits` | Toggle switch for app blocker. Shows limit count and active status. |

### `_AppUsageTile` Widget

**Props:**
- `app` (`AppUsageInfo`) — the app's usage data
- `limit` (`Duration?`) — optional time limit for this app
- `maxDuration` (`Duration`) — used to calculate progress bar width

**Renders:**
- App icon placeholder (colored by package hash) with first letter of app name
- App name and usage duration (e.g. "1h 23m")
- Progress bar (width proportional to `app.totalTimeInForeground / maxDuration`)
- Bar color: red if over limit, purple otherwise
- Limit label if set: "Limit: 2h" or "⏰ Over limit (2h)"
- Timer button to open `_SetLimitSheet`

### `_SetLimitSheet` Bottom Sheet

**Presets:** 15m, 30m, 1h, 2h, 3h, 4h

**Actions:**
- Select a preset duration
- Toggle "Enable App Blocker with this limit"
- Tap "Set Limit" → calls `AppUsageService.setAppLimit(packageName, duration)`
- If blocker enabled → checks accessibility, starts blocker via `AppUsageService.startBlocker()`
- Optional "Remove Limit" button if existing limit is set

---

## `lib/services/feedback_loop_controller.dart` — Secondary Consumer

**Role:** Consumes real-time app launch events but does **not** fetch usage duration.

### Usage

```dart
// In _startSignalSubscriptions()
_appLaunchSub = _appUsageService.appLaunchStream.listen((event) {
  _setActiveApp(event.packageName, source: 'app');
});
```

**What it does:**
- Listens to `appLaunchStream` from `AppUsageService`
- On each app launch, calls `_setActiveApp(packageName)`
- Classifies the app into a frequency class (`normal`, `reduced`, `veryLow`)
- Adjusts screenshot capture delay based on app classification
- **Does NOT** read or store `totalTimeInForeground` or usage duration

---

## Summary Table

| File | Fetches Duration? | Fetches Per-App? | Fetches Daily Totals? | Real-Time Stream? | Display UI? |
|------|-------------------|------------------|----------------------|-------------------|-------------|
| `app_usage_service.dart` | Yes | Yes | Yes | Yes (`appLaunchStream`) | No |
| `app_usage_screen.dart` | No (delegates to service) | Yes (via service) | Yes (via service) | No | Yes |
| `feedback_loop_controller.dart` | No | No (package name only) | No | Yes (`appLaunchStream`) | No |
