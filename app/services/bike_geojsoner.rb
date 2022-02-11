class BikeGeojsoner
  # Using an array of colors here to make it easier to copy, specifically for github.com/bikeindex/bike_thefts_map
  COLORS = ["#BD1622", "#E74C3C", "#EB6759", "#EE8276", "#F29D94", "#F6B9B3"].freeze

  def self.stolen_marker_color(date_stolen)
    if date_stolen > Time.now - 1.day
      COLORS[0]
    elsif date_stolen > Time.now - 1.week
      COLORS[1]
    elsif date_stolen > Time.now - 1.month
      COLORS[2]
    elsif date_stolen > Time.now - 1.year
      COLORS[3]
    elsif date_stolen > Time.now - 5.years
      COLORS[4]
    else
      COLORS[5]
    end
  end

  def self.feature(bike, extended_properties = false)
    return nil unless bike.status_stolen?
    date_stolen = bike.occurred_at || Time.current
    properties = {id: bike.id, color: stolen_marker_color(date_stolen)}
    if extended_properties
      properties.merge!(kind: "theft",
        occurred_at: date_stolen.to_i,
        title: bike.title_string)
    end
    {
      type: "Feature",
      properties: properties,
      geometry: {
        type: "Point",
        coordinates: [
          bike.current_stolen_record.longitude_public,
          bike.current_stolen_record.latitude_public
        ]
      }
    }
  end

  def self.feature_from_plucked(id, occurred_at, latitude, longitude)
    {
      type: "Feature",
      properties: {id: id, color: stolen_marker_color(occurred_at)},
      geometry: {
        type: "Point",
        coordinates: [
          longitude.round(Bike::PUBLIC_COORD_LENGTH),
          latitude.round(Bike::PUBLIC_COORD_LENGTH)
        ]
      }
    }
  end
end
