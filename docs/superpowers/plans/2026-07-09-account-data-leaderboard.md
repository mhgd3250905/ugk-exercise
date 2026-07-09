# Account Data Sync And Sports Plaza Leaderboard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build account profile sync, premium-only workout cloud sync, and the sports plaza leaderboard for the pushup exercise.

**Architecture:** Keep the existing local workout flow intact. Flutter saves local sessions first, then a thin sync layer uploads premium account data in the background. Cloudflare Worker/D1 owns profile writes, membership-gated workout sync, leaderboard join state, and daily ranking aggregates.

**Tech Stack:** Flutter/Dart, ChangeNotifier controllers, `http`, Cloudflare Workers TypeScript, D1, Node test runner.

---

## Scope Check

This plan implements the full first version from `docs/superpowers/specs/2026-07-09-account-data-leaderboard-design.md`.

The work is split into independently verifiable slices:

1. Public profile model and API.
2. Local workout sync metadata.
3. Worker workout sync.
4. Flutter background sync.
5. Worker leaderboard.
6. Flutter UI for profile, home card, leaderboard, and records merge.

Do not change pushup recognition, replay fixtures, camera inference, or `pushup_domain.dart`.

## File Map

### Worker

- Modify: `workers/membership-api/schema.sql`
  - Add profile fields to `users`.
  - Add `workout_sessions`, `leaderboard_profiles`, `leaderboard_daily_totals`.
- Modify: `workers/membership-api/src/index.ts`
  - Register new routes and keep existing auth/membership/webhook routes.
- Create: `workers/membership-api/src/profile.ts`
  - `updateProfile`, nickname normalization, avatar key validation.
- Create: `workers/membership-api/src/workouts.ts`
  - `syncWorkouts`, workout validation, membership gate, idempotent writes, leaderboard aggregation.
- Create: `workers/membership-api/src/leaderboard.ts`
  - Join, leave, day/week leaderboard query, top 100 plus my rank.
- Modify: `workers/membership-api/src/types.ts`
  - Add shared request/body/result types only when they reduce repetition in Worker modules.
- Test: `workers/membership-api/test/profile.test.mjs`
- Test: `workers/membership-api/test/workout-sync.test.mjs`
- Test: `workers/membership-api/test/leaderboard.test.mjs`

### Flutter Product/Platform/Control

- Modify: `lib/product/membership_status.dart`
  - Extend `AppUser` with `nickname`, `avatarKey`, and `publicDisplayName`.
- Modify: `lib/product/workout_session_store.dart`
  - Add `exerciseType`, `syncStatus`, `syncedAt`, and update methods with backward-compatible JSON parsing.
- Create: `lib/product/leaderboard_models.dart`
  - Leaderboard row, period, snapshot, join status.
- Modify: `lib/platform/membership_api_client.dart`
  - Add profile, workout sync, workout fetch, leaderboard methods.
- Modify: `lib/control/account_controller.dart`
  - Add profile update command and expose current saved session to sync code.
- Create: `lib/control/workout_sync_controller.dart`
  - Background sync orchestration over `WorkoutSessionStore`, `AccountController`, and `MembershipApiClient`.
- Create: `lib/control/leaderboard_controller.dart`
  - Load/join/leave leaderboard state.

### Flutter UI

- Modify: `lib/main.dart`
  - Wire controllers.
- Modify: `lib/ui/pages/home_page.dart`
  - Add sports plaza leaderboard card and pass sync controller to workout/records pages.
- Modify: `lib/ui/pages/workout_page.dart`
  - Queue cloud sync after local save without blocking navigation.
- Modify: `lib/ui/pages/profile_page.dart`
  - Add nickname editor and built-in avatar picker.
- Modify: `lib/ui/pages/records_page.dart`
  - Show local records first, then cloud sync state/merged cloud history for premium accounts.
- Create: `lib/ui/pages/leaderboard_page.dart`
  - Day/week pushup leaderboard, join prompt, top 100 and my rank.
- Modify: `lib/l10n/app_zh.arb`
- Modify: `lib/l10n/app_en.arb`

### Flutter Tests

- Modify: `test/membership_status_test.dart`
- Modify: `test/membership_api_client_test.dart`
- Modify: `test/workout_session_store_test.dart`
- Create: `test/workout_sync_controller_test.dart`
- Create: `test/leaderboard_controller_test.dart`
- Modify: `test/profile_page_test.dart`
- Create: `test/leaderboard_page_test.dart`
- Modify: `test/workout_page_test.dart`

---

## Task 1: Worker Schema And Profile Endpoint

**Files:**
- Modify: `workers/membership-api/schema.sql`
- Modify: `workers/membership-api/src/index.ts`
- Create: `workers/membership-api/src/profile.ts`
- Create: `workers/membership-api/test/profile.test.mjs`

- [ ] **Step 1: Write failing profile route tests**

Create `workers/membership-api/test/profile.test.mjs` with these cases:

```js
import assert from "node:assert/strict";
import test from "node:test";

import worker from "../.tmp-test/index.js";

const envBase = {
  GOOGLE_CLIENT_ID: "unit-test-google-client-id",
  REVENUECAT_WEBHOOK_SECRET: "unit-test-webhook-secret",
  SESSION_SECRET: "unit-test-session-secret",
};

class ProfileDb {
  constructor() {
    this.sessions = new Map([["valid-token-hash", {
      user_id: "user_1",
      app_user_id: "user_1",
      expires_at: "2099-01-01T00:00:00.000Z",
    }]]);
    this.users = new Map([["user_1", {
      id: "user_1",
      display_name: "Google Name",
      email: "a@example.com",
      avatar_url: "https://example.com/google.png",
      nickname: null,
      nickname_key: null,
      avatar_key: null,
      nickname_updated_at: null,
    }]]);
    this.nicknameKeys = new Set(["taken"]);
    this.updatedUser = null;
  }

  prepare(sql) {
    return new ProfileStatement(this, sql);
  }
}

class ProfileStatement {
  constructor(db, sql) {
    this.db = db;
    this.sql = sql;
    this.args = [];
  }

  bind(...args) {
    this.args = args;
    return this;
  }

  async first() {
    if (this.sql.includes("FROM sessions WHERE token_hash = ?")) {
      return this.db.sessions.values().next().value;
    }
    if (this.sql.includes("FROM users WHERE nickname_key = ?")) {
      const key = this.args[0];
      return this.db.nicknameKeys.has(key) ? { id: "other_user" } : null;
    }
    if (this.sql.includes("SELECT nickname_updated_at FROM users")) {
      return this.db.users.get(this.args[0]);
    }
    return null;
  }

  async run() {
    if (this.sql.includes("UPDATE users SET nickname")) {
      this.db.updatedUser = {
        nickname: this.args[0],
        nickname_key: this.args[1],
        avatar_key: this.args[2],
        user_id: this.args[5],
      };
    }
    return { meta: { changes: 1 } };
  }
}

function env(db) {
  return { ...envBase, DB: db };
}

function authedRequest(body) {
  return new Request("https://worker.test/me/profile", {
    method: "PATCH",
    headers: {
      "content-type": "application/json",
      authorization: "Bearer valid-token",
    },
    body: JSON.stringify(body),
  });
}

test("profile update saves normalized unique nickname and avatar key", async () => {
  const db = new ProfileDb();

  const response = await worker.fetch(
    authedRequest({ nickname: "训练者 01", avatarKey: "ring-green" }),
    env(db),
  );

  assert.equal(response.status, 200);
  assert.equal(db.updatedUser.nickname, "训练者 01");
  assert.equal(db.updatedUser.nickname_key, "训练者01");
  assert.equal(db.updatedUser.avatar_key, "ring-green");
});

test("profile update rejects duplicate nickname", async () => {
  const response = await worker.fetch(
    authedRequest({ nickname: "taken", avatarKey: "ring-green" }),
    env(new ProfileDb()),
  );

  assert.equal(response.status, 409);
  assert.deepEqual(await response.json(), { error: "nickname_taken" });
});

test("profile update rejects unknown avatar key", async () => {
  const response = await worker.fetch(
    authedRequest({ nickname: "训练者 02", avatarKey: "remote-url" }),
    env(new ProfileDb()),
  );

  assert.equal(response.status, 400);
  assert.deepEqual(await response.json(), { error: "invalid_avatar_key" });
});
```

- [ ] **Step 2: Run profile tests and verify failure**

Run:

```bash
cd workers/membership-api && npm test -- test/profile.test.mjs
```

Expected: FAIL because `/me/profile` is not registered and `profile.ts` does not exist.

- [ ] **Step 3: Extend schema**

Modify `workers/membership-api/schema.sql`:

