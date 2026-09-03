import { describe, it, expect } from 'vitest';
import {
  formatNumber,
  formatDistance,
  formatDuration,
  formatPace,
  formatSpeed,
  formatElevation,
  formatDate,
  formatDateTime,
  formatDateTimeTitle,
  formatCalories,
  formatHeartRate,
  getActivityIcon,
  formatActivityType,
  getActivityGroup,
  groupActivityTypes,
} from './formatters';

describe('formatNumber', () => {
  it('formats small numbers without delimiters', () => {
    expect(formatNumber(0)).toBe('0');
    expect(formatNumber(1)).toBe('1');
    expect(formatNumber(999)).toBe('999');
  });

  it('formats large numbers with delimiters', () => {
    expect(formatNumber(1000)).toBe('1,000');
    expect(formatNumber(10000)).toBe('10,000');
    expect(formatNumber(100000)).toBe('100,000');
    expect(formatNumber(1000000)).toBe('1,000,000');
  });
});

describe('formatDistance', () => {
  it('formats meters under 1000 as meters', () => {
    expect(formatDistance(500)).toBe('500 m');
    expect(formatDistance(999)).toBe('999 m');
  });

  it('formats meters over 1000 as kilometers with delimiter', () => {
    expect(formatDistance(1000)).toBe('1.00 km');
    expect(formatDistance(5234.5)).toBe('5.23 km');
    expect(formatDistance(42195)).toBe('42.20 km');
    // Large distance with thousand separator
    expect(formatDistance(1234567)).toBe('1,234.57 km');
  });
});

describe('formatDistance with imperial units', () => {
  it('converts meters to miles', () => {
    expect(formatDistance(1609.344, 'imperial')).toBe('1.00 mi');
    expect(formatDistance(42195, 'imperial')).toBe('26.22 mi');
    // Large distance with thousand separator
    expect(formatDistance(1609344, 'imperial')).toBe('1,000.00 mi');
  });
});

describe('formatDuration', () => {
  it('formats seconds only', () => {
    expect(formatDuration(30)).toBe('30s');
    expect(formatDuration(59)).toBe('59s');
  });

  it('formats minutes and seconds', () => {
    expect(formatDuration(60)).toBe('1m 0s');
    expect(formatDuration(90)).toBe('1m 30s');
    expect(formatDuration(3599)).toBe('59m 59s');
  });

  it('formats hours and minutes', () => {
    expect(formatDuration(3600)).toBe('1h 0m');
    expect(formatDuration(3661)).toBe('1h 1m');
    expect(formatDuration(7200)).toBe('2h 0m');
  });
});

describe('formatPace', () => {
  it('returns dash for zero speed', () => {
    expect(formatPace(0, 'Run')).toBe('-');
  });

  it('formats running pace as min/km (metric)', () => {
    // 3.33 m/s = 5:00 /km
    expect(formatPace(3.33, 'Run')).toBe('5:00 /km');
    expect(formatPace(3.33, 'Walk')).toBe('5:00 /km');
    expect(formatPace(3.33, 'Hike')).toBe('5:00 /km');
  });

  it('formats running pace as min/mi (imperial)', () => {
    // 3.33 m/s = 8:03 /mi approximately
    expect(formatPace(3.33, 'Run', 'imperial')).toBe('8:03 /mi');
    expect(formatPace(3.33, 'Walk', 'imperial')).toBe('8:03 /mi');
  });

  it('formats cycling speed as km/h (metric)', () => {
    // 10 m/s = 36 km/h
    expect(formatPace(10, 'Ride')).toBe('36.0 km/h');
  });

  it('formats cycling speed as mph (imperial)', () => {
    // 10 m/s = 22.4 mph
    expect(formatPace(10, 'Ride', 'imperial')).toBe('22.4 mph');
  });
});

describe('formatSpeed', () => {
  it('converts m/s to km/h (metric)', () => {
    expect(formatSpeed(10)).toBe('36.0 km/h');
    expect(formatSpeed(2.78)).toBe('10.0 km/h');
  });

  it('converts m/s to mph (imperial)', () => {
    expect(formatSpeed(10, 'imperial')).toBe('22.4 mph');
  });
});

describe('formatElevation', () => {
  it('rounds to nearest meter (metric)', () => {
    expect(formatElevation(100.4)).toBe('100 m');
    expect(formatElevation(100.6)).toBe('101 m');
  });

  it('converts to feet (imperial)', () => {
    expect(formatElevation(100, 'imperial')).toBe('328 ft');
    expect(formatElevation(304.8, 'imperial')).toBe('1,000 ft');
  });
});

describe('formatDate', () => {
  it('formats ISO date string', () => {
    expect(formatDate('2024-01-15T12:30:00Z')).toBe('Jan 15, 2024');
  });
});

describe('formatDateTime', () => {
  it('formats ISO date string with time', () => {
    const result = formatDateTime('2024-01-15T12:30:00Z');
    expect(result).toContain('Jan 15, 2024');
  });
});

describe('formatDateTimeTitle', () => {
  it('formats date in full title format with timezone', () => {
    const result = formatDateTimeTitle('2024-02-01T11:40:40');
    // Should contain full month name, day, year, "at", time with seconds
    expect(result).toContain('February 1, 2024');
    expect(result).toContain('at');
    expect(result).toMatch(/11:40:40(am|AM)/);
  });
});

describe('formatCalories', () => {
  it('rounds calories', () => {
    expect(formatCalories(523.7)).toBe('524 cal');
    expect(formatCalories(100)).toBe('100 cal');
  });
});

