namespace :data do
  desc "Update bikes records to set their latitude and longitude"
  task geolocate_bikes: :environment do
    bikes = Bike.where(latitude: nil, longitude: nil)
    total = bikes.count

    bikes.find_each.with_index(1) do |bike, i|
      bike.set_location_info
      bike.save
      print_progress(i, total)
    end
  end
end

def print_progress(curr, total_count)
  digits = total_count.to_s.length
  count = [curr.to_s.rjust(digits, " "), total_count].join("/")
  percent = (curr * 100 / total_count.to_f).round(1).to_s.rjust(5, " ")
  $stdout.print "#{count} : #{percent}%\r"
  $stdout.flush
end
