import Dexie, { type Table } from 'dexie';
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

class StravaDatabase extends Dexie {
  activities!: Table<StoredActivity, string>;
  gear!: Table<StoredGear, string>;
  auth!: Table<StoredAuth & { id: string }, string>;
  syncState!: Table<SyncState, string>;

  constructor() {
    super('StravaSearchDB');

    this.version(1).stores({
      activities: 'id, athleteId, title, activity_type, sport_type, gear_id, start_date_in_zone, [athleteId+start_date_in_zone]',
      gear: 'id, athleteId',
      auth: 'id',
      syncState: 'athleteId',
    });
    // Version 1 keyed rows by Number IDs. Everything here re-syncs from Bike Index when empty
    this.version(2).upgrade((transaction) =>
      Promise.all(transaction.storeNames.map((name) => transaction.table(name).clear()))
    );
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

const AUTH_KEY = 'current';

export async function saveAuth(auth: StoredAuth): Promise<void> {
  await db.auth.put({ ...auth, id: AUTH_KEY });
}

export async function getAuth(): Promise<(StoredAuth & { id: string }) | undefined> {
  return db.auth.get(AUTH_KEY);
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
