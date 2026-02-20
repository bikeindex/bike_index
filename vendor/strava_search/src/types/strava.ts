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
  id: number;
  name: string;
  description?: string;
  distance: number;
  moving_time: number;
  elapsed_time: number;
  total_elevation_gain: number;
  type: string;
  sport_type: string;
  start_date: string;
  start_date_local: string;
  timezone: string;
  utc_offset: number;
  location_city?: string;
  location_state?: string;
  location_country?: string;
  achievement_count: number;
  kudos_count: number;
  comment_count: number;
  athlete_count: number;
  photo_count: number;
  map?: {
    id: string;
    summary_polyline?: string;
    polyline?: string;
  };
  trainer: boolean;
  commute: boolean;
  manual: boolean;
  private: boolean;
  visibility: string;
  flagged: boolean;
  gear_id?: string;
  gear?: StravaGear;
  start_latlng?: [number, number];
  end_latlng?: [number, number];
  average_speed: number;
  max_speed: number;
  average_cadence?: number;
  average_watts?: number;
  weighted_average_watts?: number;
  kilojoules?: number;
  device_watts?: boolean;
  has_heartrate: boolean;
  average_heartrate?: number;
  max_heartrate?: number;
  heartrate_opt_out: boolean;
  display_hide_heartrate_option: boolean;
  elev_high?: number;
  elev_low?: number;
  pr_count: number;
  total_photo_count: number;
  has_kudoed: boolean;
  suffer_score?: number;
  calories?: number;
  device_name?: string;
  hide_from_home?: boolean;
  segment_cities?: string[];
  segment_states?: string[];
  segment_countries?: string[];
  photos?: {
    primary?: {
      unique_id: string;
      urls: {
        '100': string;
        '600': string;
      };
      source: number;
      media_type: number;
    };
    use_primary_photo: boolean;
    count: number;
  };
  segment_efforts?: Array<{
    segment: {
      city?: string | null;
      state?: string | null;
      country?: string | null;
    };
  }>;
}

/**
 * Derive location from segment efforts when activity location is null,
 * and extract all unique locations from segments
 */
export function deriveLocationFromSegments(activity: StravaActivity): StravaActivity {
  // Extract all unique locations from segment efforts
  const cities = new Set<string>();
  const states = new Set<string>();
  const countries = new Set<string>();

  activity.segment_efforts?.forEach((effort) => {
    if (effort.segment?.city) cities.add(effort.segment.city);
    if (effort.segment?.state) states.add(effort.segment.state);
    if (effort.segment?.country) countries.add(effort.segment.country);
  });

  const segment_cities = cities.size > 0 ? Array.from(cities).sort() : undefined;
  const segment_states = states.size > 0 ? Array.from(states).sort() : undefined;
  const segment_countries = countries.size > 0 ? Array.from(countries).sort() : undefined;

  // If activity already has location, just add segment locations
  if (activity.location_city || activity.location_state) {
    return {
      ...activity,
      segment_cities,
      segment_states,
      segment_countries,
    };
  }

  // Otherwise, also derive primary location from first segment with location
  const segmentWithLocation = activity.segment_efforts?.find(
    (effort) => effort.segment?.city || effort.segment?.state
  );

  if (segmentWithLocation?.segment) {
    return {
      ...activity,
      location_city: segmentWithLocation.segment.city ?? undefined,
      location_state: segmentWithLocation.segment.state ?? undefined,
      location_country: segmentWithLocation.segment.country ?? undefined,
      segment_cities,
      segment_states,
      segment_countries,
    };
  }

  return {
    ...activity,
    segment_cities,
    segment_states,
    segment_countries,
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
export type VisibilityFilter = 'all' | 'everyone' | 'followers_only' | 'only_me';

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
  visibilityFilter: VisibilityFilter;
  page: number;
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
