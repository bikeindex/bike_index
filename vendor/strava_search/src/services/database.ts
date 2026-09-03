import Dexie, { type Table } from 'dexie';
import type { StravaActivity, StravaGear, StoredAuth } from '../types/strava';

export interface StoredActivity extends StravaActivity {
  id: number; // parsed from strava_id, used as Dexie primary key
  athleteId: number;
  syncedAt: number;
}

export interface StoredGear extends StravaGear {
  athleteId: number;
}

export interface SyncState {
  athleteId: number;
  lastSyncedAt: number;
  oldestActivityDate: string | null;
  isInitialSyncComplete: boolean;
}

class StravaDatabase extends Dexie {
  activities!: Table<StoredActivity, number>;
  gear!: Table<StoredGear, string>;
  auth!: Table<StoredAuth & { id: number }, number>;
  syncState!: Table<SyncState, number>;

  constructor() {
    super('StravaSearchDB');

    this.version(1).stores({
      activities: 'id, athleteId, title, activity_type, sport_type, gear_id, start_date_in_zone, [athleteId+start_date_in_zone]',
      gear: 'id, athleteId',
      auth: 'id',
      syncState: 'athleteId',
    });
  }
}

export const db = new StravaDatabase();

function activityId(activity: StravaActivity): number {
  return parseInt(activity.strava_id, 10);
}

export async function saveActivities(activities: StravaActivity[], athleteId: number): Promise<void> {
  const storedActivities: StoredActivity[] = activities.map((activity) => ({
    ...activity,
    id: activityId(activity),
    athleteId,
    syncedAt: Date.now(),
  }));

  await db.activities.bulkPut(storedActivities);
}

export async function getActivitiesForAthlete(athleteId: number): Promise<StoredActivity[]> {
  return db.activities.where('athleteId').equals(athleteId).toArray();
}

export async function getActivityById(id: number): Promise<StoredActivity | undefined> {
  return db.activities.get(id);
}

export async function updateActivityInDb(id: number, updates: Partial<StoredActivity>): Promise<void> {
  await db.activities.update(id, { ...updates, syncedAt: Date.now() });
}

export async function saveGear(gear: StravaGear[], athleteId: number): Promise<void> {
  const storedGear: StoredGear[] = gear.map((g) => ({
    ...g,
    athleteId,
  }));

  await db.gear.bulkPut(storedGear);
}

export async function getGearForAthlete(athleteId: number): Promise<StoredGear[]> {
  return db.gear.where('athleteId').equals(athleteId).toArray();
}

export async function saveAuth(auth: StoredAuth): Promise<void> {
  await db.auth.put({ ...auth, id: auth.athlete.id });
}

export async function getAuth(): Promise<(StoredAuth & { id: number }) | undefined> {
  const auths = await db.auth.toArray();
  return auths[0];
}

export async function clearAuth(): Promise<void> {
  await db.auth.clear();
}

export async function getSyncState(athleteId: number): Promise<SyncState | undefined> {
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
