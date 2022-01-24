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

  def self.feature(bike)
    return nil unless bike.status_stolen?
    date_stolen = bike.current_stolen_record.date_stolen || Time.current
    {
      type: "Feature",
      properties: {
        :bike_id => bike.id,
        :kind => "theft",
        :occurred_at => date_stolen.to_i,
        :title => bike.title_string,
        "marker-size" => "small",
        "marker-color" => stolen_marker_color(date_stolen)
      },
      geometry: {
        type: "Point",
        coordinates: [
          bike.current_stolen_record.longitude_public,
          bike.current_stolen_record.latitude_public
        ]
      }
    }
  end
end
