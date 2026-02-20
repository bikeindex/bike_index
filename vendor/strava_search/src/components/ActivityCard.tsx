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
      <div className="flex">
        {/* Content */}
        <div className="flex-1 min-w-0 p-4">
          {/* Header */}
          <div className="flex items-start gap-3">
            <label className="flex items-center mt-1">
              <input
                type="checkbox"
                checked={isSelected}
                onChange={onToggleSelect}
                className="w-4 h-4 text-[#fc4c02] border-gray-300 dark:border-gray-600 rounded focus:ring-[#fc4c02]"
              />
            </label>
            <div className="flex-1 min-w-0">
              <div className="flex items-center gap-2 flex-wrap mb-1">
                <span className="text-lg">{getActivityIcon(activity.sport_type)}</span>
                <span className="text-xs font-medium text-gray-500 dark:text-gray-400">
                  {formatActivityType(activity.sport_type)}
                </span>
                {activityGear && (
                  <span className="text-xs px-2 py-0.5 bg-gray-100 dark:bg-gray-700 text-gray-500 dark:text-gray-400 rounded-full">
                    {activityGear.name}
                  </span>
                )}
                <span className="text-xs text-gray-400">
                  <span title={formatDateTimeTitle(activity.start_date_in_zone)}>
                    {formatDate(activity.start_date_in_zone)}
                  </span>
                  {activity.device_name && (
                    <>
                      {' · '}
                      <span className="italic" title="Recorded by">
                        {activity.device_name}
                      </span>
                    </>
                  )}
                  {(firstCity || firstState) && (
                    <>
                      {' · '}
                      {[firstCity, firstState]
                        .filter(Boolean)
                        .join(', ')}
                    </>
                  )}
                </span>
              </div>

              <h3 className="font-semibold text-gray-900 dark:text-gray-100 truncate">
                <a
                  href={`https://www.strava.com/activities/${activity.strava_id}`}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="hover:text-[#fc4c02]"
                >
                  {activity.title}
                </a>
              </h3>

              {activity.description && (
                <p className="text-sm text-gray-600 dark:text-gray-400 mt-2 line-clamp-2">
                  {activity.description}
                </p>
              )}
            </div>
          </div>

        {/* Stats grid */}
        <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 mt-4 pt-3 border-t border-gray-100 dark:border-gray-700">
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
              <div className="text-xs text-gray-500 dark:text-gray-400">Pace/Speed</div>
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

        {/* Additional info */}
        <div className="flex flex-wrap items-center gap-3 mt-3 text-xs text-gray-500 dark:text-gray-400">
          {activity.average_heartrate && (
            <div className="flex items-center gap-1">
              <Heart className="w-3 h-3 text-red-400" />
              <span>{Math.round(activity.average_heartrate)} bpm avg</span>
            </div>
          )}

          {activity.kudos_count > 0 && (
            <span>👍 {activity.kudos_count}</span>
          )}

          {activity.pr_count > 0 && (
            <span className="text-[#fc4c02] font-medium">
              🏆 {activity.pr_count} PR{activity.pr_count > 1 ? 's' : ''}
            </span>
          )}

          {activity.suffer_score != null && activity.suffer_score > 0 && (
            <span>Suffer: {activity.suffer_score}</span>
          )}

          {activity.commute && (
            <span title="Commute">Commute</span>
          )}

          {activity.muted && (
            <span title="Not published to Home or Club feeds">Muted</span>
          )}

          {activity.private && (
            <span title="Private activity">🔒 Private</span>
          )}
        </div>
        </div>

        {/* Photo */}
        {photoUrl && (
          <a
            href={`https://www.strava.com/activities/${activity.strava_id}`}
            target="_blank"
            rel="noopener noreferrer"
            className="relative flex-shrink-0 self-stretch"
          >
            <img
              src={photoUrl}
              alt={activity.title}
              className="w-32 h-full object-cover rounded-r-lg"
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
