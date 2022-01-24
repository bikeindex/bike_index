class CreateStolenGeojsonWorker < ScheduledWorker
  prepend ScheduledWorkerRecorder

  def self.frequency
    24.1.hours
  end

  def perform
    { type: "FeatureCollection", features: geojson_bike_features }
  end

  def geojson_bike_features
    Bike.unscoped.status_stolen.current.where.not(latitude: nil, occurred_at: nil)
      .order(occurred_at: :desc).pluck(:id, :occurred_at, :latitude, :longitude)
      .map { |id, oc, lat, lng| BikeGeojsoner.feature_from_plucked(id, oc, lat, lng) }
  end
end
