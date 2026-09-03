# frozen_string_literal: true

class RenameAthleteIdAndStravaGearIdToStravaId < ActiveRecord::Migration[7.2]
  def change
    rename_column :strava_integrations, :athlete_id, :strava_id
    rename_column :strava_gears, :strava_gear_id, :strava_id
  end
end