```sql
ALTER TABLE users ADD COLUMN nickname TEXT;
ALTER TABLE users ADD COLUMN nickname_key TEXT;
ALTER TABLE users ADD COLUMN avatar_key TEXT;
ALTER TABLE users ADD COLUMN nickname_updated_at TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS users_nickname_key_idx
ON users(nickname_key)
WHERE nickname_key IS NOT NULL;
```

Keep the existing `display_name`, `email`, and `avatar_url` columns for Google source data.

- [ ] **Step 4: Add profile route implementation**

Create `workers/membership-api/src/profile.ts`:

```ts
import { json, requireSession } from "./session.js";
import type { Env } from "./types.js";

const avatarKeys = new Set([
  "ring-green",
  "ring-lime",
  "ring-sky",
  "ring-yellow",
  "ring-coral",
  "bolt-green",
  "bolt-lime",
  "bolt-sky",
]);

export async function updateProfile(
  request: Request,
  env: Env,
): Promise<Response> {
  const session = await requireSession(env, request);
  if (session instanceof Response) {
    return session;
  }

  const body = (await request.json()) as {
    nickname?: unknown;
    avatarKey?: unknown;
  };
  if (typeof body.nickname !== "string") {
    return json({ error: "invalid_nickname" }, 400);
  }
  if (typeof body.avatarKey !== "string" || !avatarKeys.has(body.avatarKey)) {
    return json({ error: "invalid_avatar_key" }, 400);
  }

  const nickname = body.nickname.trim();
  const nicknameKey = normalizeNickname(nickname);
  if (nickname.length < 2 || nickname.length > 16 || nicknameKey.length < 2) {
    return json({ error: "invalid_nickname" }, 400);
  }

  const existing = await env.DB.prepare(
    "SELECT id FROM users WHERE nickname_key = ? AND id <> ?",
  )
    .bind(nicknameKey, session.userId)
    .first<{ id: string }>();
  if (existing) {
    return json({ error: "nickname_taken" }, 409);
  }

  const current = await env.DB.prepare(
    "SELECT nickname_updated_at FROM users WHERE id = ?",
  )
    .bind(session.userId)
    .first<{ nickname_updated_at: string | null }>();
  const now = new Date();
  if (
    current?.nickname_updated_at &&
    now.getTime() - Date.parse(current.nickname_updated_at) <
      30 * 24 * 60 * 60 * 1000
  ) {
    return json({ error: "nickname_change_too_soon" }, 409);
  }

  const nowIso = now.toISOString();
  await env.DB.prepare(
    "UPDATE users SET nickname = ?, nickname_key = ?, avatar_key = ?, nickname_updated_at = ?, updated_at = ? WHERE id = ?",
  )
    .bind(nickname, nicknameKey, body.avatarKey, nowIso, nowIso, session.userId)
    .run();

  return json({
    user: {
      id: session.userId,
      nickname,
      avatarKey: body.avatarKey,
    },
  });
}

export function normalizeNickname(value: string): string {
  return value.trim().toLowerCase().replace(/\s+/g, "");
}
```

Modify `workers/membership-api/src/index.ts`:

```ts
import { updateProfile } from "./profile.js";
```

Register before the 404:

```ts
if (request.method === "PATCH" && url.pathname === "/me/profile") {
  return updateProfile(request, env);
}
```

- [ ] **Step 5: Run profile tests**

Run:

```bash
cd workers/membership-api && npm test -- test/profile.test.mjs
```

Expected: PASS.

- [ ] **Step 6: Run all Worker tests**

Run:

```bash
cd workers/membership-api && npm test
```

Expected: PASS.

- [ ] **Step 7: Commit**

Run:

```bash
git add workers/membership-api/schema.sql workers/membership-api/src/index.ts workers/membership-api/src/profile.ts workers/membership-api/test/profile.test.mjs
git commit -m "feat: add account profile update api"
```

---

## Task 2: Flutter Public Profile Models And API Client

**Files:**
- Modify: `lib/product/membership_status.dart`
- Modify: `lib/platform/membership_api_client.dart`
- Modify: `test/membership_status_test.dart`
- Modify: `test/membership_api_client_test.dart`

- [ ] **Step 1: Write failing model tests**

Add to `test/membership_status_test.dart`:

```dart
test('AppUser parses public nickname and avatar key with legacy fallback', () {
  final user = AppUser.fromJson({
    'id': 'user_1',
    'displayName': 'Google Name',
    'email': 'a@example.com',
    'avatarUrl': 'https://example.com/a.png',
    'nickname': '训练者 01',
    'avatarKey': 'ring-green',
  });

  expect(user.publicDisplayName, '训练者 01');
  expect(user.avatarKey, 'ring-green');
});

test('AppUser falls back to display name when nickname is absent', () {
  final user = AppUser.fromJson({
    'id': 'user_1',
    'displayName': 'Google Name',
    'email': 'a@example.com',
    'avatarUrl': null,
  });

  expect(user.publicDisplayName, 'Google Name');
  expect(user.avatarKey, isNull);
});
```

- [ ] **Step 2: Run model tests and verify failure**

Run:

```bash
flutter test test/membership_status_test.dart
```

Expected: FAIL because `nickname`, `avatarKey`, and `publicDisplayName` are missing.

- [ ] **Step 3: Extend AppUser minimally**

Modify `lib/product/membership_status.dart`:

```dart
class AppUser {
  const AppUser({
    required this.id,
    required this.displayName,
    required this.email,
    required this.avatarUrl,
    this.nickname,
    this.avatarKey,
  });

  final String id;
  final String displayName;
  final String email;
  final String? avatarUrl;
  final String? nickname;
  final String? avatarKey;

  String get publicDisplayName {
    final value = nickname?.trim();
    return value == null || value.isEmpty ? displayName : value;
  }

  static AppUser fromJson(Map<String, Object?> json) {
    return AppUser(
      id: json['id']! as String,
      displayName: (json['displayName'] as String?) ?? '训练者',
      email: (json['email'] as String?) ?? '',
      avatarUrl: json['avatarUrl'] as String?,
      nickname: json['nickname'] as String?,
      avatarKey: json['avatarKey'] as String?,
    );
  }
}
```

- [ ] **Step 4: Write failing API client profile test**

Add to `test/membership_api_client_test.dart`:

```dart
test('updateProfile patches nickname and avatar key', () async {
  final client = MembershipApiClient(
    baseUrl: 'https://api.example.com',
    httpClient: MockClient((request) async {
      expect(request.method, 'PATCH');
      expect(request.url.toString(), 'https://api.example.com/me/profile');
      expect(request.headers['authorization'], 'Bearer session_1');
      expect(request.body, contains('训练者 01'));
      expect(request.body, contains('ring-green'));
      return http.Response(
        '''
        {
          "user": {
            "id": "user_1",
            "displayName": "Google Name",
            "email": "a@example.com",
            "avatarUrl": null,
            "nickname": "训练者 01",
            "avatarKey": "ring-green"
          }
        }
        ''',
        200,
        headers: {'content-type': 'application/json'},
      );
    }),
  );

  final user = await client.updateProfile(
    'session_1',
    nickname: '训练者 01',
    avatarKey: 'ring-green',
  );

  expect(user.publicDisplayName, '训练者 01');
  expect(user.avatarKey, 'ring-green');
});
```

- [ ] **Step 5: Run API client test and verify failure**

Run:

```bash
flutter test test/membership_api_client_test.dart
```

Expected: FAIL because `updateProfile` is missing.

- [ ] **Step 6: Implement API client method**

Modify `lib/platform/membership_api_client.dart`:

```dart
Future<AppUser> updateProfile(
  String sessionToken, {
  required String nickname,
  required String avatarKey,
}) async {
  final response = await _httpClient.patch(
    _baseUri.resolve('me/profile'),
    headers: {
      'authorization': 'Bearer $sessionToken',
      'content-type': 'application/json',
    },
    body: jsonEncode({'nickname': nickname, 'avatarKey': avatarKey}),
  );
  final parsed = _parseJson(response);
  return AppUser.fromJson(Map<String, Object?>.from(parsed['user']! as Map));
}
```

- [ ] **Step 7: Run Flutter tests for touched units**

Run:

```bash
flutter test test/membership_status_test.dart test/membership_api_client_test.dart
```

Expected: PASS.

- [ ] **Step 8: Commit**

Run:

```bash
git add lib/product/membership_status.dart lib/platform/membership_api_client.dart test/membership_status_test.dart test/membership_api_client_test.dart
git commit -m "feat: add public profile api client"
```

---

## Task 3: Local Workout Sync Metadata

**Files:**
- Modify: `lib/product/workout_session_store.dart`
- Modify: `test/workout_session_store_test.dart`

- [ ] **Step 1: Write failing backward compatibility and sync status tests**

