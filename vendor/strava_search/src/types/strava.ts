export interface StravaAthlete {
  id: number;
  username: string;
  firstname: string;
  lastname: string;
  city: string;
  state: string;
  country: string;
  profile: string;
  profile_medium: string;
}

export interface StravaGear {
  id: string;
  primary: boolean;
  name: string;
  distance: number;
  brand_name?: string;
  model_name?: string;
  description?: string;
  resource_state: number;
}

export interface StravaActivity {
  strava_id: string;
  title: string;
  description?: string;
  activity_type: string;
  sport_type: string;
  distance_meters: number;
  moving_time_seconds: number;
  total_elevation_gain_meters: number;
  average_speed: number;
  start_date: string;
  start_date_in_zone: string;
  timezone: string;
  kudos_count: number;
  suffer_score?: number;
  gear_id?: string | null;
  private: boolean;
  commute: boolean;
  muted: boolean;
  enriched: boolean;
  enriched_at?: string | null;
  pr_count: number;
  device_name?: string;
  device_watts?: boolean;
  average_watts?: number;
  max_heartrate?: number;
  average_heartrate?: number;
  photos?: {
    photo_url: string | null;
    photo_count: number;
  };
  segment_locations?: {
    cities?: string[];
    states?: string[];
    countries?: string[];
  };
}

export interface StoredAuth {
  accessToken: string;
  refreshToken: string;
  expiresAt: number;
  athlete: StravaAthlete;
}

export type ActivityType =
  | 'AlpineSki'
  | 'BackcountrySki'
  | 'Canoeing'
  | 'Crossfit'
  | 'EBikeRide'
  | 'Elliptical'
  | 'Golf'
  | 'Handcycle'
  | 'Hike'
  | 'IceSkate'
  | 'InlineSkate'
  | 'Kayaking'
  | 'Kitesurf'
  | 'NordicSki'
  | 'Ride'
  | 'RockClimbing'
  | 'RollerSki'
  | 'Rowing'
  | 'Run'
  | 'Sail'
  | 'Skateboard'
  | 'Snowboard'
  | 'Snowshoe'
  | 'Soccer'
  | 'StairStepper'
  | 'StandUpPaddling'
  | 'Surfing'
  | 'Swim'
  | 'Velomobile'
  | 'VirtualRide'
  | 'VirtualRun'
  | 'Walk'
  | 'WeightTraining'
  | 'Wheelchair'
  | 'Windsurf'
  | 'Workout'
  | 'Yoga';

export const ACTIVITY_TYPES: ActivityType[] = [
  'AlpineSki',
  'BackcountrySki',
  'Canoeing',
  'Crossfit',
  'EBikeRide',
  'Elliptical',
  'Golf',
  'Handcycle',
  'Hike',
  'IceSkate',
  'InlineSkate',
  'Kayaking',
  'Kitesurf',
  'NordicSki',
  'Ride',
  'RockClimbing',
  'RollerSki',
  'Rowing',
  'Run',
  'Sail',
  'Skateboard',
  'Snowboard',
  'Snowshoe',
  'Soccer',
  'StairStepper',
  'StandUpPaddling',
  'Surfing',
  'Swim',
  'Velomobile',
  'VirtualRide',
  'VirtualRun',
  'Walk',
  'WeightTraining',
  'Wheelchair',
  'Windsurf',
  'Workout',
  'Yoga',
];

export type MutedFilter = 'all' | 'muted' | 'not_muted';
export type PhotoFilter = 'all' | 'with_photo' | 'without_photo';
export type PrivateFilter = 'all' | 'private' | 'not_private';
export type CommuteFilter = 'all' | 'commute' | 'not_commute';

export type ViewMode = 'activities' | 'gear';

export interface SearchFilters {
  query: string;
  activityTypes: string[];
  gearIds: string[];
  noEquipment: boolean;
  dateFrom: string | null;
  dateTo: string | null;
  distanceFrom: number | null;
  distanceTo: number | null;
  elevationFrom: number | null;
  elevationTo: number | null;
  activityTypesExpanded: boolean;
  equipmentExpanded: boolean;
  mutedFilter: MutedFilter;
  photoFilter: PhotoFilter;
  privateFilter: PrivateFilter;
  commuteFilter: CommuteFilter;
  sufferScoreFrom: number | null;
  sufferScoreTo: number | null;
  kudosFrom: number | null;
  kudosTo: number | null;
  page: number;
  view: ViewMode;
}

export interface UpdatableActivity {
  name?: string;
  type?: ActivityType;
  sport_type?: string;
  gear_id?: string;
  description?: string;
  trainer?: boolean;
  commute?: boolean;
}
