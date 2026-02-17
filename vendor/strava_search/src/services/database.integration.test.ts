import { describe, it, expect, beforeEach } from 'vitest';
import {
  db,
  saveActivities,
  getActivitiesForAthlete,
  getActivityById,
  updateActivityInDb,
  saveGear,
  getGearForAthlete,
  saveAuth,
  getAuth,
  clearAuth,
  getSyncState,
  updateSyncState,
  clearAllData,
  type SyncState,
} from './database';
import type { StravaActivity, StravaGear, StoredAuth } from '../types/strava';

// Helper to create a mock activity
function createMockActivity(overrides: Partial<StravaActivity> = {}): StravaActivity {
  return {
    id: Math.floor(Math.random() * 1000000),
    name: 'Test Activity',
    description: 'Test description',
    distance: 10000,
    moving_time: 3600,
    elapsed_time: 3700,
    total_elevation_gain: 100,
    type: 'Ride',
    sport_type: 'Ride',
    start_date: '2024-01-15T10:00:00Z',
    start_date_local: '2024-01-15T02:00:00Z',
    timezone: '(GMT-08:00) America/Los_Angeles',
    utc_offset: -28800,
    achievement_count: 0,
    kudos_count: 5,
    comment_count: 0,
    athlete_count: 1,
    photo_count: 0,
    trainer: false,
    commute: false,
    manual: false,
    private: false,
    visibility: 'everyone',
    flagged: false,
    average_speed: 2.78,
    max_speed: 5.5,
    has_heartrate: false,
    heartrate_opt_out: false,
    display_hide_heartrate_option: false,
    pr_count: 0,
    total_photo_count: 0,
    has_kudoed: false,
    ...overrides,
  };
}

// Helper to create mock gear
function createMockGear(overrides: Partial<StravaGear> = {}): StravaGear {
  return {
    id: `g${Math.floor(Math.random() * 1000000)}`,
    primary: false,
    name: 'Test Bike',
    distance: 5000,
    resource_state: 2,
    ...overrides,
  };
}

// Helper to create mock auth
function createMockAuth(athleteId: number): StoredAuth {
  return {
    accessToken: 'test_access_token',
    refreshToken: 'test_refresh_token',
    expiresAt: Date.now() + 3600000,
    athlete: {
      id: athleteId,
      username: 'testuser',
      firstname: 'Test',
      lastname: 'User',
      city: 'Test City',
      state: 'Test State',
      country: 'Test Country',
      profile: 'https://example.com/profile.jpg',
      profile_medium: 'https://example.com/profile_medium.jpg',
    },
  };
}

