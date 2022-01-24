class BikeGeojsoner
  def self.stolen_marker_color(date_stolen)
    if date_stolen > Time.now - 1.day
      "#BD1622"
    elsif date_stolen > Time.now - 1.week
      "#E74C3C"
    elsif date_stolen > Time.now - 1.month
      "#EB6759"
    elsif date_stolen > Time.now - 6.months
      "#EE8276"
    elsif date_stolen > Time.now - 5.years
      "#F29D94"
    else
      "#F6B9B3"
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
      properties: {id: bike.id, color: stolen_marker_color(occurred_at)},
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
