include ActionView::Helpers::NumberHelper

namespace :data do
  desc "Set location info on any bike records with no lat/long"
  task set_bike_location_info: :environment do
    display_geocoded_bike_counts

    puts "Setting coordinates on stolen bikes:"
    puts "------------------------------------"
    stolen_bikes = Bike.where(latitude: nil, longitude: nil).where.not(stolen_lat: nil, stolen_long: nil)
    stolen_bikes.update_all("latitude = stolen_lat, longitude = stolen_long")
    puts "Updated #{stolen_bikes.count} stolen bikes"

    display_geocoded_bike_counts

    puts "Setting coordinates on non-stolen bikes:"
    puts "----------------------------------------"
    bikes =
      Bike
        .includes(:current_stolen_record, :creation_organization, :ownerships)
        .where(latitude: nil, longitude: nil)
    total = bikes.count

    bikes.find_each.with_index(1) do |bike, i|
      bike.set_location_info
      bike.save
      print_progress(i, total)
    end

    display_geocoded_bike_counts
  end
end

def print_progress(curr, total_count)
  total = number_with_delimiter(total_count)
  digits = total.to_s.length

  count = [number_with_delimiter(curr).to_s.rjust(digits, " "), total].join("/")
  percent = (curr * 100 / total_count.to_f).round(1).to_s.rjust(7, " ")

  $stdout.print "#{count} : #{percent}%\r"
  $stdout.flush
end

def display_geocoded_bike_counts
  geocoded_bikes = Bike.where.not(latitude: nil, longitude: nil).count
  ungeocoded_bikes = Bike.where(latitude: nil, longitude: nil).count
  puts
  puts "Geocoded bikes: #{number_with_delimiter(geocoded_bikes)}"
  puts "Un-geocoded bikes: #{number_with_delimiter(ungeocoded_bikes)}"
  puts
end
