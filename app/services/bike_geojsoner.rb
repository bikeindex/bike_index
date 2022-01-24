class BikeGeojsoner
  def self.stolen_marker_color(date_stolen)
    case
    when date_stolen > Time.now - 1.day
      "#BD1622"
    when date_stolen > Time.now - 1.week
      "#E74C3C"
    when date_stolen > Time.now - 1.month
      "#EB6759"
    when date_stolen > Time.now - 6.months
      "#EE8276"
    when date_stolen > Time.now - 5.years
      "#F29D94"
    else
      "#F6B9B3"
    end
  end

  def self.feature(bike)
    return nil unless bike.status_stolen?
    {
      type: "Feature",
      properties: {
        bike_id: bike.id,
        kind: "theft",
        occurred_at: bike.date_stolen.to_i,
        title: bike.title_string,
        "marker-size" => "small",
        "marker-color" => stolen_marker_color(bike)
      },
      geometry: {
        type: "Point",
        coordinates: [bike.longitude_public, bike.latitude_public]
      }
    }
  end
end
