import { format, formatDistanceToNow, parseISO } from 'date-fns';

export type UnitSystem = 'metric' | 'imperial';

export function formatNumber(value: number): string {
  return value.toLocaleString();
}

export function formatDistance(meters: number, units: UnitSystem = 'metric'): string {
  if (units === 'imperial') {
    const miles = meters / 1609.344;
    return `${miles.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })} mi`;
  }

  if (meters >= 1000) {
    const km = meters / 1000;
    return `${km.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })} km`;
  }
  return `${Math.round(meters).toLocaleString()} m`;
}

export function formatDuration(seconds: number): string {
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  const secs = seconds % 60;

  if (hours > 0) {
    return `${hours}h ${minutes}m`;
  }
  if (minutes > 0) {
    return `${minutes}m ${secs}s`;
  }
  return `${secs}s`;
}

export function formatPace(metersPerSecond: number, activityType: string, units: UnitSystem = 'metric'): string {
  if (metersPerSecond === 0) return '-';

  // For running/walking, show pace (min/km or min/mi)
  if (['Run', 'Walk', 'Hike', 'VirtualRun', 'TrailRun'].includes(activityType)) {
    if (units === 'imperial') {
      const secondsPerMile = 1609.344 / metersPerSecond;
      const minutes = Math.floor(secondsPerMile / 60);
      const seconds = Math.round(secondsPerMile % 60);
      return `${minutes}:${seconds.toString().padStart(2, '0')} /mi`;
    }
    const secondsPerKm = 1000 / metersPerSecond;
    const minutes = Math.floor(secondsPerKm / 60);
    const seconds = Math.round(secondsPerKm % 60);
    return `${minutes}:${seconds.toString().padStart(2, '0')} /km`;
  }

  // For cycling and others, show speed (mph or km/h)
  if (units === 'imperial') {
    const mph = metersPerSecond * 2.23694;
    return `${mph.toFixed(1)} mph`;
  }
  const kmPerHour = metersPerSecond * 3.6;
  return `${kmPerHour.toFixed(1)} km/h`;
}

export function formatSpeed(metersPerSecond: number, units: UnitSystem = 'metric'): string {
  if (units === 'imperial') {
    const mph = metersPerSecond * 2.23694;
    return `${mph.toFixed(1)} mph`;
  }
  const kmPerHour = metersPerSecond * 3.6;
  return `${kmPerHour.toFixed(1)} km/h`;
}

export function formatElevation(meters: number, units: UnitSystem = 'metric'): string {
  if (units === 'imperial') {
    const feet = meters * 3.28084;
    return `${Math.round(feet).toLocaleString()} ft`;
  }
  return `${Math.round(meters).toLocaleString()} m`;
}

export function formatDate(dateString: string): string {
  if (!dateString) return '';
  const date = parseISO(dateString);
  return format(date, 'MMM d, yyyy');
}

export function formatDateTime(dateString: string): string {
  if (!dateString) return '';
  const date = parseISO(dateString);
  return format(date, 'MMM d, yyyy h:mm a');
}

export function formatDateTimeTitle(dateString: string): string {
  if (!dateString) return '';
  const date = parseISO(dateString);

  // Get timezone abbreviation using Intl API
  const tzAbbr = new Intl.DateTimeFormat('en-US', { timeZoneName: 'short' })
    .formatToParts(date)
    .find(part => part.type === 'timeZoneName')?.value || '';

  // Format: "February 1, 2026 at 11:40:40am PST"
  const formatted = format(date, "MMMM d, yyyy 'at' h:mm:ssaaa");
  return `${formatted} ${tzAbbr}`;
}

export function formatTimeAgo(dateString: string): string {
  if (!dateString) return '';
  const date = parseISO(dateString);
  return formatDistanceToNow(date, { addSuffix: true });
}

export function formatDateForInput(dateString: string | null): string {
  if (!dateString) return '';
  const date = parseISO(dateString);
  return format(date, 'yyyy-MM-dd');
}

export function getActivityIcon(activityType: string): string {
  const icons: Record<string, string> = {
    Run: '🏃',
    VirtualRun: '🖥️🏃',
    Ride: '🚴',
    VirtualRide: '🖥️🚴',
    EBikeRide: '🔌🚴',
    EMountainBikeRide: '🔌🚵',
    MountainBikeRide: '🚵',
    GravelRide: '🚴',
    Swim: '🏊',
    Walk: '🚶',
    Hike: '🥾',
    AlpineSki: '🚡⛷️',
    BackcountrySki: '⛷️',
    NordicSki: '⛷️',
    Snowboard: '🏂',
    Kayaking: '🚣',
    Rowing: '🚣',
    Canoeing: '🛶',
    StandUpPaddling: '🏄',
    Surfing: '🏄',
    Kitesurf: '🪁',
    Windsurf: '💨🏄',
    Yoga: '🧘',
    WeightTraining: '🏋️',
    Workout: '💪',
    Crossfit: '💪',
    RockClimbing: '🧗',
    IceSkate: '⛸️',
    InlineSkate: '🛼',
    Soccer: '⚽',
    Golf: '⛳',
    Skateboard: '🛹',
  };

  return icons[activityType] || '🏅';
}

