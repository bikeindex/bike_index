class BikeServices::Geojsoner
  def self.feature(bike, extended_properties = false)
    return nil unless bike.status_stolen?
    date_stolen = bike.occurred_at || Time.current
    properties = {id: bike.id, at: date_stolen.to_date.to_s}
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
      properties: {id: id, at: occurred_at.to_date.to_s},
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
