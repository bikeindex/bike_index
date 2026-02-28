import { useMemo } from 'react';
import { Search, X, ChevronDown } from 'lucide-react';
import type { SearchFilters as SearchFiltersType, StravaActivity } from '../types/strava';
import type { StoredGear } from '../services/database';
import {
  getActivityIcon,
  formatActivityType,
  formatNumber,
  groupActivityTypes,
  ACTIVITY_GROUPS,
  type ActivityGroup,
} from '../utils/formatters';
import { usePreferences } from '../contexts/PreferencesContext';

interface SearchFiltersProps {
  filters: SearchFiltersType;
  onFiltersChange: (filters: SearchFiltersType) => void;
  activities: StravaActivity[];
  activityTypes: string[];
  gear: StoredGear[];
  totalCount: number;
  filteredCount: number;
}

const toggleInactive = 'bg-gray-100 text-gray-700 hover:bg-gray-200 dark:bg-gray-700 dark:text-gray-300 dark:hover:bg-gray-600';
const inputClasses = 'px-2 py-1 border border-gray-300 dark:border-gray-600 dark:bg-gray-700 dark:text-gray-200 rounded focus:ring-2 focus:ring-[#fc4c02] focus:border-transparent outline-none';

export function SearchFilters({
  filters,
  onFiltersChange,
  activities,
  activityTypes,
  gear,
  totalCount,
  filteredCount,
}: SearchFiltersProps) {
  const { units } = usePreferences();
  const distanceUnit = units === 'imperial' ? 'mi' : 'km';
  const elevationUnit = units === 'imperial' ? 'ft' : 'm';

  const selectClasses = `${inputClasses} cursor-pointer`;

  // Extract all location tuples from activities, with legacy fallback
  const allLocations = useMemo(() => {
    return activities.flatMap((a) => {
      const locs = a.segment_locations?.locations;
      if (locs) return locs;
      // Legacy: flat arrays with no city→region mapping
      const cities = a.segment_locations?.cities || [];
      const regions = a.segment_locations?.states || [];
      if (cities.length === 0 && regions.length === 0) return [];
      // Best-effort: create tuples from cities with the shortest region name
      const shortRegion = regions.length > 0 ? regions.reduce((x, y) => x.length <= y.length ? x : y) : undefined;
      return cities.map((city) => ({ city, region: shortRegion }));
    });
  }, [activities]);

  const allCountries = useMemo(() => {
    const set = new Set<string>();
    for (const loc of allLocations) {
      if (loc.country) set.add(loc.country);
    }
    return Array.from(set).sort();
  }, [allLocations]);

  const availableRegions = useMemo(() => {
    const set = new Set<string>();
    for (const loc of allLocations) {
      if (filters.country && loc.country !== filters.country) continue;
      if (loc.region) set.add(loc.region);
    }
    return Array.from(set).sort();
  }, [allLocations, filters.country]);

  const availableCities = useMemo(() => {
    const cityRegions = new Map<string, string>();
    for (const loc of allLocations) {
      if (!loc.city) continue;
      if (filters.country && loc.country !== filters.country) continue;
      if (filters.region && loc.region !== filters.region) continue;
      if (!cityRegions.has(loc.city) && loc.region) cityRegions.set(loc.city, loc.region);
    }
    return Array.from(cityRegions.entries())
      .map(([city, region]) => ({ city, region }))
      .sort((a, b) => a.city.localeCompare(b.city));
  }, [allLocations, filters.country, filters.region]);


  const hasActiveFilters =
    filters.query ||
    filters.activityTypes.length > 0 ||
    filters.gearIds.length > 0 ||
    filters.noEquipment ||
    filters.dateFrom ||
    filters.dateTo ||
    filters.distanceFrom !== null ||
    filters.distanceTo !== null ||
    filters.elevationFrom !== null ||
    filters.elevationTo !== null ||
    filters.mutedFilter !== 'all' ||
    filters.photoFilter !== 'all' ||
    filters.privateFilter !== 'all' ||
    filters.commuteFilter !== 'all' ||
    filters.trainerFilter !== 'all' ||
    filters.sufferScoreFrom !== null ||
    filters.sufferScoreTo !== null ||
    filters.kudosFrom !== null ||
    filters.kudosTo !== null ||
    filters.country !== null ||
    filters.region !== null ||
    filters.city !== null;

  const clearFilters = () => {
    onFiltersChange({
      ...filters,
      query: '',
      activityTypes: [],
      gearIds: [],
      noEquipment: false,
      dateFrom: null,
      dateTo: null,
      distanceFrom: null,
      distanceTo: null,
      elevationFrom: null,
      elevationTo: null,
      mutedFilter: 'all',
      photoFilter: 'all',
      privateFilter: 'all',
      commuteFilter: 'all',
      trainerFilter: 'all',
      sufferScoreFrom: null,
      sufferScoreTo: null,
      kudosFrom: null,
      kudosTo: null,
      country: null,
      region: null,
      city: null,
    });
  };

  const setFiltersExpanded = (expanded: boolean) => {
    onFiltersChange({ ...filters, filtersExpanded: expanded });
  };

  const setActivityTypesExpanded = (expanded: boolean) => {
    onFiltersChange({ ...filters, activityTypesExpanded: expanded });
  };

  const setEquipmentExpanded = (expanded: boolean) => {
    onFiltersChange({ ...filters, equipmentExpanded: expanded });
  };

  const toggleActivityType = (type: string) => {
    const newTypes = filters.activityTypes.includes(type)
      ? filters.activityTypes.filter((t) => t !== type)
      : [...filters.activityTypes, type];
    onFiltersChange({ ...filters, activityTypes: newTypes });
  };

  const toggleActivityGroup = (groupTypes: string[]) => {
    const allSelected = groupTypes.every((t) => filters.activityTypes.includes(t));
    const newTypes = allSelected
      ? filters.activityTypes.filter((t) => !groupTypes.includes(t))
      : [...new Set([...filters.activityTypes, ...groupTypes])];
    onFiltersChange({ ...filters, activityTypes: newTypes });
  };

  const toggleGear = (gearId: string) => {
    const newGearIds = filters.gearIds.includes(gearId)
      ? filters.gearIds.filter((g) => g !== gearId)
      : [...filters.gearIds, gearId];
    onFiltersChange({ ...filters, gearIds: newGearIds, noEquipment: false });
  };

  const toggleNoEquipment = () => {
    onFiltersChange({
      ...filters,
      noEquipment: !filters.noEquipment,
      gearIds: [], // Clear gear selection when toggling no equipment
    });
  };

  return (
  <>
    <div className="space-y-4">
      {/* Search input */}
      <div className="relative">
        <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400" />
        <input
          type="text"
          value={filters.query}
          onChange={(e) => onFiltersChange({ ...filters, query: e.target.value })}
          placeholder="Search by name, description, recorded with..."
          className={`w-full pl-10 pr-4 py-2 border border-gray-300 dark:border-gray-600 dark:bg-gray-700 dark:text-gray-200 rounded-lg focus:ring-2 focus:ring-[#fc4c02] focus:border-transparent outline-none`}
        />
        {filters.query && (
          <button
            onClick={() => onFiltersChange({ ...filters, query: '' })}
            className="absolute right-3 top-1/2 -translate-y-1/2 p-1 hover:bg-gray-100 dark:hover:bg-gray-600 rounded"
          >
            <X className="w-4 h-4 text-gray-400" />
          </button>
        )}
      </div>

      {/* Filters accordion */}
      <div className="space-y-3">
        <div className="border border-gray-200 dark:border-gray-700 rounded-lg overflow-hidden">
          <button
            onClick={() => setFiltersExpanded(!filters.filtersExpanded)}
            className="w-full flex items-center justify-between px-3 py-2 bg-gray-50 dark:bg-gray-700 hover:bg-gray-100 dark:hover:bg-gray-600 transition-colors"
          >
            <div className="flex items-center gap-2">
              <span className="text-sm font-medium text-gray-700 dark:text-gray-300">Search Activity Properties</span>
              {(() => {
                const count = [
                  filters.dateFrom, filters.dateTo,
                  filters.distanceFrom !== null, filters.distanceTo !== null,
                  filters.elevationFrom !== null, filters.elevationTo !== null,
                  filters.mutedFilter !== 'all', filters.photoFilter !== 'all',
                  filters.privateFilter !== 'all', filters.commuteFilter !== 'all',
                  filters.trainerFilter !== 'all',
                  filters.sufferScoreFrom !== null, filters.sufferScoreTo !== null,
                  filters.kudosFrom !== null, filters.kudosTo !== null,
                  !!filters.country, !!filters.region, !!filters.city,
                ].filter(Boolean).length;
                return count > 0 ? (
                  <span className="px-2 py-0.5 text-xs bg-gray-500 text-white rounded-full">{count}</span>
                ) : null;
              })()}
            </div>
            <ChevronDown
              className={`w-4 h-4 text-gray-500 transition-transform ${
                filters.filtersExpanded ? 'rotate-180' : ''
              }`}
            />
          </button>

          {filters.filtersExpanded && (
          <div className="p-3 space-y-3 border-t border-gray-200 dark:border-gray-700">

        {/* Date and distance range */}
        <div className="flex flex-wrap gap-y-2 gap-x-6 items-center mb-4">
          <div className="flex gap-x-3">
            <label className="flex items-center gap-2 text-sm text-gray-600 dark:text-gray-400">
              <span>From:</span>
              <input
                type="date"
                value={filters.dateFrom || ''}
                onChange={(e) =>
                  onFiltersChange({ ...filters, dateFrom: e.target.value || null })
                }
                className={inputClasses}
              />
            </label>
            <label className="flex items-center gap-2 text-sm text-gray-600 dark:text-gray-400">
              <span>To:</span>
              <input
                type="date"
                value={filters.dateTo || ''}
                onChange={(e) =>
                  onFiltersChange({ ...filters, dateTo: e.target.value || null })
                }
                className={inputClasses}
              />
            </label>
          </div>
          <label className="flex items-center gap-2 text-sm text-gray-600 dark:text-gray-400">
              <span>Distance (<span title={units === 'imperial' ? 'miles' : 'kilometers'}>{distanceUnit}</span>):</span>
              <input
                type="number"
                min="0"
                step="0.1"
                value={filters.distanceFrom ?? ''}
                onChange={(e) =>
                  onFiltersChange({ ...filters, distanceFrom: e.target.value ? parseFloat(e.target.value) : null })
                }
                placeholder={distanceUnit}
                className={`w-16 ${inputClasses}`}
              />
              <span>to</span>
              <input
                type="number"
                min="0"
                step="0.1"
                value={filters.distanceTo ?? ''}
                onChange={(e) =>
                  onFiltersChange({ ...filters, distanceTo: e.target.value ? parseFloat(e.target.value) : null })
                }
                placeholder={distanceUnit}
                className={`w-16 ${inputClasses}`}
              />
            </label>
            <label className="flex items-center gap-2 text-sm text-gray-600 dark:text-gray-400">
              <span>Elevation (<span title={units === 'imperial' ? 'feet' : 'meters'}>{elevationUnit}</span>):</span>
              <input
                type="number"
                min="0"
                step="1"
                value={filters.elevationFrom ?? ''}
                onChange={(e) =>
                  onFiltersChange({ ...filters, elevationFrom: e.target.value ? parseFloat(e.target.value) : null })
                }
                placeholder={elevationUnit}
                className={`w-20 ${inputClasses}`}
              />
              <span>to</span>
              <input
                type="number"
                min="0"
                step="1"
                value={filters.elevationTo ?? ''}
                onChange={(e) =>
                  onFiltersChange({ ...filters, elevationTo: e.target.value ? parseFloat(e.target.value) : null })
                }
                placeholder={elevationUnit}
                className={`w-20 ${inputClasses}`}
              />
            </label>
        </div>

        {/* Toggle filters */}
        <div className="flex flex-wrap gap-y-2 gap-x-6 items-center mb-4">
          <div className="flex">
            <button
              onClick={() => onFiltersChange({ ...filters, mutedFilter: filters.mutedFilter === 'muted' ? 'all' : 'muted' })}
              className={`px-3 py-1 text-sm rounded-l-full transition-colors ${
                filters.mutedFilter === 'muted'
                  ? 'bg-[#fc4c02] text-white'
                  : toggleInactive
              }`}
            >
              Muted
            </button>
            <button
              onClick={() => onFiltersChange({ ...filters, mutedFilter: filters.mutedFilter === 'not_muted' ? 'all' : 'not_muted' })}
              className={`px-3 py-1 text-sm rounded-r-full transition-colors ${
                filters.mutedFilter === 'not_muted'
                  ? 'bg-[#fc4c02] text-white'
                  : toggleInactive
              }`}
            >
              Not muted
            </button>
          </div>
          <div className="flex">
            <button
              onClick={() => onFiltersChange({ ...filters, privateFilter: filters.privateFilter === 'private' ? 'all' : 'private' })}
              className={`px-3 py-1 text-sm rounded-l-full transition-colors ${
                filters.privateFilter === 'private'
                  ? 'bg-[#fc4c02] text-white'
                  : toggleInactive
              }`}
            >
              Private
            </button>
            <button
              onClick={() => onFiltersChange({ ...filters, privateFilter: filters.privateFilter === 'not_private' ? 'all' : 'not_private' })}
              className={`px-3 py-1 text-sm rounded-r-full transition-colors ${
                filters.privateFilter === 'not_private'
                  ? 'bg-[#fc4c02] text-white'
                  : toggleInactive
              }`}
            >
              Not private
            </button>
          </div>
          <div className="flex">
            <button
              onClick={() => onFiltersChange({ ...filters, photoFilter: filters.photoFilter === 'with_photo' ? 'all' : 'with_photo' })}
              className={`px-3 py-1 text-sm rounded-l-full transition-colors ${
                filters.photoFilter === 'with_photo'
                  ? 'bg-[#fc4c02] text-white'
                  : toggleInactive
              }`}
            >
              With photo
            </button>
            <button
              onClick={() => onFiltersChange({ ...filters, photoFilter: filters.photoFilter === 'without_photo' ? 'all' : 'without_photo' })}
              className={`px-3 py-1 text-sm rounded-r-full transition-colors ${
                filters.photoFilter === 'without_photo'
                  ? 'bg-[#fc4c02] text-white'
                  : toggleInactive
              }`}
            >
              No photo
            </button>
          </div>
          <div className="flex">
            <button
              onClick={() => onFiltersChange({ ...filters, commuteFilter: filters.commuteFilter === 'commute' ? 'all' : 'commute' })}
              className={`px-3 py-1 text-sm rounded-l-full transition-colors ${
                filters.commuteFilter === 'commute'
                  ? 'bg-[#fc4c02] text-white'
                  : toggleInactive
              }`}
            >
              Commute
            </button>
            <button
              onClick={() => onFiltersChange({ ...filters, commuteFilter: filters.commuteFilter === 'not_commute' ? 'all' : 'not_commute' })}
              className={`px-3 py-1 text-sm rounded-r-full transition-colors ${
                filters.commuteFilter === 'not_commute'
                  ? 'bg-[#fc4c02] text-white'
                  : toggleInactive
              }`}
            >
              Not commute
            </button>
          </div>
          <div className="flex">
            <button
              onClick={() => onFiltersChange({ ...filters, trainerFilter: filters.trainerFilter === 'trainer' ? 'all' : 'trainer' })}
              className={`px-3 py-1 text-sm rounded-l-full transition-colors ${
                filters.trainerFilter === 'trainer'
                  ? 'bg-[#fc4c02] text-white'
                  : toggleInactive
              }`}
            >
              Trainer
            </button>
            <button
              onClick={() => onFiltersChange({ ...filters, trainerFilter: filters.trainerFilter === 'not_trainer' ? 'all' : 'not_trainer' })}
              className={`px-3 py-1 text-sm rounded-r-full transition-colors ${
                filters.trainerFilter === 'not_trainer'
                  ? 'bg-[#fc4c02] text-white'
                  : toggleInactive
              }`}
            >
              Not trainer
            </button>
          </div>
        </div>

        {/* Relative effort and kudos range */}
        <div className="flex flex-wrap gap-y-2 gap-x-6 items-center">
          <label className="flex items-center gap-2 text-sm text-gray-600 dark:text-gray-400">
              <span>Relative effort:</span>
              <input
                type="number"
                min="0"
                step="1"
                value={filters.sufferScoreFrom ?? ''}
                onChange={(e) =>
                  onFiltersChange({ ...filters, sufferScoreFrom: e.target.value ? parseFloat(e.target.value) : null })
                }
                placeholder="min"
                className={`w-16 ${inputClasses}`}
              />
              <span>to</span>
              <input
                type="number"
                min="0"
                step="1"
                value={filters.sufferScoreTo ?? ''}
                onChange={(e) =>
                  onFiltersChange({ ...filters, sufferScoreTo: e.target.value ? parseFloat(e.target.value) : null })
                }
                placeholder="max"
                className={`w-16 ${inputClasses}`}
              />
            </label>
            <label className="flex items-center gap-2 text-sm text-gray-600 dark:text-gray-400">
              <span>Kudos:</span>
              <input
                type="number"
                min="0"
                step="1"
                value={filters.kudosFrom ?? ''}
                onChange={(e) =>
                  onFiltersChange({ ...filters, kudosFrom: e.target.value ? parseFloat(e.target.value) : null })
                }
                placeholder="min"
                className={`w-16 ${inputClasses}`}
              />
              <span>to</span>
              <input
                type="number"
                min="0"
                step="1"
                value={filters.kudosTo ?? ''}
                onChange={(e) =>
                  onFiltersChange({ ...filters, kudosTo: e.target.value ? parseFloat(e.target.value) : null })
                }
                placeholder="max"
                className={`w-16 ${inputClasses}`}
              />
            </label>
        </div>

        {/* Location filters */}
        {allCountries.length > 0 && (
        <div className="flex flex-wrap gap-y-2 gap-x-6 items-center">
          <label className="flex items-center gap-2 text-sm text-gray-600 dark:text-gray-400">
            <span>Country:</span>
            <select
              value={filters.country || ''}
              onChange={(e) => {
                const country = e.target.value || null;
                onFiltersChange({
                  ...filters,
                  country,
                  region: country === filters.country ? filters.region : null,
                  city: country === filters.country ? filters.city : null,
                });
              }}
              className={selectClasses}
            >
              <option value="">All</option>
              {allCountries.map((c) => (
                <option key={c} value={c}>{c}</option>
              ))}
            </select>
          </label>
          {availableRegions.length > 0 && (
          <label className="flex items-center gap-2 text-sm text-gray-600 dark:text-gray-400">
            <span>Region:</span>
            <select
              value={filters.region || ''}
              onChange={(e) => {
                const region = e.target.value || null;
                onFiltersChange({
                  ...filters,
                  region,
                  city: region === filters.region ? filters.city : null,
                });
              }}
              className={selectClasses}
            >
              <option value="">All</option>
              {availableRegions.map((r) => (
                <option key={r} value={r}>{r}</option>
              ))}
            </select>
          </label>
          )}
          {availableCities.length > 0 && (
          <label className="flex items-center gap-2 text-sm text-gray-600 dark:text-gray-400">
            <span>City:</span>
            <select
              value={filters.city || ''}
              onChange={(e) => onFiltersChange({ ...filters, city: e.target.value || null })}
              className={selectClasses}
            >
              <option value="">All</option>
              {availableCities.map(({ city, region }) => (
                <option key={city} value={city}>{city}, {region}</option>
              ))}
            </select>
          </label>
          )}
        </div>
        )}

          </div>
          )}
        </div>

        {/* Activity types accordion */}
        {activityTypes.length > 0 && (
          <div className="border border-gray-200 dark:border-gray-700 rounded-lg overflow-hidden">
            {/* Accordion header */}
            <button
              onClick={() => setActivityTypesExpanded(!filters.activityTypesExpanded)}
              className="w-full flex items-center justify-between px-3 py-2 bg-gray-50 dark:bg-gray-700 hover:bg-gray-100 dark:hover:bg-gray-600 transition-colors"
            >
              <div className="flex items-center gap-2">
                <span className="text-sm font-medium text-gray-700 dark:text-gray-300">Search Activity Types</span>
                {filters.activityTypes.length > 0 && (
                  <span className="px-2 py-0.5 text-xs bg-gray-500 text-white rounded-full">
                    {filters.activityTypes.length}
                  </span>
                )}
              </div>
              <ChevronDown
                className={`w-4 h-4 text-gray-500 transition-transform ${
                  filters.activityTypesExpanded ? 'rotate-180' : ''
                }`}
              />
            </button>

            {/* Accordion content */}
            {filters.activityTypesExpanded && (
              <div className="p-3 space-y-4 border-t border-gray-200 dark:border-gray-700">
                {(() => {
                  const grouped = groupActivityTypes(activityTypes);
                  const groupOrder: ActivityGroup[] = ['foot', 'cycle', 'water', 'winter', 'other'];

                  return groupOrder.map((groupKey) => {
                    const types = grouped[groupKey];
                    if (types.length === 0) return null;

                    const groupConfig = ACTIVITY_GROUPS[groupKey];

                    return (
                      <div key={groupKey} className="flex flex-wrap items-center gap-2">
                        <button
                          onClick={() => toggleActivityGroup(types)}
                          className={`text-sm font-medium px-2 py-0.5 rounded transition-colors ${
                            types.every((t) => filters.activityTypes.includes(t))
                              ? 'bg-[#fc4c02] text-white'
                              : 'text-gray-700 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-600'
                          }`}
                        >
                          {groupConfig.icon} {groupConfig.label}
                        </button>
                        {types.map((type) => {
                          const isSelected = filters.activityTypes.includes(type);
                          const isGroupFullySelected = types.every((t) => filters.activityTypes.includes(t));
                          return (
                            <button
                              key={type}
                              onClick={() => toggleActivityType(type)}
                              className={`px-3 py-1 text-sm rounded-full transition-colors ${
                                isSelected
                                  ? isGroupFullySelected
                                    ? 'bg-gray-500 text-white'
                                    : 'bg-[#fc4c02] text-white'
                                  : toggleInactive
                              }`}
                            >
                              {getActivityIcon(type)} {formatActivityType(type)}
                            </button>
                          );
                        })}
                      </div>
                    );
                  });
                })()}
              </div>
            )}
          </div>
        )}

        {/* Equipment accordion */}
        {(() => {
          const bikes = gear.filter((g) => g.id.startsWith('b'));
          const shoes = gear.filter((g) => g.id.startsWith('g'));
          const hasEquipmentFilter = filters.gearIds.length > 0 || filters.noEquipment;

          return (
            <div className="border border-gray-200 dark:border-gray-700 rounded-lg overflow-hidden">
              {/* Accordion header */}
              <button
                onClick={() => setEquipmentExpanded(!filters.equipmentExpanded)}
                className="w-full flex items-center justify-between px-3 py-2 bg-gray-50 dark:bg-gray-700 hover:bg-gray-100 dark:hover:bg-gray-600 transition-colors"
              >
                <div className="flex items-center gap-2">
                  <span className="text-sm font-medium text-gray-700 dark:text-gray-300">Search Equipment</span>
                  {hasEquipmentFilter && (
                    <span className="px-2 py-0.5 text-xs bg-gray-500 text-white rounded-full">
                      {filters.noEquipment ? 1 : filters.gearIds.length}
                    </span>
                  )}
                </div>
                <ChevronDown
                  className={`w-4 h-4 text-gray-500 transition-transform ${
                    filters.equipmentExpanded ? 'rotate-180' : ''
                  }`}
                />
              </button>

              {/* Accordion content */}
              {filters.equipmentExpanded && (
                <div className="p-3 space-y-5 border-t border-gray-200 dark:border-gray-700">
                  {/* No equipment option */}
                  <div className="flex flex-wrap gap-2">
                    <button
                      onClick={toggleNoEquipment}
                      className={`px-3 py-1 text-sm rounded-full transition-colors ${
                        filters.noEquipment
                          ? 'bg-[#fc4c02] text-white'
                          : toggleInactive
                      }`}
                    >
                      No equipment
                    </button>
                  </div>

                  {/* Bikes */}
                  <div className="flex flex-wrap items-center gap-2">
                    <span className="text-sm font-medium text-gray-700 dark:text-gray-300">🚴 Bikes</span>
                    {bikes.map((g) => (
                      <button
                        key={g.id}
                        onClick={() => toggleGear(g.id)}
                        className={`px-3 py-1 text-sm rounded-full transition-colors ${
                          filters.gearIds.includes(g.id)
                            ? 'bg-[#fc4c02] text-white'
                            : toggleInactive
                        }`}
                      >
                        {g.name}
                      </button>
                    ))}
                    {bikes.length === 0 && (
                      <span className="text-sm text-gray-400">No bikes</span>
                    )}
                  </div>

                  {/* Shoes */}
                  <div className="flex flex-wrap items-center gap-2">
                    <span className="text-sm font-medium text-gray-700 dark:text-gray-300">👟 Shoes</span>
                    {shoes.map((g) => (
                      <button
                        key={g.id}
                        onClick={() => toggleGear(g.id)}
                        className={`px-3 py-1 text-sm rounded-full transition-colors ${
                          filters.gearIds.includes(g.id)
                            ? 'bg-[#fc4c02] text-white'
                            : toggleInactive
                        }`}
                      >
                        {g.name}
                      </button>
                    ))}
                    {shoes.length === 0 && (
                      <span className="text-sm text-gray-400">No shoes</span>
                    )}
                  </div>
                </div>
              )}
            </div>
          );
        })()}

      </div>
    </div>

    {/* Results count and clear */}
    <div className="flex items-center justify-between px-1 pt-2">
      <span className="text-sm text-gray-600 dark:text-gray-400">
        {filteredCount === totalCount
          ? `Matching all ${formatNumber(totalCount)} activities`
          : `Matching ${formatNumber(filteredCount)} of ${formatNumber(totalCount)} activities`}
      </span>
      {hasActiveFilters && (
        <button
          onClick={clearFilters}
          className="text-sm text-[#fc4c02] hover:text-[#e34402] font-medium"
        >
          Clear all filters
        </button>
      )}
    </div>
  </>
  );
}
