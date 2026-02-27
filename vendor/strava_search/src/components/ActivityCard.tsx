import { memo } from 'react';
import type { StoredActivity, StoredGear } from '../services/database';
import {
  formatDistance,
  formatDuration,
  formatPace,
  formatDate,
  formatDateTimeTitle,
  formatElevation,
  getActivityIcon,
  formatActivityType,
} from '../utils/formatters';
import { usePreferences } from '../contexts/PreferencesContext';
import { Clock, TrendingUp, Activity, Zap, Heart } from 'lucide-react';

interface ActivityCardProps {
  activity: StoredActivity;
  gear: StoredGear[];
  isSelected: boolean;
  onToggleSelect: () => void;
}

export const ActivityCard = memo(function ActivityCard({
  activity,
  gear,
  isSelected,
  onToggleSelect,
}: ActivityCardProps) {
  const { units } = usePreferences();
  const activityGear = gear.find((g) => g.id === activity.gear_id);
  const photoUrl = activity.photos?.photo_url;
  const photoCount = activity.photos?.photo_count || 0;
  const firstCity = activity.segment_locations?.cities?.[0];
  const firstState = activity.segment_locations?.states?.[0];

  return (
    <div
      className={`bg-white dark:bg-gray-800 rounded-lg shadow-sm transition-all hover:shadow-md overflow-hidden ${
        isSelected ? 'ring-2 ring-[#fc4c02]' : ''
      }`}
    >
      <div className={`grid ${photoUrl ? 'grid-cols-[1fr_auto]' : ''}`}>
        {/* Header - full width on small, col 1 on sm+ */}
        <div className={`p-4 pb-4 border-b border-gray-100 dark:border-gray-700 ${photoUrl ? 'col-span-2 sm:col-span-1' : ''}`}>
          <div className="flex items-baseline gap-3 mb-1">
            <label className="flex items-baseline">
              <input
                type="checkbox"
                checked={isSelected}
                onChange={onToggleSelect}
                className="w-4 h-4 text-[#fc4c02] border-gray-300 dark:border-gray-600 rounded focus:ring-[#fc4c02]"
              />
            </label>
            <h3 className="font-semibold text-gray-900 dark:text-gray-100 flex-1 min-w-0 flex items-center gap-1.5">
              <a
                href={`https://www.strava.com/activities/${activity.strava_id}`}
                target="_blank"
                className="hover:text-[#fc4c02]"
              >
                <span className="items-center gap-2 mr-1" title={formatActivityType(activity.sport_type)}>
                  <span className="text-lg leading-none mr-1">{getActivityIcon(activity.sport_type)}</span>
                  <span className="hidden sm:inline text-xs font-medium text-gray-500 dark:text-gray-400 mr-1">
                    {formatActivityType(activity.sport_type)}
                  </span>
                </span>
                {activity.title}
              </a>
            </h3>
          </div>

          <div className="flex items-center gap-y-1 gap-x-2 sm:gap-x-4 flex-wrap mt-2 mb-2">
            <span className="text-xs text-gray-400" title={formatDateTimeTitle(activity.start_date_in_zone)}>
              {formatDate(activity.start_date_in_zone)}
            </span>
            {activityGear && (
              <span className="text-xs px-2 py-0.5 bg-gray-100 dark:bg-gray-700 text-gray-500 dark:text-gray-400 rounded-full">
                {activityGear.name}
                {activity.trainer && (
                  <span className="text-gray-400 dark:text-gray-500"> · Trainer</span>
                )}
              </span>
            )}
            {!activityGear && activity.trainer && (
              <span className="text-xs px-2 py-0.5 bg-gray-100 dark:bg-gray-700 text-gray-400 dark:text-gray-500 rounded-full">
                Trainer
              </span>
            )}
            {activity.device_name && (
              <span className="text-xs text-gray-400 italic" title="Recorded by">
                {activity.device_name}
              </span>
            )}
            {(firstCity || firstState) && (
              <span className="text-xs text-gray-400">
                {[firstCity, firstState].filter(Boolean).join(', ')}
              </span>
            )}
            {activity.kudos_count > 0 && (
              <span className="text-xs text-gray-400" title={`${activity.kudos_count} kudos`}>👍 {activity.kudos_count}</span>
            )}
          </div>

          {activity.description && (
            <p className="text-sm text-gray-600 dark:text-gray-400 line-clamp-2" title={activity.description}>
              {activity.description}
            </p>
          )}
        </div>

        {/* Stats + Additional info */}
        <div className="px-4 pb-4 pt-3">
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
            <div className="flex items-center gap-2">
              <Activity className="w-4 h-4 text-gray-400" />
              <div>
                <div className="text-sm font-medium dark:text-gray-200">{formatDistance(activity.distance_meters, units)}</div>
                <div className="text-xs text-gray-500 dark:text-gray-400">Distance</div>
              </div>
            </div>

            <div className="flex items-center gap-2">
              <Clock className="w-4 h-4 text-gray-400" />
              <div>
                <div className="text-sm font-medium dark:text-gray-200">{formatDuration(activity.moving_time_seconds)}</div>
                <div className="text-xs text-gray-500 dark:text-gray-400">Time</div>
              </div>
            </div>

            <div className="flex items-center gap-2">
              <Zap className="w-4 h-4 text-gray-400" />
              <div>
                <div className="text-sm font-medium dark:text-gray-200">
                  {formatPace(activity.average_speed, activity.sport_type, units)}
                </div>
                <div className="text-xs text-gray-500 dark:text-gray-400">
                  {['Run', 'Walk', 'Hike', 'VirtualRun', 'TrailRun'].includes(activity.sport_type) ? 'Avg pace' : 'Avg speed'}
                </div>
              </div>
            </div>

            <div className="flex items-center gap-2">
              <TrendingUp className="w-4 h-4 text-gray-400" />
              <div>
                <div className="text-sm font-medium dark:text-gray-200">
                  {formatElevation(activity.total_elevation_gain_meters, units)}
                </div>
                <div className="text-xs text-gray-500 dark:text-gray-400">Elevation</div>
              </div>
            </div>
          </div>

          <div className="flex flex-wrap items-center gap-x-4 gap-y-2 mt-3 text-xs text-gray-500 dark:text-gray-400">
            {activity.average_heartrate && (
              <div className="flex items-center gap-1">
                <Heart className="w-3 h-3 text-red-400" />
                <span title={activity.max_heartrate ? `Max heartrate: ${Math.round(activity.max_heartrate)} bpm` : undefined}>
                  {Math.round(activity.average_heartrate)} bpm avg
                </span>
              </div>
            )}

            {activity.suffer_score != null && activity.suffer_score > 0 && (
              <span className="italic">relative effort {activity.suffer_score}</span>
            )}

            {activity.pr_count > 0 && (
              <span className="text-[#fc4c02] font-medium">
                🏆 {activity.pr_count} PR{activity.pr_count > 1 ? 's' : ''}
              </span>
            )}

            {activity.commute && (
              <span className="px-2 py-0.5 bg-gray-100 dark:bg-gray-700 rounded-full" title="Commute">Commute</span>
            )}

            {activity.muted && (
              <span className="text-gray-300 dark:text-gray-600" title="Not published to Home or Club feeds">Muted</span>
            )}

            {activity.private && (
              <span title="Private activity">🔒 Private</span>
            )}
          </div>
        </div>

        {/* Photo - row 2 on small (next to stats), spans both rows on sm+ */}
        {photoUrl && (
          <a
            href={`https://www.strava.com/activities/${activity.strava_id}`}
            target="_blank"

            className="relative row-start-2 col-start-2 sm:row-start-1 sm:row-span-2 self-stretch"
          >
            <img
              src={photoUrl}
              alt={activity.title}
              className="w-24 sm:w-32 h-full object-cover rounded-br-lg sm:rounded-tr-lg"
            />
            {photoCount > 1 && (
              <span className="absolute bottom-2 right-2 bg-black/70 text-white text-xs px-1.5 py-0.5 rounded">
                +{photoCount - 1}
              </span>
            )}
          </a>
        )}
      </div>
    </div>
  );
});
