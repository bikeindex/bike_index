import { Search, X, ChevronDown } from 'lucide-react';
import type { SearchFilters as SearchFiltersType } from '../types/strava';
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
  activityTypes: string[];
  gear: StoredGear[];
  totalCount: number;
  filteredCount: number;
}

export function SearchFilters({
  filters,
  onFiltersChange,
  activityTypes,
  gear,
  totalCount,
  filteredCount,
}: SearchFiltersProps) {
  const { units } = usePreferences();
  const distanceUnit = units === 'imperial' ? 'mi' : 'km';
  const elevationUnit = units === 'imperial' ? 'ft' : 'm';

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
    filters.photoFilter !== 'all';

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
    });
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
    <div className="bg-white rounded-lg shadow-md p-4 space-y-4">
      {/* Search input */}
      <div className="relative">
        <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400" />
        <input
          type="text"
          value={filters.query}
          onChange={(e) => onFiltersChange({ ...filters, query: e.target.value })}
          placeholder="Search by name, description, location, recorded with..."
          className="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-[#fc4c02] focus:border-transparent outline-none"
        />
        {filters.query && (
          <button
            onClick={() => onFiltersChange({ ...filters, query: '' })}
            className="absolute right-3 top-1/2 -translate-y-1/2 p-1 hover:bg-gray-100 rounded"
          >
            <X className="w-4 h-4 text-gray-400" />
          </button>
        )}
      </div>

      {/* Filter toggle section */}
      <div className="space-y-3">
        {/* Date and distance range */}
        <div className="flex flex-wrap gap-3 items-center">
          <label className="flex items-center gap-2 text-sm text-gray-600">
            <span>From:</span>
            <input
              type="date"
              value={filters.dateFrom || ''}
              onChange={(e) =>
                onFiltersChange({ ...filters, dateFrom: e.target.value || null })
              }
              className="px-2 py-1 border border-gray-300 rounded focus:ring-2 focus:ring-[#fc4c02] focus:border-transparent outline-none"
            />
          </label>
          <label className="flex items-center gap-2 text-sm text-gray-600">
            <span>To:</span>
            <input
              type="date"
              value={filters.dateTo || ''}
              onChange={(e) =>
                onFiltersChange({ ...filters, dateTo: e.target.value || null })
              }
              className="px-2 py-1 border border-gray-300 rounded focus:ring-2 focus:ring-[#fc4c02] focus:border-transparent outline-none"
            />
          </label>
          <label className="flex items-center gap-2 text-sm text-gray-600 ml-4">
            <span>Distance:</span>
            <input
              type="number"
              min="0"
              step="0.1"
              value={filters.distanceFrom ?? ''}
              onChange={(e) =>
                onFiltersChange({ ...filters, distanceFrom: e.target.value ? parseFloat(e.target.value) : null })
              }
              placeholder={distanceUnit}
              className="w-20 px-2 py-1 border border-gray-300 rounded focus:ring-2 focus:ring-[#fc4c02] focus:border-transparent outline-none"
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
              className="w-20 px-2 py-1 border border-gray-300 rounded focus:ring-2 focus:ring-[#fc4c02] focus:border-transparent outline-none"
            />
            <span className="text-gray-400">{distanceUnit}</span>
          </label>
          <label className="flex items-center gap-2 text-sm text-gray-600 ml-4">
            <span>Elevation:</span>
            <input
              type="number"
              min="0"
              step="1"
              value={filters.elevationFrom ?? ''}
              onChange={(e) =>
                onFiltersChange({ ...filters, elevationFrom: e.target.value ? parseFloat(e.target.value) : null })
              }
              placeholder={elevationUnit}
              className="w-20 px-2 py-1 border border-gray-300 rounded focus:ring-2 focus:ring-[#fc4c02] focus:border-transparent outline-none"
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
              className="w-20 px-2 py-1 border border-gray-300 rounded focus:ring-2 focus:ring-[#fc4c02] focus:border-transparent outline-none"
            />
            <span className="text-gray-400">{elevationUnit}</span>
          </label>
          <div className="flex ml-4">
            <button
              onClick={() => onFiltersChange({ ...filters, mutedFilter: filters.mutedFilter === 'muted' ? 'all' : 'muted' })}
              className={`px-3 py-1 text-sm rounded-l-full transition-colors ${
                filters.mutedFilter === 'muted'
                  ? 'bg-[#fc4c02] text-white'
                  : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
              }`}
            >
              Muted
            </button>
            <button
              onClick={() => onFiltersChange({ ...filters, mutedFilter: filters.mutedFilter === 'not_muted' ? 'all' : 'not_muted' })}
              className={`px-3 py-1 text-sm rounded-r-full transition-colors ${
                filters.mutedFilter === 'not_muted'
                  ? 'bg-[#fc4c02] text-white'
                  : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
              }`}
            >
              Not muted
            </button>
          </div>
          <div className="flex ml-2">
            <button
              onClick={() => onFiltersChange({ ...filters, photoFilter: filters.photoFilter === 'with_photo' ? 'all' : 'with_photo' })}
              className={`px-3 py-1 text-sm rounded-l-full transition-colors ${
                filters.photoFilter === 'with_photo'
                  ? 'bg-[#fc4c02] text-white'
                  : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
              }`}
            >
              With photo
            </button>
            <button
              onClick={() => onFiltersChange({ ...filters, photoFilter: filters.photoFilter === 'without_photo' ? 'all' : 'without_photo' })}
              className={`px-3 py-1 text-sm rounded-r-full transition-colors ${
                filters.photoFilter === 'without_photo'
                  ? 'bg-[#fc4c02] text-white'
                  : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
              }`}
            >
              No photo
            </button>
          </div>
        </div>

        {/* Activity types accordion */}
        {activityTypes.length > 0 && (
          <div className="border border-gray-200 rounded-lg overflow-hidden">
            {/* Accordion header */}
            <button
              onClick={() => setActivityTypesExpanded(!filters.activityTypesExpanded)}
              className="w-full flex items-center justify-between px-3 py-2 bg-gray-50 hover:bg-gray-100 transition-colors"
            >
              <div className="flex items-center gap-2">
                <span className="text-sm font-medium text-gray-700">Search Activity Types</span>
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
              <div className="p-3 space-y-4 border-t border-gray-200">
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
                              : 'text-gray-700 hover:bg-gray-100'
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
                                  : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
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
            <div className="border border-gray-200 rounded-lg overflow-hidden">
              {/* Accordion header */}
              <button
                onClick={() => setEquipmentExpanded(!filters.equipmentExpanded)}
                className="w-full flex items-center justify-between px-3 py-2 bg-gray-50 hover:bg-gray-100 transition-colors"
              >
                <div className="flex items-center gap-2">
                  <span className="text-sm font-medium text-gray-700">Search Equipment</span>
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
                <div className="p-3 space-y-5 border-t border-gray-200">
                  {/* No equipment option */}
                  <div className="flex flex-wrap gap-2">
                    <button
                      onClick={toggleNoEquipment}
                      className={`px-3 py-1 text-sm rounded-full transition-colors ${
                        filters.noEquipment
                          ? 'bg-[#fc4c02] text-white'
                          : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
                      }`}
                    >
                      No equipment
                    </button>
                  </div>

                  {/* Bikes */}
                  <div className="flex flex-wrap items-center gap-2">
                    <span className="text-sm font-medium text-gray-700">🚴 Bikes</span>
                    {bikes.map((g) => (
                      <button
                        key={g.id}
                        onClick={() => toggleGear(g.id)}
                        className={`px-3 py-1 text-sm rounded-full transition-colors ${
                          filters.gearIds.includes(g.id)
                            ? 'bg-[#fc4c02] text-white'
                            : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
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
                    <span className="text-sm font-medium text-gray-700">👟 Shoes</span>
                    {shoes.map((g) => (
                      <button
                        key={g.id}
                        onClick={() => toggleGear(g.id)}
                        className={`px-3 py-1 text-sm rounded-full transition-colors ${
                          filters.gearIds.includes(g.id)
                            ? 'bg-[#fc4c02] text-white'
                            : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
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
      <span className="text-sm text-gray-600">
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