describe('formatHeartRate', () => {
  it('rounds heart rate', () => {
    expect(formatHeartRate(145.5)).toBe('146 bpm');
    expect(formatHeartRate(120)).toBe('120 bpm');
  });
});

describe('getActivityIcon', () => {
  it('returns correct emoji for known activity types', () => {
    expect(getActivityIcon('Run')).toBe('🏃');
    expect(getActivityIcon('Ride')).toBe('🚴');
    expect(getActivityIcon('Swim')).toBe('🏊');
    expect(getActivityIcon('Hike')).toBe('🥾');
    expect(getActivityIcon('Yoga')).toBe('🧘');
  });

  it('returns default emoji for unknown types', () => {
    expect(getActivityIcon('Unknown')).toBe('🏅');
    expect(getActivityIcon('')).toBe('🏅');
  });
});

describe('formatActivityType', () => {
  it('converts camelCase to spaced words', () => {
    expect(formatActivityType('VirtualRide')).toBe('Virtual Ride');
    expect(formatActivityType('VirtualRun')).toBe('Virtual Run');
    expect(formatActivityType('WeightTraining')).toBe('Weight Training');
    expect(formatActivityType('RockClimbing')).toBe('Rock Climb');
    expect(formatActivityType('IceSkate')).toBe('Ice Skate');
    expect(formatActivityType('InlineSkate')).toBe('Inline Skate');
  });

  it('handles special cases', () => {
    expect(formatActivityType('EBikeRide')).toBe('E-Bike Ride');
    expect(formatActivityType('StandUpPaddling')).toBe('Stand Up Paddling');
  });

  it('preserves single word types', () => {
    expect(formatActivityType('Run')).toBe('Run');
    expect(formatActivityType('Ride')).toBe('Ride');
    expect(formatActivityType('Swim')).toBe('Swim');
    expect(formatActivityType('Hike')).toBe('Hike');
    expect(formatActivityType('Walk')).toBe('Walk');
  });
});

describe('getActivityGroup', () => {
  it('groups foot activities correctly', () => {
    expect(getActivityGroup('Run')).toBe('foot');
    expect(getActivityGroup('TrailRun')).toBe('foot');
    expect(getActivityGroup('VirtualRun')).toBe('foot');
    expect(getActivityGroup('Walk')).toBe('foot');
    expect(getActivityGroup('Hike')).toBe('foot');
  });

  it('groups cycle activities correctly', () => {
    expect(getActivityGroup('Ride')).toBe('cycle');
    expect(getActivityGroup('VirtualRide')).toBe('cycle');
    expect(getActivityGroup('MountainBikeRide')).toBe('cycle');
    expect(getActivityGroup('GravelRide')).toBe('cycle');
    expect(getActivityGroup('EBikeRide')).toBe('cycle');
    expect(getActivityGroup('EMountainBikeRide')).toBe('cycle');
    expect(getActivityGroup('Velomobile')).toBe('cycle');
    expect(getActivityGroup('Handcycle')).toBe('cycle');
  });

  it('groups water activities correctly', () => {
    expect(getActivityGroup('Swim')).toBe('water');
    expect(getActivityGroup('Kayaking')).toBe('water');
    expect(getActivityGroup('Canoeing')).toBe('water');
    expect(getActivityGroup('Rowing')).toBe('water');
    expect(getActivityGroup('Surfing')).toBe('water');
    expect(getActivityGroup('StandUpPaddling')).toBe('water');
  });

  it('groups winter activities correctly', () => {
    expect(getActivityGroup('AlpineSki')).toBe('winter');
    expect(getActivityGroup('BackcountrySki')).toBe('winter');
    expect(getActivityGroup('NordicSki')).toBe('winter');
    expect(getActivityGroup('Snowboard')).toBe('winter');
    expect(getActivityGroup('Snowshoe')).toBe('winter');
    expect(getActivityGroup('IceSkate')).toBe('winter');
  });

  it('groups unknown activities as other', () => {
    expect(getActivityGroup('Yoga')).toBe('other');
    expect(getActivityGroup('WeightTraining')).toBe('other');
    expect(getActivityGroup('Golf')).toBe('other');
    expect(getActivityGroup('UnknownActivity')).toBe('other');
  });
});

describe('groupActivityTypes', () => {
  it('groups activity types correctly', () => {
    const types = ['Run', 'Ride', 'Swim', 'AlpineSki', 'Yoga'];
    const grouped = groupActivityTypes(types);

    expect(grouped.foot).toEqual(['Run']);
    expect(grouped.cycle).toEqual(['Ride']);
    expect(grouped.water).toEqual(['Swim']);
    expect(grouped.winter).toEqual(['Alpine Ski'].map(() => 'AlpineSki'));
    expect(grouped.other).toEqual(['Yoga']);
  });

  it('sorts types within groups by display name', () => {
    const types = ['VirtualRide', 'Ride', 'GravelRide', 'MountainBikeRide'];
    const grouped = groupActivityTypes(types);

    // Should be sorted alphabetically by display name
    expect(grouped.cycle).toEqual(['EBikeRide', 'GravelRide', 'MountainBikeRide', 'Ride', 'VirtualRide'].filter(t => types.includes(t)));
  });

  it('returns empty arrays for groups with no matching types', () => {
    const types = ['Run', 'Walk'];
    const grouped = groupActivityTypes(types);

    expect(grouped.foot).toHaveLength(2);
    expect(grouped.cycle).toHaveLength(0);
    expect(grouped.water).toHaveLength(0);
    expect(grouped.winter).toHaveLength(0);
    expect(grouped.other).toHaveLength(0);
  });
});
