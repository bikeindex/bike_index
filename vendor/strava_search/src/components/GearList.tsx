import type { StoredGear } from '../services/database';
import type { GearBikeLink } from '../services/railsApi';
import { formatDistance } from '../utils/formatters';
import { usePreferences } from '../contexts/PreferencesContext';
import { ExternalLink } from 'lucide-react';

interface GearListProps {
  gear: StoredGear[];
  gearBikeLinks: GearBikeLink[];
  activityCountsByGear: Record<string, number>;
}

export function GearList({ gear, gearBikeLinks, activityCountsByGear }: GearListProps) {
  const { units } = usePreferences();

  const bikeLinksMap = new Map(gearBikeLinks.map((link) => [link.stravaGearId, link]));
  const bikes = gear.filter((g) => g.id.startsWith('b'));
  const shoes = gear.filter((g) => g.id.startsWith('g'));

  const renderGearCard = (g: StoredGear) => {
    const bikeLink = bikeLinksMap.get(g.id);
    const activityCount = activityCountsByGear[g.id] || 0;

    return (
      <div
        key={g.id}
        className="bg-white dark:bg-gray-800 rounded-lg shadow-sm p-4 hover:shadow-md transition-shadow"
      >
        <div className="flex items-start justify-between gap-3">
          <div className="min-w-0 flex-1">
            <div className="flex items-center gap-2 flex-wrap">
              <h3 className="font-semibold text-gray-900 dark:text-gray-100 truncate">
                {g.name}
              </h3>
              {g.primary && (
                <span className="text-xs px-2 py-0.5 bg-[#fc4c02] text-white rounded-full">
                  Primary
                </span>
              )}
            </div>
            {(g.brand_name || g.model_name) && (
              <p className="text-sm text-gray-500 dark:text-gray-400 mt-1">
                {[g.brand_name, g.model_name].filter(Boolean).join(' ')}
              </p>
            )}
            <div className="flex flex-wrap gap-4 mt-2 text-sm text-gray-600 dark:text-gray-400">
              <span>{formatDistance(g.distance, units)}</span>
              <span>{activityCount.toLocaleString()} {activityCount === 1 ? 'activity' : 'activities'}</span>
            </div>
          </div>

          {bikeLink && (
            <a
              href={`/bikes/${bikeLink.bikeId}`}
              className="flex items-center gap-1.5 px-3 py-1.5 text-sm font-medium text-[#fc4c02] bg-orange-50 dark:bg-orange-900/20 hover:bg-orange-100 dark:hover:bg-orange-900/40 rounded-lg transition-colors whitespace-nowrap"
            >
              <ExternalLink className="w-3.5 h-3.5" />
              {bikeLink.bikeName}
            </a>
          )}
        </div>
      </div>
    );
  };

  return (
    <div className="space-y-6">
      {bikes.length > 0 && (
        <div>
          <h2 className="text-sm font-medium text-gray-700 dark:text-gray-300 mb-3 flex items-center gap-2">
            <span>🚴 Bikes</span>
            <span className="text-gray-400">({bikes.length})</span>
          </h2>
          <div className="space-y-3">
            {bikes.map(renderGearCard)}
          </div>
        </div>
      )}

      {shoes.length > 0 && (
        <div>
          <h2 className="text-sm font-medium text-gray-700 dark:text-gray-300 mb-3 flex items-center gap-2">
            <span>👟 Shoes</span>
            <span className="text-gray-400">({shoes.length})</span>
          </h2>
          <div className="space-y-3">
            {shoes.map(renderGearCard)}
          </div>
        </div>
      )}

      {bikes.length === 0 && shoes.length === 0 && (
        <div className="text-center py-12 text-gray-500 dark:text-gray-400">
          No gear found. Sync your activities to load gear from Strava.
        </div>
      )}
    </div>
  );
}
