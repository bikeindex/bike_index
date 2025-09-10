class CreateStolenGeojsonJob < ScheduledJob
  prepend ScheduledJobRecorder

  def self.frequency
    24.1.hours
  end

  def self.file_url
    # Could be file&.path - but, easier to just use a static URL (e.g. for tests)
    "https://files.bikeindex.org/uploads/tsvs/stolen.geojson"
  end

  # Currently this method is only used for testing...
  def self.file
    FileCacheMaintainer.files.find { |f| f["filename"] == "stolen.geojson" }
  end

  def file_prefix
    Rails.env.test? ? "/spec/fixtures/tsv_creation/" : ""
  end

  def perform
    filename = "#{file_prefix}stolen.geojson"
    out_file = File.join(Rails.root, filename)
    output = File.open(out_file, "w")
    output.puts Oj.dump({type: "FeatureCollection", features: geojson_bike_features})
    # Note: this file url uses Cloudflare's transform function to add CORS headers
    Spreadsheets::TsvCreator.new.send_to_uploader(output)
    # Expire cache so we get the newest one!
    Integrations::Cloudflare.new.expire_cache(self.class.file_url)
  end

  def geojson_bike_features
    Bike.unscoped.status_stolen.current.where.not(latitude: nil).where.not(occurred_at: nil)
      .order(occurred_at: :desc).pluck(:id, :occurred_at, :latitude, :longitude)
      .map { |id, oc, lat, lng| BikeServices::Geojsoner.feature_from_plucked(id, oc, lat, lng) }
  end
end