export type ActivityGroup = 'foot' | 'cycle' | 'water' | 'winter' | 'other';

export const ACTIVITY_GROUPS: Record<ActivityGroup, { label: string; icon: string; types: string[] }> = {
  foot: {
    label: 'Foot',
    icon: '🏃',
    types: ['Run', 'TrailRun', 'VirtualRun', 'Walk', 'Hike'],
  },
  cycle: {
    label: 'Cycle',
    icon: '🚴',
    types: ['Ride', 'VirtualRide', 'MountainBikeRide', 'GravelRide', 'EBikeRide', 'EMountainBikeRide', 'Velomobile', 'Handcycle'],
  },
  water: {
    label: 'Water',
    icon: '🏊',
    types: ['Canoeing', 'Kayaking', 'Kitesurf', 'Rowing', 'Sail', 'StandUpPaddling', 'Surfing', 'Swim', 'Windsurf'],
  },
  winter: {
    label: 'Winter Sports',
    icon: '⛷️',
    types: ['IceSkate', 'AlpineSki', 'BackcountrySki', 'NordicSki', 'Snowboard', 'Snowshoe'],
  },
  other: {
    label: 'Other',
    icon: '✨',
    types: [], // Dynamically filled with anything not in other groups
  },
};

const ALL_GROUPED_TYPES = new Set(
  Object.values(ACTIVITY_GROUPS).flatMap(g => g.types)
);

export function getActivityGroup(activityType: string): ActivityGroup {
  if (ALL_GROUPED_TYPES.has(activityType)) {
    for (const [group, config] of Object.entries(ACTIVITY_GROUPS) as [ActivityGroup, typeof ACTIVITY_GROUPS[ActivityGroup]][]) {
      if (config.types.includes(activityType)) {
        return group;
      }
    }
  }
  return 'other';
}

export function groupActivityTypes(types: string[]): Record<ActivityGroup, string[]> {
  const grouped: Record<ActivityGroup, string[]> = {
    foot: [],
    cycle: [],
    water: [],
    winter: [],
    other: [],
  };

  for (const type of types) {
    const group = getActivityGroup(type);
    grouped[group].push(type);
  }

  // Sort each group by display name
  for (const group of Object.keys(grouped) as ActivityGroup[]) {
    grouped[group].sort((a, b) => formatActivityType(a).localeCompare(formatActivityType(b)));
  }

  return grouped;
}

export function formatActivityType(activityType: string): string {
  const displayNames: Record<string, string> = {
    Ride: 'Ride',
    NordicSki: 'Nordic Ski',
    BackcountrySki: 'Backcountry Ski',
    AlpineSki: 'Alpine Ski',
    GravelRide: 'Gravel Ride',
    EBikeRide: 'E-Bike Ride',
    Run: 'Run',
    MountainBikeRide: 'Mountain Bike Ride',
    Swim: 'Swim',
    Walk: 'Walk',
    Hike: 'Hike',
    TrailRun: 'Trail Run',
    EMountainBikeRide: 'E-Mountain Bike Ride',
    Badminton: 'Badminton',
    Canoeing: 'Canoe',
    Crossfit: 'Crossfit',
    Elliptical: 'Elliptical',
    Golf: 'Golf',
    IceSkate: 'Ice Skate',
    InlineSkate: 'Inline Skate',
    Handcycle: 'Handcycle',
    HighIntensityIntervalTraining: 'HIIT',
    Kayaking: 'Kayaking',
    Kitesurf: 'Kitesurf',
    Pickleball: 'Pickleball',
    Pilates: 'Pilates',
    Racquetball: 'Racquetball',
    RockClimbing: 'Rock Climb',
    RollerSki: 'Roller Ski',
    Rowing: 'Rowing',
    Sail: 'Sail',
    Skateboard: 'Skateboard',
    Snowboard: 'Snowboard',
    Snowshoe: 'Snowshoe',
    Soccer: 'Football (Soccer)',
    Squash: 'Squash',
    StandUpPaddling: 'Stand Up Paddling',
    StairStepper: 'Stair-Stepper',
    Surfing: 'Surfing',
    TableTennis: 'Table Tennis',
    Tennis: 'Tennis',
    Velomobile: 'Velomobile',
    WeightTraining: 'Weight Training',
    Windsurf: 'Windsurf',
    Wheelchair: 'Wheelchair',
    Workout: 'Workout',
    Yoga: 'Yoga',
    // Virtual activities
    VirtualRide: 'Virtual Ride',
    VirtualRun: 'Virtual Run',
  };

  // Return mapped name or fall back to splitting camelCase
  return displayNames[activityType] || activityType.replace(/([a-z])([A-Z])/g, '$1 $2');
}

export function formatCalories(calories: number): string {
  return `${Math.round(calories)} cal`;
}

export function formatHeartRate(bpm: number): string {
  return `${Math.round(bpm)} bpm`;
}
