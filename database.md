# Database Schema - Guardian AI

SQLite database file: `guardian_ai.db`

---

## Tables Overview

| Table | Purpose | Type |
|-------|---------|------|
| `child_settings` | Global child configuration (single row) | Key-Value |
| `tasks` | Daily tasks loaded from JSON | Entity |
| `app_limits` | Per-app time limits for specific apps | Entity |

---

## Table: `child_settings`

**Purpose:** Stores global child settings (single-row table, always id = 1)

| Column | Type | Default | Description |
|--------|------|---------|-------------|
| `id` | INTEGER | 1 | Primary key (always 1) |
| `total_allowed_screen_time_minutes` | INTEGER | 240 | Daily screen time limit in minutes (4 hours) |
| `total_points` | INTEGER | 10 | Reward points balance |

**Seed Data:**
```sql
INSERT INTO child_settings (id, total_allowed_screen_time_minutes, total_points) 
VALUES (1, 240, 10);
```

---

## Table: `tasks`

**Purpose:** Daily tasks that children complete to earn screen time

| Column | Type | Description |
|--------|------|-------------|
| `id` | INTEGER | Primary key (1, 2, 3, ...) |
| `name` | TEXT | Task name (e.g., "MORNING READING") |
| `category` | TEXT | Category (e.g., "Daily Task", "Chores", "Study") |
| `timer_time` | TEXT | Duration string (e.g., "5m", "15m", "45m") |
| `state` | TEXT | Current state: `initial`, `accepted`, `completed` |

**Seed Data (from assets/data/tasks.json):**

| id | name | category | timer_time | state |
|----|------|----------|------------|-------|
| 1 | MORNING READING | Daily Task | 5m | initial |
| 2 | CLEAN ROOM | Chores | 15m | initial |
| 3 | HOMEWORK | Study | 45m | initial |
| 4 | EXERCISE | Daily Task | 20m | initial |
| 5 | WATER PLANTS | Chores | 10m | initial |

---

## Table: `app_limits`

**Purpose:** Per-app time limits - only specific apps have limits set

| Column | Type | Description |
|--------|------|-------------|
| `package_name` | TEXT | App's package name (primary key) |
| `app_name` | TEXT | Display name (e.g., "WhatsApp", "Instagram") |
| `allowed_minutes` | INTEGER | Daily limit in minutes |

**Seed Data:**

| package_name | app_name | allowed_minutes |
|--------------|----------|-----------------|
| com.whatsapp | WhatsApp | 180 (3 hours) |
| com.instagram.android | Instagram | 300 (5 hours) |
| com.google.android.youtube | YouTube | 120 (2 hours) |
| com.zhiliaoapp.musically | TikTok | 90 (1.5 hours) |

**Note:** Apps not in this table have **no limit** - they show only used time.

---

## Initialization

The database is initialized via `AppDatabase.initialize()` which:
1. Opens (or creates) the SQLite database at `guardian_ai.db`
2. Seeds default data on first run via `_onCreate`
3. Hydrates the live-usage cache from the native platform via `child.refreshUsageData()`

### `_onCreate` Method

Called once when the database file is first created.

#### child_settings table
```sql
CREATE TABLE child_settings (
  id INTEGER PRIMARY KEY,
  total_allowed_screen_time_minutes INTEGER NOT NULL DEFAULT 240,
  total_points INTEGER NOT NULL DEFAULT 10
)
```
Then inserts the seed row: `(1, 240, 10)`

#### tasks table
```sql
CREATE TABLE tasks (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL,
  category TEXT NOT NULL,
  timer_time TEXT NOT NULL,
  state TEXT NOT NULL DEFAULT 'initial'
)
```
Seeds tasks from `assets/data/tasks.json` (see table above).

#### app_limits table
```sql
CREATE TABLE app_limits (
  package_name TEXT PRIMARY KEY,
  app_name TEXT NOT NULL,
  allowed_minutes INTEGER NOT NULL
)
```
Seeds with the per-app limits shown in the table above.

---

## Child Data

Accessed via `AppDatabase().child`. Provides methods for:

### Live Usage Cache (not persisted in SQLite)
- `appUsageList`: List<AppUsageInfo> - Today's per-app usage stats from native platform
- `totalUsedScreenTime`: Duration - Total screen time used today
- `isUsageLoading`: boolean - Whether usage data is currently loading
- `refreshUsageData()`: Future<void> - Fetches today's usage stats from native platform and caches them

### Screen Time (SQLite)
- `getTotalAllowedScreenTimeMinutes()`: Future<int> - Returns total allowed screen time in minutes
- `setTotalAllowedScreenTimeMinutes(int minutes)`: Future<void> - Updates the allowed screen time
- `getTimeRemaining()`: Future<Duration> - Returns remaining screen time for today (allowed - used)

### Points (SQLite)
- `getTotalPoints()`: Future<int> - Returns current reward points balance
- `setTotalPoints(int points)`: Future<void> - Sets the points balance
- `addPoints(int amount)`: Future<void> - Adds points to the current balance

### Tasks (SQLite)
- `getTasks()`: Future<List<TaskModel>> - Returns all tasks ordered by ID
- `updateTaskState(int taskId, TaskState state)`: Future<void> - Updates a task's state
- `completedTasksSync(List<TaskModel> tasks)`: int - Returns count of completed tasks in a list
- `_parseTaskState(String state)`: TaskState - Converts string state to TaskState enum (internal)

### App Limits (SQLite)
- `getAppLimit(String packageName)`: Future<int?> - Returns allowed minutes for an app, or null if no limit
- `getAllAppLimits()`: Future<Map<String, int>> - Returns all app limits as a map
- `setAppLimit(String packageName, String appName, int allowedMinutes)`: Future<void> - Sets or updates an app limit
- `removeAppLimit(String packageName)`: Future<void> - Removes an app limit

---

## Parent Data

Accessed via `AppDatabase().parent`. Currently a placeholder for future parent-side features (profiles, rules, etc.).

---

## Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│                      AppDatabase                            │
│                   (SQLite: guardian_ai.db)                 │
└─────────────────────────────────────────────────────────────┘
                               │
        ┌─────────────────────┴─────────────────────┐
        │                                           │
        ▼                                           ▼
┌───────────────────┐                    ┌───────────────────┐
│   ChildData       │                    │   ParentData      │
│                   │                    │   (placeholder)   │
│ ┌───────────────┐ │                    └───────────────────┘
│ │ child_settings│ │
│ │ - points      │ │
│ │ - screen time │ │
│ └───────────────┘ │
│ ┌───────────────┐ │
│ │ tasks         │ │
│ └───────────────┘ │
│ ┌───────────────┐ │
│ │ app_limits    │ │
│ └───────────────┘ │
│ ┌───────────────┐ │
│ │ Live Usage    │ │ ← From native platform
│ │ (not in DB)   │ │   (AppUsageService)
│ └───────────────┘ │
└───────────────────┘
```

---

## Usage in Code

### Reading Data (Async)
```dart
final points = await AppDatabase().child.getTotalPoints();
final tasks = await AppDatabase().child.getTasks();
final limit = await AppDatabase().child.getAppLimit('com.whatsapp');
```

### Writing Data (Async)
```dart
await AppDatabase().child.setTotalPoints(20);
await AppDatabase().child.updateTaskState(1, TaskState.completed);
await AppDatabase().child.setAppLimit('com.whatsapp', 'WhatsApp', 120);
```

### Live Usage (From Native)
```dart
await AppDatabase().child.refreshUsageData();
final usage = AppDatabase().child.appUsageList;
```