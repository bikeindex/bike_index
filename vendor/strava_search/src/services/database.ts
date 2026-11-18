import Dexie, { type Table, type Transaction } from 'dexie';
import type { StravaActivity, StravaGear, StoredAuth } from '../types/strava';

// Strava IDs are 64-bit and can pass Number.MAX_SAFE_INTEGER, so they stay strings
export interface StoredActivity extends StravaActivity {
  id: string; // strava_id, used as Dexie primary key
  athleteId: string;
  syncedAt: number;
}

export interface StoredGear extends StravaGear {
  athleteId: string;
}

export interface SyncState {
  athleteId: string;
  lastSyncedAt: number;
  oldestActivityDate: string | null;
  isInitialSyncComplete: boolean;
}

const SCHEMA = {
  activities: 'id, athleteId, title, activity_type, sport_type, gear_id, start_date_in_zone, [athleteId+start_date_in_zone]',
  gear: 'id, athleteId',
  auth: 'id',
  syncState: 'athleteId',
};

// A primary key can't be modified in place, so each table is rewritten
async function rewriteTable<T>(transaction: Transaction, name: string, convert: (row: T) => T): Promise<void> {
  const table = transaction.table<T>(name);
  const rows = await table.toArray();
  await table.clear();
  await table.bulkAdd(rows.map(convert));
}

class StravaDatabase extends Dexie {
  activities!: Table<StoredActivity, string>;
  gear!: Table<StoredGear, string>;
  auth!: Table<StoredAuth & { id: string }, string>;
  syncState!: Table<SyncState, string>;

  constructor() {
    super('StravaSearchDB');

    this.version(1).stores(SCHEMA);
    this.version(2).stores(SCHEMA).upgrade(async (transaction) => {
      await rewriteTable<StoredActivity>(transaction, 'activities', (activity) => ({
        ...activity,
        id: activity.strava_id,
        athleteId: String(activity.athleteId),
      }));
      await rewriteTable<StoredGear>(transaction, 'gear', (gear) => ({ ...gear, athleteId: String(gear.athleteId) }));
      await rewriteTable<SyncState>(transaction, 'syncState', (state) => ({ ...state, athleteId: String(state.athleteId) }));
      await rewriteTable<StoredAuth & { id: string }>(transaction, 'auth', (auth) => ({
        ...auth,
        id: String(auth.id),
        athlete: { ...auth.athlete, id: String(auth.athlete.id) },
      }));
    });
  }
}

export const db = new StravaDatabase();

export async function saveActivities(activities: StravaActivity[], athleteId: string): Promise<void> {
  const storedActivities: StoredActivity[] = activities.map((activity) => ({
    ...activity,
    id: activity.strava_id,
    athleteId,
    syncedAt: Date.now(),
  }));

  await db.activities.bulkPut(storedActivities);
}

export async function getActivitiesForAthlete(athleteId: string): Promise<StoredActivity[]> {
  return db.activities.where('athleteId').equals(athleteId).toArray();
}

export async function getActivityById(id: string): Promise<StoredActivity | undefined> {
  return db.activities.get(id);
}

export async function updateActivityInDb(id: string, updates: Partial<StoredActivity>): Promise<void> {
  await db.activities.update(id, { ...updates, syncedAt: Date.now() });
}

export async function saveGear(gear: StravaGear[], athleteId: string): Promise<void> {
  const storedGear: StoredGear[] = gear.map((g) => ({
    ...g,
    athleteId,
  }));

  await db.gear.bulkPut(storedGear);
}

export async function getGearForAthlete(athleteId: string): Promise<StoredGear[]> {
  return db.gear.where('athleteId').equals(athleteId).toArray();
}

export async function saveAuth(auth: StoredAuth): Promise<void> {
  await db.transaction('rw', db.auth, async () => {
    await db.auth.clear();
    await db.auth.put({ ...auth, id: auth.athlete.id });
  });
}

export async function getAuth(): Promise<(StoredAuth & { id: string }) | undefined> {
  const auths = await db.auth.toArray();
  return auths[0];
}

export async function clearAuth(): Promise<void> {
  await db.auth.clear();
}

export async function getSyncState(athleteId: string): Promise<SyncState | undefined> {
  return db.syncState.get(athleteId);
}

export async function updateSyncState(state: SyncState): Promise<void> {
  await db.syncState.put(state);
}

export async function clearAllData(): Promise<void> {
  await Promise.all([
    db.activities.clear(),
    db.gear.clear(),
    db.auth.clear(),
    db.syncState.clear(),
  ]);
}