Add to `test/workout_session_store_test.dart`:

```dart
test('fromJson defaults old sessions to pushup localOnly records', () {
  final session = WorkoutSession.fromJson({
    'id': 'old',
    'startedAt': '2026-07-08T09:00:00.000',
    'endedAt': '2026-07-08T09:03:00.000',
    'count': 12,
  });

  expect(session.exerciseType, 'pushup');
  expect(session.syncStatus, WorkoutSyncStatus.localOnly);
  expect(session.syncedAt, isNull);
});

test('markForCloudSync and markSynced update stored sync status', () async {
  final store = WorkoutSessionStore(baseDir: tempDir);
  final session = WorkoutSession(
    id: 's1',
    startedAt: DateTime(2026, 7, 8, 9),
    endedAt: DateTime(2026, 7, 8, 9, 3),
    count: 12,
  );
  await store.append(session);

  await store.markForCloudSync('s1');
  expect((await store.load()).single.syncStatus, WorkoutSyncStatus.pending);

  await store.markCloudSynced('s1', DateTime(2026, 7, 8, 10));
  final updated = (await store.load()).single;
  expect(updated.syncStatus, WorkoutSyncStatus.synced);
  expect(updated.syncedAt, DateTime(2026, 7, 8, 10));
});
```

- [ ] **Step 2: Run store test and verify failure**

Run:

```bash
flutter test test/workout_session_store_test.dart
```

Expected: FAIL because sync metadata does not exist.

- [ ] **Step 3: Add sync status enum and model fields**

Modify `lib/product/workout_session_store.dart`:

```dart
enum WorkoutSyncStatus {
  localOnly,
  pending,
  synced,
  failed;

  static WorkoutSyncStatus fromJson(Object? value) {
    return WorkoutSyncStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => WorkoutSyncStatus.localOnly,
    );
  }
}
```

Extend `WorkoutSession` constructor and fields:

```dart
const WorkoutSession({
  required this.id,
  required this.startedAt,
  required this.endedAt,
  required this.count,
  this.exerciseType = 'pushup',
  this.syncStatus = WorkoutSyncStatus.localOnly,
  this.syncedAt,
});

final String exerciseType;
final WorkoutSyncStatus syncStatus;
final DateTime? syncedAt;
```

Add JSON keys:

```dart
'exerciseType': exerciseType,
'syncStatus': syncStatus.name,
if (syncedAt != null) 'syncedAt': syncedAt!.toIso8601String(),
```

Parse with defaults:

```dart
exerciseType: (json['exerciseType'] as String?) ?? 'pushup',
syncStatus: WorkoutSyncStatus.fromJson(json['syncStatus']),
syncedAt: json['syncedAt'] == null
    ? null
    : DateTime.parse(json['syncedAt']! as String).toLocal(),
```

Update equality/hashCode/toString to include the new fields.

- [ ] **Step 4: Add store update helpers**

Add private replacement helper and public status methods:

```dart
Future<void> markForCloudSync(String id) async {
  await _replace(
    id,
    (session) => session.copyWith(syncStatus: WorkoutSyncStatus.pending),
  );
}

Future<void> markCloudSynced(String id, DateTime syncedAt) async {
  await _replace(
    id,
    (session) => session.copyWith(
      syncStatus: WorkoutSyncStatus.synced,
      syncedAt: syncedAt,
    ),
  );
}

Future<void> markCloudSyncFailed(String id) async {
  await _replace(
    id,
    (session) => session.copyWith(syncStatus: WorkoutSyncStatus.failed),
  );
}

Future<List<WorkoutSession>> pendingCloudSync() async {
  return [
    for (final session in await load())
      if (session.syncStatus == WorkoutSyncStatus.pending ||
          session.syncStatus == WorkoutSyncStatus.failed)
        session,
  ];
}

Future<void> _replace(
  String id,
  WorkoutSession Function(WorkoutSession session) update,
) async {
  final sessions = await load();
  final next = [
    for (final session in sessions)
      session.id == id ? update(session) : session,
  ];
  await _write(next);
}
```

Add `copyWith` and extract append writing into `_write(List<WorkoutSession>)`.

- [ ] **Step 5: Run store tests**

Run:

```bash
flutter test test/workout_session_store_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit**

Run:

```bash
git add lib/product/workout_session_store.dart test/workout_session_store_test.dart
git commit -m "feat: track workout cloud sync state"
```

---

## Task 4: Worker Workout Sync Endpoint

**Files:**
- Modify: `workers/membership-api/schema.sql`
- Modify: `workers/membership-api/src/index.ts`
- Create: `workers/membership-api/src/workouts.ts`
- Create: `workers/membership-api/test/workout-sync.test.mjs`

- [ ] **Step 1: Write failing workout sync tests**

Create `workers/membership-api/test/workout-sync.test.mjs` with cases:

```js
import assert from "node:assert/strict";
import test from "node:test";

import { syncWorkoutsForTest } from "../.tmp-test/workouts.js";

test("sync rejects non-premium accounts", async () => {
  const result = await syncWorkoutsForTest({
    premiumActive: false,
    joinedAt: null,
    existingSessionIds: new Set(),
    workouts: [{
      clientSessionId: "s1",
      exerciseType: "pushup",
      startedAt: "2026-07-09T01:00:00.000Z",
      endedAt: "2026-07-09T01:03:00.000Z",
      localDate: "2026-07-09",
      timezoneOffsetMinutes: 480,
      metricValue: 20,
      metricUnit: "reps",
    }],
  });

  assert.deepEqual(result, [{ clientSessionId: "s1", status: "rejected", reason: "premium_required" }]);
});

test("sync accepts first upload and ignores duplicate for aggregation", async () => {
  const result = await syncWorkoutsForTest({
    premiumActive: true,
    joinedAt: "2026-07-09T00:00:00.000Z",
    existingSessionIds: new Set(["s1"]),
    workouts: [{
      clientSessionId: "s1",
      exerciseType: "pushup",
      startedAt: "2026-07-09T01:00:00.000Z",
      endedAt: "2026-07-09T01:03:00.000Z",
      localDate: "2026-07-09",
      timezoneOffsetMinutes: 480,
      metricValue: 20,
      metricUnit: "reps",
    }],
  });

  assert.deepEqual(result, [{ clientSessionId: "s1", status: "duplicate" }]);
});

test("sync does not aggregate workouts before leaderboard join", async () => {
  const result = await syncWorkoutsForTest({
    premiumActive: true,
    joinedAt: "2026-07-09T02:00:00.000Z",
    existingSessionIds: new Set(),
    workouts: [{
      clientSessionId: "s1",
      exerciseType: "pushup",
      startedAt: "2026-07-09T01:00:00.000Z",
      endedAt: "2026-07-09T01:03:00.000Z",
      localDate: "2026-07-09",
      timezoneOffsetMinutes: 480,
      metricValue: 20,
      metricUnit: "reps",
    }],
  });

  assert.equal(result[0].status, "accepted");
  assert.equal(result[0].aggregated, false);
});
```

- [ ] **Step 2: Run workout sync tests and verify failure**

Run:

```bash
cd workers/membership-api && npm test -- test/workout-sync.test.mjs
```

Expected: FAIL because `workouts.ts` does not exist.

- [ ] **Step 3: Extend schema for cloud workouts and daily totals**

Append to `workers/membership-api/schema.sql`:

```sql
CREATE TABLE IF NOT EXISTS workout_sessions (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id),
  client_session_id TEXT NOT NULL,
  exercise_type TEXT NOT NULL,
  started_at TEXT NOT NULL,
  ended_at TEXT NOT NULL,
  duration_seconds INTEGER NOT NULL,
  local_date TEXT NOT NULL,
  timezone_offset_minutes INTEGER NOT NULL,
  ranking_date TEXT NOT NULL,
  metric_value INTEGER NOT NULL,
  metric_unit TEXT NOT NULL,
  created_at TEXT NOT NULL,
  UNIQUE(user_id, client_session_id)
);

