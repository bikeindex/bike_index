class CreateStolenGeojsonWorker < ScheduledWorker
  prepend ScheduledWorkerRecorder

  def self.frequency
    24.1.hours
  end

  def file_prefix
    Rails.env.test? ? "/spec/fixtures/tsv_creation/" : ""
  end

  def perform
    out_file = File.join(Rails.root, "#{file_prefix}stolen_geojson.json")
    output = File.open(out_file, "w") do |f|
      f.write(Oj.dump({type: "FeatureCollection", features: geojson_bike_features}))
    end
  end

  def geojson_bike_features
    Bike.unscoped.status_stolen.current.where.not(latitude: nil, occurred_at: nil)
      .order(occurred_at: :desc).pluck(:id, :occurred_at, :latitude, :longitude)
      .map { |id, oc, lat, lng| BikeGeojsoner.feature_from_plucked(id, oc, lat, lng) }
  end
end
