class AddPriorityToStravaRequests < ActiveRecord::Migration[6.1]
  def change
    add_column :strava_requests, :priority, :integer, null: false, default: 0

    reversible do |dir|
      dir.up do
        # Backfill priority based on PRIORITY_ORDER: [5, 2, 4, 3, 0, 1]
        # incoming_webhook(5)→0, list_activities(2)→1, fetch_gear(4)→2,
        # fetch_activity(3)→3, fetch_athlete(0)→4, fetch_athlete_stats(1)→5, proxy(6)→6
        execute <<~SQL
          UPDATE strava_requests SET priority = CASE request_type
            WHEN 5 THEN 0
            WHEN 2 THEN 1
            WHEN 4 THEN 2
            WHEN 3 THEN 3
            WHEN 0 THEN 4
            WHEN 1 THEN 5
            WHEN 6 THEN 6
            ELSE 7
          END
        SQL
      end
    end
  end
end