CREATE TABLE IF NOT EXISTS leaderboard_profiles (
  user_id TEXT PRIMARY KEY REFERENCES users(id),
  is_joined INTEGER NOT NULL,
  joined_at TEXT,
  left_at TEXT,
  updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS leaderboard_daily_totals (
  user_id TEXT NOT NULL REFERENCES users(id),
  exercise_type TEXT NOT NULL,
  ranking_date TEXT NOT NULL,
  total_value INTEGER NOT NULL,
  last_session_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  PRIMARY KEY(user_id, exercise_type, ranking_date)
);

CREATE INDEX IF NOT EXISTS workout_sessions_user_month_idx
ON workout_sessions(user_id, local_date);

CREATE INDEX IF NOT EXISTS leaderboard_daily_totals_query_idx
ON leaderboard_daily_totals(exercise_type, ranking_date, total_value DESC);
```

- [ ] **Step 4: Implement workout validation and ranking date**

Create `workers/membership-api/src/workouts.ts` with small pure helpers first:

```ts
import { membershipIsActive } from "./membership_state.js";
import { json, requireSession } from "./session.js";
import type { Env } from "./types.js";

type WorkoutInput = {
  clientSessionId: string;
  exerciseType: string;
  startedAt: string;
  endedAt: string;
  localDate: string;
  timezoneOffsetMinutes: number;
  metricValue: number;
  metricUnit: string;
};

export type SyncResult =
  | { clientSessionId: string; status: "accepted"; aggregated: boolean }
  | { clientSessionId: string; status: "duplicate" }
  | { clientSessionId: string; status: "rejected"; reason: string };

export function rankingDateForShanghai(endedAt: string): string {
  const value = Date.parse(endedAt);
  const shifted = new Date(value + 8 * 60 * 60 * 1000);
  return shifted.toISOString().slice(0, 10);
}

export function validateWorkout(input: WorkoutInput): string | null {
  if (input.exerciseType !== "pushup") return "invalid_exercise_type";
  if (input.metricUnit !== "reps") return "invalid_metric";
  if (!Number.isInteger(input.metricValue) || input.metricValue <= 0) {
    return "invalid_metric";
  }
  if (input.metricValue > 1000) return "daily_limit_exceeded";
  const started = Date.parse(input.startedAt);
  const ended = Date.parse(input.endedAt);
  if (!Number.isFinite(started) || !Number.isFinite(ended) || ended <= started) {
    return "invalid_duration";
  }
  if ((ended - started) / 1000 > 3 * 60 * 60) return "invalid_duration";
  return null;
}
```

- [ ] **Step 5: Implement route and idempotent writes**

In `workouts.ts`, add `syncWorkouts`:

```ts
export async function syncWorkouts(
  request: Request,
  env: Env,
): Promise<Response> {
  const session = await requireSession(env, request);
  if (session instanceof Response) return session;

  const body = (await request.json()) as { workouts?: WorkoutInput[] };
  const workouts = Array.isArray(body.workouts) ? body.workouts : [];
  const premium = await membershipActiveForUser(env, session.userId);
  const joined = await leaderboardProfile(env, session.userId);
  const results: SyncResult[] = [];

  for (const workout of workouts) {
    if (!premium) {
      results.push({
        clientSessionId: workout.clientSessionId,
        status: "rejected",
        reason: "premium_required",
      });
      continue;
    }
    const invalid = validateWorkout(workout);
    if (invalid) {
      results.push({
        clientSessionId: workout.clientSessionId,
        status: "rejected",
        reason: invalid,
      });
      continue;
    }

    const inserted = await insertWorkout(env, session.userId, workout);
    if (!inserted) {
      results.push({ clientSessionId: workout.clientSessionId, status: "duplicate" });
      continue;
    }

    const shouldAggregate =
      joined?.is_joined === 1 &&
      joined.joined_at !== null &&
      Date.parse(workout.endedAt) >= Date.parse(joined.joined_at);
    if (shouldAggregate) {
      await addDailyTotal(env, session.userId, workout);
    }
    results.push({
      clientSessionId: workout.clientSessionId,
      status: "accepted",
      aggregated: shouldAggregate,
    });
  }

  return json({ results });
}
```

Add these private helpers under `syncWorkouts`:

```ts
async function membershipActiveForUser(env: Env, userId: string): Promise<boolean> {
  const snapshot = await env.DB.prepare(
    "SELECT is_active, expires_at FROM membership_snapshots WHERE user_id = ?",
  )
    .bind(userId)
    .first<{ is_active: number; expires_at: string | null }>();
  return snapshot ? membershipIsActive(snapshot.is_active, snapshot.expires_at) : false;
}

async function leaderboardProfile(env: Env, userId: string) {
  return env.DB.prepare(
    "SELECT is_joined, joined_at FROM leaderboard_profiles WHERE user_id = ?",
  )
    .bind(userId)
    .first<{ is_joined: number; joined_at: string | null }>();
}

async function insertWorkout(
  env: Env,
  userId: string,
  workout: WorkoutInput,
): Promise<boolean> {
  const durationSeconds = Math.round(
    (Date.parse(workout.endedAt) - Date.parse(workout.startedAt)) / 1000,
  );
  const result = await env.DB.prepare(
    "INSERT OR IGNORE INTO workout_sessions (id, user_id, client_session_id, exercise_type, started_at, ended_at, duration_seconds, local_date, timezone_offset_minutes, ranking_date, metric_value, metric_unit, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
  )
    .bind(
      crypto.randomUUID(),
      userId,
      workout.clientSessionId,
      workout.exerciseType,
      workout.startedAt,
      workout.endedAt,
      durationSeconds,
      workout.localDate,
      workout.timezoneOffsetMinutes,
      rankingDateForShanghai(workout.endedAt),
      workout.metricValue,
      workout.metricUnit,
      new Date().toISOString(),
    )
    .run();
  return result.meta.changes === 1;
}

async function addDailyTotal(
  env: Env,
  userId: string,
  workout: WorkoutInput,
): Promise<void> {
  const now = new Date().toISOString();
  await env.DB.prepare(
    "INSERT INTO leaderboard_daily_totals (user_id, exercise_type, ranking_date, total_value, last_session_at, updated_at) VALUES (?, ?, ?, ?, ?, ?) ON CONFLICT(user_id, exercise_type, ranking_date) DO UPDATE SET total_value = total_value + excluded.total_value, last_session_at = excluded.last_session_at, updated_at = excluded.updated_at",
  )
    .bind(
      userId,
      workout.exerciseType,
      rankingDateForShanghai(workout.endedAt),
      workout.metricValue,
      workout.endedAt,
      now,
    )
    .run();
}
```

- [ ] **Step 6: Register route**

Modify `workers/membership-api/src/index.ts`:

```ts
import { syncWorkouts } from "./workouts.js";
```

Register:

```ts
if (request.method === "POST" && url.pathname === "/workouts/sync") {
  return syncWorkouts(request, env);
}
```

- [ ] **Step 7: Run Worker workout sync tests and all Worker tests**

Run:

```bash
cd workers/membership-api && npm test -- test/workout-sync.test.mjs
cd workers/membership-api && npm test
```

Expected: PASS.

- [ ] **Step 8: Commit**

Run:

```bash
git add workers/membership-api/schema.sql workers/membership-api/src/index.ts workers/membership-api/src/workouts.ts workers/membership-api/test/workout-sync.test.mjs
git commit -m "feat: add premium workout sync api"
```

---

## Task 5: Flutter Workout Sync Client And Controller

**Files:**
- Modify: `lib/platform/membership_api_client.dart`
- Modify: `lib/control/account_controller.dart`
- Create: `lib/control/workout_sync_controller.dart`
- Modify: `test/membership_api_client_test.dart`
- Create: `test/workout_sync_controller_test.dart`

- [ ] **Step 1: Write failing API client sync test**

Add to `test/membership_api_client_test.dart`:

```dart
test('syncWorkouts posts a batch and parses per-item results', () async {
  final client = MembershipApiClient(
    baseUrl: 'https://api.example.com',
    httpClient: MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.toString(), 'https://api.example.com/workouts/sync');
      expect(request.headers['authorization'], 'Bearer session_1');
      expect(request.body, contains('clientSessionId'));
      return http.Response(
        '''
        {
          "results": [
            {"clientSessionId": "s1", "status": "accepted", "aggregated": false}
          ]
        }
        ''',
        200,
        headers: {'content-type': 'application/json'},
      );
    }),
  );

  final results = await client.syncWorkouts('session_1', [
    WorkoutSyncRequest.fromSession(
      WorkoutSession(
        id: 's1',
        startedAt: DateTime.utc(2026, 7, 9, 1),
        endedAt: DateTime.utc(2026, 7, 9, 1, 3),
        count: 20,
      ),
    ),
  ]);

  expect(results.single.clientSessionId, 's1');
  expect(results.single.status, WorkoutSyncResultStatus.accepted);
});
```

- [ ] **Step 2: Run API client test and verify failure**

Run:

```bash
flutter test test/membership_api_client_test.dart
```

Expected: FAIL because sync request/result types do not exist.

- [ ] **Step 3: Implement request/result types and API method**

Add to `lib/platform/membership_api_client.dart`:

```dart
enum WorkoutSyncResultStatus { accepted, duplicate, rejected }