describe('database service integration tests', () => {
  const testAthleteId = 12345;
  const otherAthleteId = 67890;

  // Clear database before each test
  beforeEach(async () => {
    await db.activities.clear();
    await db.gear.clear();
    await db.auth.clear();
    await db.syncState.clear();
  });

  describe('saveActivities and getActivitiesForAthlete', () => {
    it('saves activities with athleteId and syncedAt timestamp', async () => {
      const activities = [
        createMockActivity({ id: 1, name: 'Activity 1' }),
        createMockActivity({ id: 2, name: 'Activity 2' }),
      ];

      await saveActivities(activities, testAthleteId);

      const saved = await getActivitiesForAthlete(testAthleteId);
      expect(saved).toHaveLength(2);
      expect(saved[0].athleteId).toBe(testAthleteId);
      expect(saved[0].syncedAt).toBeDefined();
      expect(typeof saved[0].syncedAt).toBe('number');
    });

    it('returns only activities for the specified athlete', async () => {
      const activities1 = [createMockActivity({ id: 1, name: 'Athlete 1 Activity' })];
      const activities2 = [createMockActivity({ id: 2, name: 'Athlete 2 Activity' })];

      await saveActivities(activities1, testAthleteId);
      await saveActivities(activities2, otherAthleteId);

      const athlete1Activities = await getActivitiesForAthlete(testAthleteId);
      const athlete2Activities = await getActivitiesForAthlete(otherAthleteId);

      expect(athlete1Activities).toHaveLength(1);
      expect(athlete1Activities[0].name).toBe('Athlete 1 Activity');
      expect(athlete2Activities).toHaveLength(1);
      expect(athlete2Activities[0].name).toBe('Athlete 2 Activity');
    });

    it('returns empty array when athlete has no activities', async () => {
      const activities = await getActivitiesForAthlete(99999);
      expect(activities).toHaveLength(0);
    });

    it('updates existing activities with bulkPut', async () => {
      const activity = createMockActivity({ id: 100, name: 'Original Name' });
      await saveActivities([activity], testAthleteId);

      const updatedActivity = createMockActivity({ id: 100, name: 'Updated Name' });
      await saveActivities([updatedActivity], testAthleteId);

      const saved = await getActivitiesForAthlete(testAthleteId);
      expect(saved).toHaveLength(1);
      expect(saved[0].name).toBe('Updated Name');
    });
  });

  describe('getActivityById', () => {
    it('returns the correct activity', async () => {
      const activities = [
        createMockActivity({ id: 100, name: 'Target Activity' }),
        createMockActivity({ id: 200, name: 'Other Activity' }),
      ];
      await saveActivities(activities, testAthleteId);

      const activity = await getActivityById(100);
      expect(activity).toBeDefined();
      expect(activity?.name).toBe('Target Activity');
    });

    it('returns undefined for non-existent activity', async () => {
      const activity = await getActivityById(99999);
      expect(activity).toBeUndefined();
    });
  });

  describe('updateActivityInDb', () => {
    it('updates activity fields and sets syncedAt timestamp', async () => {
      const activity = createMockActivity({ id: 100, name: 'Original' });
      await saveActivities([activity], testAthleteId);

      const beforeUpdate = await getActivityById(100);
      const originalSyncedAt = beforeUpdate?.syncedAt;

      // Small delay to ensure timestamp changes
      await new Promise((resolve) => setTimeout(resolve, 10));

      await updateActivityInDb(100, { name: 'Updated', description: 'New desc' });

      const updated = await getActivityById(100);
      expect(updated?.name).toBe('Updated');
      expect(updated?.description).toBe('New desc');
      expect(updated?.syncedAt).toBeGreaterThan(originalSyncedAt!);
    });

    it('preserves other fields when updating', async () => {
      const activity = createMockActivity({
        id: 100,
        name: 'Original',
        distance: 5000,
        kudos_count: 10,
      });
      await saveActivities([activity], testAthleteId);

      await updateActivityInDb(100, { name: 'Updated' });

      const updated = await getActivityById(100);
      expect(updated?.name).toBe('Updated');
      expect(updated?.distance).toBe(5000);
      expect(updated?.kudos_count).toBe(10);
    });
  });

  describe('saveGear and getGearForAthlete', () => {
    it('saves gear with athleteId', async () => {
      const gear = [
        createMockGear({ id: 'g1', name: 'Road Bike' }),
        createMockGear({ id: 'g2', name: 'Mountain Bike' }),
      ];

      await saveGear(gear, testAthleteId);

      const saved = await getGearForAthlete(testAthleteId);
      expect(saved).toHaveLength(2);
      expect(saved[0].athleteId).toBe(testAthleteId);
    });

    it('returns only gear for the specified athlete', async () => {
      const gear1 = [createMockGear({ id: 'g1', name: 'Bike 1' })];
      const gear2 = [createMockGear({ id: 'g2', name: 'Bike 2' })];

      await saveGear(gear1, testAthleteId);
      await saveGear(gear2, otherAthleteId);

      const athlete1Gear = await getGearForAthlete(testAthleteId);
      expect(athlete1Gear).toHaveLength(1);
      expect(athlete1Gear[0].name).toBe('Bike 1');
    });

    it('updates existing gear with bulkPut', async () => {
      await saveGear([createMockGear({ id: 'g1', name: 'Old Name' })], testAthleteId);
      await saveGear([createMockGear({ id: 'g1', name: 'New Name' })], testAthleteId);

      const saved = await getGearForAthlete(testAthleteId);
      expect(saved).toHaveLength(1);
      expect(saved[0].name).toBe('New Name');
    });
  });

  describe('saveAuth, getAuth, and clearAuth', () => {
    it('saves and retrieves auth data', async () => {
      const auth = createMockAuth(testAthleteId);
      await saveAuth(auth);

      const retrieved = await getAuth();
      expect(retrieved).toBeDefined();
      expect(retrieved?.accessToken).toBe('test_access_token');
      expect(retrieved?.athlete.id).toBe(testAthleteId);
    });

    it('returns undefined when no auth exists', async () => {
      const auth = await getAuth();
      expect(auth).toBeUndefined();
    });

    it('clears auth data', async () => {
      const auth = createMockAuth(testAthleteId);
      await saveAuth(auth);

      await clearAuth();

      const retrieved = await getAuth();
      expect(retrieved).toBeUndefined();
    });

    it('overwrites existing auth when saving new auth', async () => {
      await saveAuth(createMockAuth(testAthleteId));
      await saveAuth(createMockAuth(otherAthleteId));

      // Only the most recent auth should be accessible via getAuth
      const retrieved = await getAuth();
      expect(retrieved?.athlete.id).toBe(otherAthleteId);
    });
  });

  describe('getSyncState and updateSyncState', () => {
    it('saves and retrieves sync state', async () => {
      const syncState: SyncState = {
        athleteId: testAthleteId,
        lastSyncedAt: Date.now(),
        oldestActivityDate: '2020-01-01T00:00:00Z',
        isInitialSyncComplete: true,
      };

      await updateSyncState(syncState);

      const retrieved = await getSyncState(testAthleteId);
      expect(retrieved).toBeDefined();
      expect(retrieved?.athleteId).toBe(testAthleteId);
      expect(retrieved?.isInitialSyncComplete).toBe(true);
      expect(retrieved?.oldestActivityDate).toBe('2020-01-01T00:00:00Z');
    });

    it('returns undefined for non-existent sync state', async () => {
      const state = await getSyncState(99999);
      expect(state).toBeUndefined();
    });

    it('updates existing sync state', async () => {
      const initialState: SyncState = {
        athleteId: testAthleteId,
        lastSyncedAt: 1000,
        oldestActivityDate: null,
        isInitialSyncComplete: false,
      };
      await updateSyncState(initialState);

      const updatedState: SyncState = {
        athleteId: testAthleteId,
        lastSyncedAt: 2000,
        oldestActivityDate: '2020-01-01T00:00:00Z',
        isInitialSyncComplete: true,
      };
      await updateSyncState(updatedState);

      const retrieved = await getSyncState(testAthleteId);
      expect(retrieved?.lastSyncedAt).toBe(2000);
      expect(retrieved?.isInitialSyncComplete).toBe(true);
    });

    it('maintains separate sync states per athlete', async () => {
      await updateSyncState({
        athleteId: testAthleteId,
        lastSyncedAt: 1000,
        oldestActivityDate: null,
        isInitialSyncComplete: true,
      });
      await updateSyncState({
        athleteId: otherAthleteId,
        lastSyncedAt: 2000,
        oldestActivityDate: null,
        isInitialSyncComplete: false,
      });

      const state1 = await getSyncState(testAthleteId);
      const state2 = await getSyncState(otherAthleteId);

      expect(state1?.lastSyncedAt).toBe(1000);
      expect(state1?.isInitialSyncComplete).toBe(true);
      expect(state2?.lastSyncedAt).toBe(2000);
      expect(state2?.isInitialSyncComplete).toBe(false);
    });
  });

  describe('clearAllData', () => {
    it('clears all tables', async () => {
      // Populate all tables
      await saveActivities([createMockActivity({ id: 1 })], testAthleteId);
      await saveGear([createMockGear({ id: 'g1' })], testAthleteId);
      await saveAuth(createMockAuth(testAthleteId));
      await updateSyncState({
        athleteId: testAthleteId,
        lastSyncedAt: Date.now(),
        oldestActivityDate: null,
        isInitialSyncComplete: true,
      });

      // Clear everything
      await clearAllData();

      // Verify all tables are empty
      const activities = await getActivitiesForAthlete(testAthleteId);
      const gear = await getGearForAthlete(testAthleteId);
      const auth = await getAuth();
      const syncState = await getSyncState(testAthleteId);

      expect(activities).toHaveLength(0);
      expect(gear).toHaveLength(0);
      expect(auth).toBeUndefined();
      expect(syncState).toBeUndefined();
    });
  });

  describe('data integrity', () => {
    it('preserves all activity fields through save/retrieve cycle', async () => {
      const activity = createMockActivity({
        id: 100,
        name: 'Full Activity',
        description: 'Description',
        distance: 50000,
        moving_time: 7200,
        total_elevation_gain: 500,
        average_speed: 6.94,
        max_speed: 12.5,
        average_heartrate: 145,
        max_heartrate: 180,
        kudos_count: 25,
        pr_count: 3,
        calories: 1500,
        gear_id: 'b12345',
        location_city: 'San Francisco',
        location_state: 'California',
        device_name: 'Garmin Edge 530',
        hide_from_home: true,
      });

      await saveActivities([activity], testAthleteId);
      const retrieved = await getActivityById(100);

      expect(retrieved?.name).toBe('Full Activity');
      expect(retrieved?.description).toBe('Description');
      expect(retrieved?.distance).toBe(50000);
      expect(retrieved?.moving_time).toBe(7200);
      expect(retrieved?.total_elevation_gain).toBe(500);
      expect(retrieved?.average_speed).toBe(6.94);
      expect(retrieved?.max_speed).toBe(12.5);
      expect(retrieved?.average_heartrate).toBe(145);
      expect(retrieved?.max_heartrate).toBe(180);
      expect(retrieved?.kudos_count).toBe(25);
      expect(retrieved?.pr_count).toBe(3);
      expect(retrieved?.calories).toBe(1500);
      expect(retrieved?.gear_id).toBe('b12345');
      expect(retrieved?.location_city).toBe('San Francisco');
      expect(retrieved?.location_state).toBe('California');
      expect(retrieved?.device_name).toBe('Garmin Edge 530');
      expect(retrieved?.hide_from_home).toBe(true);
    });

    it('handles activities with photos', async () => {
      const activity = createMockActivity({
        id: 100,
        total_photo_count: 3,
        photos: {
          primary: {
            unique_id: 'photo123',
            urls: {
              '100': 'https://example.com/100.jpg',
              '600': 'https://example.com/600.jpg',
            },
            source: 1,
            media_type: 1,
          },
          use_primary_photo: true,
          count: 3,
        },
      });

      await saveActivities([activity], testAthleteId);
      const retrieved = await getActivityById(100);

      expect(retrieved?.photos?.primary?.unique_id).toBe('photo123');
      expect(retrieved?.photos?.count).toBe(3);
    });

    it('handles activities with segment data', async () => {
      const activity = createMockActivity({
        id: 100,
        segment_cities: ['San Francisco', 'Sausalito'],
        segment_states: ['California'],
        segment_countries: ['United States'],
      });

      await saveActivities([activity], testAthleteId);
      const retrieved = await getActivityById(100);

      expect(retrieved?.segment_cities).toEqual(['San Francisco', 'Sausalito']);
      expect(retrieved?.segment_states).toEqual(['California']);
    });
  });
});