class WorkoutSyncRequest {
  const WorkoutSyncRequest({
    required this.clientSessionId,
    required this.exerciseType,
    required this.startedAt,
    required this.endedAt,
    required this.localDate,
    required this.timezoneOffsetMinutes,
    required this.metricValue,
    required this.metricUnit,
  });

  final String clientSessionId;
  final String exerciseType;
  final DateTime startedAt;
  final DateTime endedAt;
  final String localDate;
  final int timezoneOffsetMinutes;
  final int metricValue;
  final String metricUnit;

  factory WorkoutSyncRequest.fromSession(WorkoutSession session) {
    final local = session.startedAt.toLocal();
    return WorkoutSyncRequest(
      clientSessionId: session.id,
      exerciseType: session.exerciseType,
      startedAt: session.startedAt.toUtc(),
      endedAt: session.endedAt.toUtc(),
      localDate:
          '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}',
      timezoneOffsetMinutes: local.timeZoneOffset.inMinutes,
      metricValue: session.count,
      metricUnit: 'reps',
    );
  }

  Map<String, Object> toJson() => {
    'clientSessionId': clientSessionId,
    'exerciseType': exerciseType,
    'startedAt': startedAt.toIso8601String(),
    'endedAt': endedAt.toIso8601String(),
    'localDate': localDate,
    'timezoneOffsetMinutes': timezoneOffsetMinutes,
    'metricValue': metricValue,
    'metricUnit': metricUnit,
  };
}
```

Also add `WorkoutSyncResult` and `syncWorkouts(String sessionToken, List<WorkoutSyncRequest> workouts)`.

- [ ] **Step 4: Expose current session from AccountController**

Modify `lib/control/account_controller.dart`:

```dart
SavedAccountSession? get currentSession {
  final token = _sessionToken;
  final appUserId = _appUserId;
  if (token == null || appUserId == null) {
    return null;
  }
  return SavedAccountSession(sessionToken: token, appUserId: appUserId);
}
```

- [ ] **Step 5: Write failing sync controller tests**

Create `test/workout_sync_controller_test.dart`:

```dart
import 'package:test/test.dart';
import 'package:ugk_exercise/control/workout_sync_controller.dart';
import 'package:ugk_exercise/platform/account_session_store.dart';
import 'package:ugk_exercise/product/workout_session_store.dart';

void main() {
  test('queueAfterLocalSave does nothing for free or signed out account', () async {
    final store = MemoryWorkoutSessionStore();
    final controller = WorkoutSyncController(
      store: store,
      sessionProvider: () => null,
      premiumProvider: () => false,
      syncBatch: (_) async => const [],
    );

    await controller.queueAfterLocalSave('s1');

    expect(store.markForCloudSyncCalls, 0);
  });

  test('queueAfterLocalSave marks premium sessions pending without uploading inline', () async {
    final store = MemoryWorkoutSessionStore();
    final controller = WorkoutSyncController(
      store: store,
      sessionProvider: () => const SavedAccountSession(
        sessionToken: 'session_1',
        appUserId: 'user_1',
      ),
      premiumProvider: () => true,
      syncBatch: (_) async => throw StateError('must not upload inline'),
    );

    await controller.queueAfterLocalSave('s1');

    expect(store.markForCloudSyncCalls, 1);
  });
}
```

Add this fake store inside `test/workout_sync_controller_test.dart`:

```dart
class MemoryWorkoutSessionStore extends WorkoutSessionStore {
  var markForCloudSyncCalls = 0;

  @override
  Future<void> markForCloudSync(String id) async {
    markForCloudSyncCalls += 1;
  }
}
```

- [ ] **Step 6: Implement sync controller**

Create `lib/control/workout_sync_controller.dart`:

```dart
import '../platform/account_session_store.dart';
import '../platform/membership_api_client.dart';
import '../product/workout_session_store.dart';

typedef AccountSessionProvider = SavedAccountSession? Function();
typedef PremiumProvider = bool Function();
typedef WorkoutSyncBatch = Future<List<WorkoutSyncResult>> Function(
  List<WorkoutSyncRequest> workouts,
);

class WorkoutSyncController {
  WorkoutSyncController({
    required WorkoutSessionStore store,
    required AccountSessionProvider sessionProvider,
    required PremiumProvider premiumProvider,
    required WorkoutSyncBatch syncBatch,
  }) : _store = store,
       _sessionProvider = sessionProvider,
       _premiumProvider = premiumProvider,
       _syncBatch = syncBatch;

  final WorkoutSessionStore _store;
  final AccountSessionProvider _sessionProvider;
  final PremiumProvider _premiumProvider;
  final WorkoutSyncBatch _syncBatch;

  Future<void> queueAfterLocalSave(String sessionId) async {
    if (_sessionProvider() == null || !_premiumProvider()) {
      return;
    }
    await _store.markForCloudSync(sessionId);
  }

  Future<void> syncPending() async {
    final account = _sessionProvider();
    if (account == null || !_premiumProvider()) {
      return;
    }
    final sessions = await _store.pendingCloudSync();
    if (sessions.isEmpty) {
      return;
    }
    final results = await _syncBatch([
      for (final session in sessions) WorkoutSyncRequest.fromSession(session),
    ]);
    final now = DateTime.now();
    for (final result in results) {
      if (result.status == WorkoutSyncResultStatus.accepted ||
          result.status == WorkoutSyncResultStatus.duplicate) {
        await _store.markCloudSynced(result.clientSessionId, now);
      } else {
        await _store.markCloudSyncFailed(result.clientSessionId);
      }
    }
  }
}
```

- [ ] **Step 7: Run touched Flutter tests**

Run:

```bash
flutter test test/membership_api_client_test.dart test/account_controller_test.dart test/workout_sync_controller_test.dart
```

Expected: PASS.

- [ ] **Step 8: Commit**

Run:

```bash
git add lib/platform/membership_api_client.dart lib/control/account_controller.dart lib/control/workout_sync_controller.dart test/membership_api_client_test.dart test/account_controller_test.dart test/workout_sync_controller_test.dart
git commit -m "feat: add workout sync controller"
```

---

## Task 6: Non-Blocking Workout Sync Integration

**Files:**
- Modify: `lib/main.dart`
- Modify: `lib/ui/pages/home_page.dart`
- Modify: `lib/ui/pages/workout_page.dart`
- Modify: `test/workout_page_test.dart`

- [ ] **Step 1: Write failing workout page non-blocking test**

Modify `test/workout_page_test.dart` to cover sync failure not blocking local save:

```dart
testWidgets('cloud sync queue failure does not block leaving workout page', (tester) async {
  final store = _RecordingSessionStore();
  final sync = _ThrowingWorkoutSyncController();

  await tester.pumpWidget(
    MaterialApp(
      home: WorkoutPage(store: store, syncController: sync),
    ),
  );

  await tester.tap(find.text('结束训练'));
  await tester.pumpAndSettle();

  expect(store.appendCalls, 1);
  expect(sync.queueCalls, 1);
  expect(find.byType(WorkoutPage), findsNothing);
});
```

Add this fake sync controller inside `test/workout_page_test.dart` and pass it through the existing page harness:

```dart
class _ThrowingWorkoutSyncController extends WorkoutSyncController {
  _ThrowingWorkoutSyncController()
    : super(
        store: WorkoutSessionStore(),
        sessionProvider: () => null,
        premiumProvider: () => false,
        syncBatch: (_) async => const [],
      );

  var queueCalls = 0;

  @override
  Future<void> queueAfterLocalSave(String sessionId) async {
    queueCalls += 1;
    throw Exception('sync failed');
  }
}
```

- [ ] **Step 2: Run workout page test and verify failure**

Run:

```bash
flutter test test/workout_page_test.dart
```

Expected: FAIL because `WorkoutPage` has no `syncController`.

- [ ] **Step 3: Add optional sync controller to WorkoutPage**

Modify `lib/ui/pages/workout_page.dart` constructor:

```dart
const WorkoutPage({
  super.key,
  required this.store,
  this.syncController,
});

final WorkoutSessionStore store;
final WorkoutSyncController? syncController;
```

After `await widget.store.append(session);`, queue sync without blocking local completion:

```dart
try {
  await widget.syncController?.queueAfterLocalSave(session.id);
} catch (_) {
  // Cloud sync must not block local workout completion.
}
```

Keep `_pendingSession = null` and `Navigator.pop()` behavior unchanged.

- [ ] **Step 4: Wire sync controller through HomePage**

Modify `HomePage` constructor to accept `WorkoutSyncController? syncController`.

Pass it to `WorkoutPage`:

```dart
builder: (_) => WorkoutPage(
  store: _store,
  syncController: widget.syncController,
),
```

- [ ] **Step 5: Wire from main**

In `lib/main.dart`, create `WorkoutSyncController` after `AccountController` and pass it to `HomePage`.

The `syncBatch` closure should call:

```dart
final account = accountController.currentSession;
if (account == null) return const <WorkoutSyncResult>[];
return apiClient.syncWorkouts(account.sessionToken, workouts);
```

- [ ] **Step 6: Run tests**

Run:

```bash
flutter test test/workout_page_test.dart test/workout_sync_controller_test.dart
```

Expected: PASS.

- [ ] **Step 7: Commit**

Run:

```bash
git add lib/main.dart lib/ui/pages/home_page.dart lib/ui/pages/workout_page.dart test/workout_page_test.dart
git commit -m "feat: queue workout sync after local save"
```

---

## Task 7: Worker Leaderboard Join, Leave, And Query

**Files:**
- Modify: `workers/membership-api/src/index.ts`
- Create: `workers/membership-api/src/leaderboard.ts`
- Create: `workers/membership-api/test/leaderboard.test.mjs`

- [ ] **Step 1: Write failing leaderboard tests**

Create `workers/membership-api/test/leaderboard.test.mjs`:

```js
import assert from "node:assert/strict";
import test from "node:test";

import {
  rowsForLeaderboardForTest,
  weekRangeForShanghai,
} from "../.tmp-test/leaderboard.js";

test("weekRangeForShanghai returns current Monday through Sunday", () => {
  assert.deepEqual(weekRangeForShanghai("2026-07-09T12:00:00.000Z"), {
    start: "2026-07-06",
    end: "2026-07-12",
  });
});

test("leaderboard rows include top rows and my rank outside top list", () => {
  const rows = rowsForLeaderboardForTest({
    totals: [
      { userId: "u1", total: 100 },
      { userId: "u2", total: 90 },
      { userId: "me", total: 10 },
    ],
    me: "me",
    limit: 2,
  });

  assert.deepEqual(rows.top.map((row) => row.userId), ["u1", "u2"]);
  assert.equal(rows.me.userId, "me");
  assert.equal(rows.me.rank, 3);
});
```

- [ ] **Step 2: Run leaderboard tests and verify failure**

Run:

```bash
cd workers/membership-api && npm test -- test/leaderboard.test.mjs
```

Expected: FAIL because `leaderboard.ts` does not exist.

- [ ] **Step 3: Implement leaderboard helpers and routes**

Create `workers/membership-api/src/leaderboard.ts` with:

```ts
import { json, requireSession } from "./session.js";
import type { Env } from "./types.js";

export function weekRangeForShanghai(nowIso: string): { start: string; end: string } {
  const shifted = new Date(Date.parse(nowIso) + 8 * 60 * 60 * 1000);
  const day = shifted.getUTCDay() || 7;
  const monday = new Date(shifted);
  monday.setUTCDate(shifted.getUTCDate() - day + 1);
  const sunday = new Date(monday);
  sunday.setUTCDate(monday.getUTCDate() + 6);
  return {
    start: monday.toISOString().slice(0, 10),
    end: sunday.toISOString().slice(0, 10),
  };
}
```

Add these route functions:

```ts
export async function joinLeaderboard(
  request: Request,
  env: Env,
): Promise<Response> {
  const session = await requireSession(env, request);
  if (session instanceof Response) return session;
  if (!(await membershipActiveForUser(env, session.userId))) {
    return json({ error: "premium_required" }, 403);
  }
  const now = new Date().toISOString();
  await env.DB.prepare(
    "INSERT INTO leaderboard_profiles (user_id, is_joined, joined_at, left_at, updated_at) VALUES (?, 1, ?, NULL, ?) ON CONFLICT(user_id) DO UPDATE SET is_joined = 1, joined_at = excluded.joined_at, left_at = NULL, updated_at = excluded.updated_at",
  )
    .bind(session.userId, now, now)
    .run();
  return json({ ok: true, joinedAt: now });
}

export async function leaveLeaderboard(
  request: Request,
  env: Env,
): Promise<Response> {
  const session = await requireSession(env, request);
  if (session instanceof Response) return session;
  const now = new Date().toISOString();
  await env.DB.prepare(
    "INSERT INTO leaderboard_profiles (user_id, is_joined, joined_at, left_at, updated_at) VALUES (?, 0, NULL, ?, ?) ON CONFLICT(user_id) DO UPDATE SET is_joined = 0, left_at = excluded.left_at, updated_at = excluded.updated_at",
  )
    .bind(session.userId, now, now)
    .run();
  return json({ ok: true });
}

export async function getLeaderboard(
  request: Request,
  env: Env,
): Promise<Response> {
  const session = await requireSession(env, request);
  if (session instanceof Response) return session;
  const url = new URL(request.url);
  const period = url.searchParams.get("period") ?? "day";
  const exerciseType = url.searchParams.get("exerciseType") ?? "pushup";
  if (exerciseType !== "pushup" || (period !== "day" && period !== "week")) {
    return json({ error: "invalid_leaderboard_query" }, 400);
  }
  const now = new Date().toISOString();
  const rows =
    period === "day"
      ? await dayRows(env, exerciseType, rankingDateForShanghai(now))
      : await weekRows(env, exerciseType, weekRangeForShanghai(now));
  const ranked = rowsForLeaderboardForTest({
    totals: rows.map((row) => ({ userId: row.user_id, total: row.total_value })),
    me: session.userId,
    limit: 100,
  });
  return json({
    period,
    exerciseType,
    top: ranked.top,
    me: ranked.me,
  });
}
```

Use D1 `SUM(total_value)` grouped by user for the week query:

```sql
SELECT user_id, SUM(total_value) AS total_value
FROM leaderboard_daily_totals
WHERE exercise_type = ? AND ranking_date BETWEEN ? AND ?
GROUP BY user_id
ORDER BY total_value DESC
LIMIT 100
```

- [ ] **Step 4: Register routes**

Modify `workers/membership-api/src/index.ts`:

```ts
import {
  getLeaderboard,
  joinLeaderboard,
  leaveLeaderboard,
} from "./leaderboard.js";
```

Register:

```ts
if (request.method === "POST" && url.pathname === "/leaderboard/join") {
  return joinLeaderboard(request, env);
}
if (request.method === "POST" && url.pathname === "/leaderboard/leave") {
  return leaveLeaderboard(request, env);
}
if (request.method === "GET" && url.pathname === "/leaderboard") {
  return getLeaderboard(request, env);
}
```

- [ ] **Step 5: Run Worker tests**

Run:

```bash
cd workers/membership-api && npm test -- test/leaderboard.test.mjs
cd workers/membership-api && npm test
```

Expected: PASS.

- [ ] **Step 6: Commit**

Run:

```bash
git add workers/membership-api/src/index.ts workers/membership-api/src/leaderboard.ts workers/membership-api/test/leaderboard.test.mjs
git commit -m "feat: add sports plaza leaderboard api"
```

---

## Task 8: Flutter Leaderboard Models, API, And Controller

**Files:**
- Create: `lib/product/leaderboard_models.dart`
- Modify: `lib/platform/membership_api_client.dart`
- Create: `lib/control/leaderboard_controller.dart`
- Modify: `test/membership_api_client_test.dart`
- Create: `test/leaderboard_controller_test.dart`

- [ ] **Step 1: Write failing leaderboard model/API tests**

Add to `test/membership_api_client_test.dart`:

```dart
test('leaderboard request parses top rows and my rank', () async {
  final client = MembershipApiClient(
    baseUrl: 'https://api.example.com',
    httpClient: MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.toString(), contains('/leaderboard?'));
      return http.Response(
        '''
        {
          "period": "day",
          "exerciseType": "pushup",
          "top": [
            {"rank": 1, "userId": "u1", "nickname": "A", "avatarKey": "ring-green", "totalValue": 80}
          ],
          "me": {"rank": 12, "userId": "me", "nickname": "我", "avatarKey": "ring-lime", "totalValue": 20}
        }
        ''',
        200,
        headers: {'content-type': 'application/json'},
      );
    }),
  );

  final board = await client.leaderboard(
    'session_1',
    period: LeaderboardPeriod.day,
    exerciseType: 'pushup',
  );

  expect(board.top.single.rank, 1);
  expect(board.me?.rank, 12);
});
```

- [ ] **Step 2: Run test and verify failure**

Run:

```bash
flutter test test/membership_api_client_test.dart
```

Expected: FAIL because leaderboard models/API are missing.

- [ ] **Step 3: Add leaderboard models**

Create `lib/product/leaderboard_models.dart`:

```dart
enum LeaderboardPeriod { day, week }

class LeaderboardRow {
  const LeaderboardRow({
    required this.rank,
    required this.userId,
    required this.nickname,
    required this.avatarKey,
    required this.totalValue,
  });

  final int rank;
  final String userId;
  final String nickname;
  final String? avatarKey;
  final int totalValue;

  static LeaderboardRow fromJson(Map<String, Object?> json) {
    return LeaderboardRow(
      rank: json['rank']! as int,
      userId: json['userId']! as String,
      nickname: json['nickname']! as String,
      avatarKey: json['avatarKey'] as String?,
      totalValue: json['totalValue']! as int,
    );
  }
}

class LeaderboardSnapshot {
  const LeaderboardSnapshot({
    required this.period,
    required this.exerciseType,
    required this.top,
    required this.me,
  });

  final LeaderboardPeriod period;
  final String exerciseType;
  final List<LeaderboardRow> top;
  final LeaderboardRow? me;

  static LeaderboardSnapshot fromJson(Map<String, Object?> json) {
    final periodName = json['period']! as String;
    return LeaderboardSnapshot(
      period: LeaderboardPeriod.values.byName(periodName),
      exerciseType: json['exerciseType']! as String,
      top: [
        for (final item in json['top']! as List<Object?>)
          LeaderboardRow.fromJson(Map<String, Object?>.from(item! as Map)),
      ],
      me: json['me'] == null
          ? null
          : LeaderboardRow.fromJson(
              Map<String, Object?>.from(json['me']! as Map),
            ),
    );
  }
}
```

- [ ] **Step 4: Add API client methods**

Modify `lib/platform/membership_api_client.dart`:

```dart
Future<LeaderboardSnapshot> leaderboard(
  String sessionToken, {
  required LeaderboardPeriod period,
  required String exerciseType,
}) async {
  final response = await _httpClient.get(
    _baseUri.resolve(
      'leaderboard?period=${period.name}&exerciseType=$exerciseType',
    ),
    headers: {'authorization': 'Bearer $sessionToken'},
  );
  return LeaderboardSnapshot.fromJson(_parseJson(response));
}

Future<void> joinLeaderboard(String sessionToken) async {
  await _parseJson(await _httpClient.post(
    _baseUri.resolve('leaderboard/join'),
    headers: {'authorization': 'Bearer $sessionToken'},
  ));
}

Future<void> leaveLeaderboard(String sessionToken) async {
  await _parseJson(await _httpClient.post(
    _baseUri.resolve('leaderboard/leave'),
    headers: {'authorization': 'Bearer $sessionToken'},
  ));
}
```

- [ ] **Step 5: Write and implement controller tests**

Create `test/leaderboard_controller_test.dart`:

```dart
import 'package:test/test.dart';
import 'package:ugk_exercise/control/leaderboard_controller.dart';
import 'package:ugk_exercise/platform/account_session_store.dart';
import 'package:ugk_exercise/product/leaderboard_models.dart';

void main() {
  test('load ignores signed out users', () async {
    final controller = LeaderboardController(
      sessionProvider: () => null,
      load: (_, __) async => throw StateError('must not load'),
      join: () async {},
      leave: () async {},
    );

    await controller.load(LeaderboardPeriod.day);

    expect(controller.snapshot, isNull);
  });

  test('load stores snapshot for signed in users', () async {
    final controller = LeaderboardController(
      sessionProvider: () => const SavedAccountSession(
        sessionToken: 'session_1',
        appUserId: 'user_1',
      ),
      load: (_, __) async => const LeaderboardSnapshot(
        period: LeaderboardPeriod.day,
        exerciseType: 'pushup',
        top: [],
        me: null,
      ),
      join: () async {},
      leave: () async {},
    );

    await controller.load(LeaderboardPeriod.day);

    expect(controller.snapshot?.period, LeaderboardPeriod.day);
  });
}
```

Create `lib/control/leaderboard_controller.dart`:

```dart
import 'package:flutter/foundation.dart';

import '../platform/account_session_store.dart';
import '../product/leaderboard_models.dart';

typedef LeaderboardSessionProvider = SavedAccountSession? Function();
typedef LeaderboardLoad = Future<LeaderboardSnapshot> Function(
  String sessionToken,
  LeaderboardPeriod period,
);
typedef LeaderboardCommand = Future<void> Function(String sessionToken);

class LeaderboardController extends ChangeNotifier {
  LeaderboardController({
    required LeaderboardSessionProvider sessionProvider,
    required LeaderboardLoad load,
    required LeaderboardCommand join,
    required LeaderboardCommand leave,
  }) : _sessionProvider = sessionProvider,
       _load = load,
       _join = join,
       _leave = leave;

  final LeaderboardSessionProvider _sessionProvider;
  final LeaderboardLoad _load;
  final LeaderboardCommand _join;
  final LeaderboardCommand _leave;

  LeaderboardSnapshot? _snapshot;
  var _busy = false;
  String? _error;

  LeaderboardSnapshot? get snapshot => _snapshot;
  bool get busy => _busy;
  String? get error => _error;

  Future<void> load(LeaderboardPeriod period) async {
    final session = _sessionProvider();
    if (session == null) {
      _snapshot = null;
      notifyListeners();
      return;
    }
    await _run(() async {
      _snapshot = await _load(session.sessionToken, period);
    });
  }

  Future<void> join() async {
    final session = _sessionProvider();
    if (session == null) return;
    await _run(() => _join(session.sessionToken));
  }

  Future<void> leave() async {
    final session = _sessionProvider();
    if (session == null) return;
    await _run(() => _leave(session.sessionToken));
  }

  Future<void> _run(Future<void> Function() action) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await action();
    } catch (error) {
      _error = error.toString();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}
```

- [ ] **Step 6: Run tests**

Run:

```bash
flutter test test/membership_api_client_test.dart test/leaderboard_controller_test.dart
```

Expected: PASS.

- [ ] **Step 7: Commit**

Run:

```bash
git add lib/product/leaderboard_models.dart lib/platform/membership_api_client.dart lib/control/leaderboard_controller.dart test/membership_api_client_test.dart test/leaderboard_controller_test.dart
git commit -m "feat: add leaderboard client controller"
```

---

## Task 9: Profile UI For Nickname And Built-In Avatar

**Files:**
- Modify: `lib/control/account_controller.dart`
- Modify: `lib/ui/pages/profile_page.dart`
- Modify: `lib/l10n/app_zh.arb`
- Modify: `lib/l10n/app_en.arb`
- Modify: `test/account_controller_test.dart`
- Modify: `test/profile_page_test.dart`

- [ ] **Step 1: Write failing account controller profile update test**

Add to `test/account_controller_test.dart`:

```dart
test('updateProfile refreshes current user', () async {
  final api = _FakeMembershipApiClient();
  final controller = AccountController(
    sessionStore: MemoryAccountSessionStore(),
    apiClient: api,
    revenueCat: FakeRevenueCatService(isPremium: false),
    googleSignIn: () async => 'google-token',
  );
  await controller.signIn();

  await controller.updateProfile(nickname: '训练者 01', avatarKey: 'ring-green');

  expect(controller.user?.publicDisplayName, '训练者 01');
  expect(controller.user?.avatarKey, 'ring-green');
});
```

Update `_FakeMembershipApiClient` with an override for `updateProfile`.

- [ ] **Step 2: Implement AccountController command**

Add to `lib/control/account_controller.dart`:

```dart
Future<void> updateProfile({
  required String nickname,
  required String avatarKey,
}) async {
  await _run(() async {
    final token = _sessionToken;
    if (token == null) {
      return;
    }
    _user = await _apiClient.updateProfile(
      token,
      nickname: nickname,
      avatarKey: avatarKey,
    );
  });
}
```

- [ ] **Step 3: Write profile page widget test**

Add to `test/profile_page_test.dart`:

```dart
testWidgets('signed in profile shows public name and edit profile action', (tester) async {
  final controller = _FakeAccountController.signedIn(
    user: const AppUser(
      id: 'user_1',
      displayName: 'Google Name',
      email: 'a@example.com',
      avatarUrl: null,
      nickname: '训练者 01',
      avatarKey: 'ring-green',
    ),
  );

  await tester.pumpWidget(MaterialApp(home: ProfilePage(controller: controller)));

  expect(find.text('训练者 01'), findsOneWidget);
  expect(find.text('编辑资料'), findsOneWidget);
});
```

- [ ] **Step 4: Implement minimal profile UI**

In `lib/ui/pages/profile_page.dart`:

- Show `user.publicDisplayName`.
- Render an internal avatar widget when `user.avatarKey != null`.
- Add an `OutlinedButton.icon` labeled `编辑资料`.
- On tap, show a bottom sheet with:
  - `TextField` for nickname.
  - Fixed avatar choices: `ring-green`, `ring-lime`, `ring-sky`, `ring-yellow`, `ring-coral`, `bolt-green`, `bolt-lime`, `bolt-sky`.
  - Save button calls `controller.updateProfile(...)`.

Use local helper widgets inside `profile_page.dart`; do not create shared widgets yet.

- [ ] **Step 5: Run profile tests**

Run:

```bash
flutter test test/account_controller_test.dart test/profile_page_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit**

Run:

```bash
git add lib/control/account_controller.dart lib/ui/pages/profile_page.dart lib/l10n/app_zh.arb lib/l10n/app_en.arb test/account_controller_test.dart test/profile_page_test.dart
git commit -m "feat: add editable account profile"
```

---

## Task 10: Sports Plaza Home Card And Leaderboard Page

**Files:**
- Modify: `lib/main.dart`
- Modify: `lib/ui/pages/home_page.dart`
- Create: `lib/ui/pages/leaderboard_page.dart`
- Modify: `lib/l10n/app_zh.arb`
- Modify: `lib/l10n/app_en.arb`
- Create: `test/leaderboard_page_test.dart`

- [ ] **Step 1: Write leaderboard page widget tests**

Create `test/leaderboard_page_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ugk_exercise/product/leaderboard_models.dart';
import 'package:ugk_exercise/ui/pages/leaderboard_page.dart';

void main() {
  testWidgets('leaderboard page shows top rows and my rank', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LeaderboardPage(
          snapshot: const LeaderboardSnapshot(
            period: LeaderboardPeriod.day,
            exerciseType: 'pushup',
            top: [
              LeaderboardRow(
                rank: 1,
                userId: 'u1',
                nickname: 'A',
                avatarKey: 'ring-green',
                totalValue: 80,
              ),
            ],
            me: LeaderboardRow(
              rank: 12,
              userId: 'me',
              nickname: '我',
              avatarKey: 'ring-lime',
              totalValue: 20,
            ),
          ),
        ),
      ),
    );

    expect(find.text('运动广场'), findsOneWidget);
    expect(find.text('A'), findsOneWidget);
    expect(find.text('我的排名'), findsOneWidget);
    expect(find.text('第 12 名'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run widget test and verify failure**

Run:

```bash
flutter test test/leaderboard_page_test.dart
```

Expected: FAIL because `LeaderboardPage` does not exist.

- [ ] **Step 3: Implement LeaderboardPage**

Create `lib/ui/pages/leaderboard_page.dart`.

Keep it simple:

- AppBar title `运动广场`.
- Segmented day/week control.
- List rows with rank, avatar, nickname, total reps.
- Bottom pinned my rank panel if `snapshot.me != null`.
- Join prompt when controller says not joined.

Implement the page with a `LeaderboardSnapshot? snapshot` for tests and a controller for production:

```dart
class LeaderboardPage extends StatelessWidget {
  const LeaderboardPage({
    super.key,
    this.controller,
    this.snapshot,
  });

  final LeaderboardController? controller;
  final LeaderboardSnapshot? snapshot;
}
```

- [ ] **Step 4: Add home sports plaza card**

Modify `lib/ui/pages/home_page.dart`:

- Add optional `LeaderboardController? leaderboardController`.
- Add `_SportsPlazaCard` below `_ExerciseCard`.
- Card copy:
  - Title: `运动广场`
  - Subtitle: `俯卧撑项目日榜`
  - Button: `查看榜单`
- Navigate to `LeaderboardPage(controller: widget.leaderboardController)`.

Keep card visually weaker than the training card.

- [ ] **Step 5: Wire controller in main**

Modify `lib/main.dart` to create and pass `LeaderboardController`.

- [ ] **Step 6: Run UI tests**

Run:

```bash
flutter test test/leaderboard_page_test.dart
flutter test test/profile_page_test.dart
```

Expected: PASS.

- [ ] **Step 7: Commit**

Run:

```bash
git add lib/main.dart lib/ui/pages/home_page.dart lib/ui/pages/leaderboard_page.dart lib/l10n/app_zh.arb lib/l10n/app_en.arb test/leaderboard_page_test.dart
git commit -m "feat: add sports plaza leaderboard ui"
```

---

## Task 11: Records Cloud Merge And Sync Status

**Files:**
- Modify: `lib/platform/membership_api_client.dart`
- Modify: `lib/ui/pages/records_page.dart`
- Modify: `test/membership_api_client_test.dart`
- Modify: `test/workout_session_store_test.dart`

- [ ] **Step 1: Write failing cloud workouts API test**

Add to `test/membership_api_client_test.dart`:

```dart
test('cloudWorkouts fetches month sessions', () async {
  final client = MembershipApiClient(
    baseUrl: 'https://api.example.com',
    httpClient: MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.toString(), 'https://api.example.com/workouts?month=2026-07');
      return http.Response(
        '''
        {
          "workouts": [
            {
              "clientSessionId": "s1",
              "exerciseType": "pushup",
              "startedAt": "2026-07-09T01:00:00.000Z",
              "endedAt": "2026-07-09T01:03:00.000Z",
              "metricValue": 20,
              "metricUnit": "reps"
            }
          ]
        }
        ''',
        200,
        headers: {'content-type': 'application/json'},
      );
    }),
  );

  final sessions = await client.cloudWorkouts('session_1', month: '2026-07');

  expect(sessions.single.id, 's1');
  expect(sessions.single.count, 20);
});
```

- [ ] **Step 2: Implement cloud workouts fetch**

Add `cloudWorkouts` to `MembershipApiClient`. Convert server rows to `WorkoutSession` with `syncStatus: WorkoutSyncStatus.synced`.

- [ ] **Step 3: Add records page sync status**

Modify `RecordsPage` to accept optional cloud sessions and pending sync count through constructor for testability:

```dart
const RecordsPage({
  super.key,
  required this.store,
  this.cloudSessionsFuture,
  this.pendingSyncCountFuture,
});
```

Merge local and cloud by id:

```dart
final byId = <String, WorkoutSession>{
  for (final session in localSessions) session.id: session,
  for (final session in cloudSessions) session.id: session,
};
```

Use the merged list for monthly totals.

- [ ] **Step 4: Add focused records merge test**

Add to `test/workout_session_store_test.dart` or create `test/records_merge_test.dart`:

```dart
test('merge keeps one session per id and preserves cloud-only sessions', () {
  final merged = mergeWorkoutSessions(
    local: [
      WorkoutSession(
        id: 'same',
        startedAt: DateTime(2026, 7, 9, 8),
        endedAt: DateTime(2026, 7, 9, 8, 3),
        count: 10,
      ),
    ],
    cloud: [
      WorkoutSession(
        id: 'same',
        startedAt: DateTime(2026, 7, 9, 8),
        endedAt: DateTime(2026, 7, 9, 8, 3),
        count: 10,
        syncStatus: WorkoutSyncStatus.synced,
      ),
      WorkoutSession(
        id: 'cloud-only',
        startedAt: DateTime(2026, 7, 10, 8),
        endedAt: DateTime(2026, 7, 10, 8, 3),
        count: 8,
      ),
    ],
  );

  expect(merged.map((session) => session.id), ['same', 'cloud-only']);
});
```

Put `mergeWorkoutSessions` in `lib/product/workout_session_store.dart`:

```dart
List<WorkoutSession> mergeWorkoutSessions({
  required List<WorkoutSession> local,
  required List<WorkoutSession> cloud,
}) {
  final byId = <String, WorkoutSession>{
    for (final session in local) session.id: session,
  };
  for (final session in cloud) {
    byId[session.id] = session;
  }
  final merged = byId.values.toList()
    ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
  return merged;
}
```

- [ ] **Step 5: Run tests**

Run:

```bash
flutter test test/membership_api_client_test.dart test/workout_session_store_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit**

Run:

```bash
git add lib/platform/membership_api_client.dart lib/product/workout_session_store.dart lib/ui/pages/records_page.dart test/membership_api_client_test.dart test/workout_session_store_test.dart
git commit -m "feat: merge cloud workout records"
```

---

## Task 12: Full Verification

**Files:**
- No intended source changes unless verification finds defects.

- [ ] **Step 1: Run Flutter analysis**

Run:

```bash
flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 2: Run Flutter tests**

Run:

```bash
flutter test
```

Expected: all tests pass, including replay baseline tests.

- [ ] **Step 3: Run Worker tests**

Run:

```bash
cd workers/membership-api && npm test
```

Expected: all Worker tests pass.

- [ ] **Step 4: Inspect git diff**

Run:

```bash
git status --short
git diff --stat
```

Expected: no uncommitted source changes except intentionally untracked handoff documents or local cache files.

- [ ] **Step 5: Record verification**

If all checks pass, add a short note to the final response with:

- `flutter analyze`
- `flutter test`
- `cd workers/membership-api && npm test`

Do not stage `docs/handoff-account-features.md` unless the user explicitly asks.
