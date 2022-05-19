class CountWorker < ApplicationWorker
  sidekiq_options queue: "low_priority"
  sidekiq_options retry: false

  def redis
    Redis.current
  end

  def redis_key
    bike_counts
  end

  def comma_wrapped_string(array)
    array.map { |val| '"' + val.to_s.tr("\\", "").gsub(/(\\)?"/, '\"') + '"'}.join(",") + "\n"
  end

  def perform(zipcode)
    bikes = Bike.unscoped.non_example.where("zipcode ILIKE ?", "#{zipcode}%")
    all_cities = bikes.distinct.pluck(:city).reject(&:blank?).map { |c| c.strip.gsub(/\s*,\z/, "") }
    cities = all_cities.map(&:downcase)
    freq = cities.inject(Hash.new(0)) { |h,v| h[v] += 1; h }
    most_common_city = cities.max_by { |v| freq[v] }
    city = all_cities.detect { |c| c.downcase == most_common_city }

    begin_2022 = Time.current.beginning_of_year
    begin_2020 = begin_2022 - 2.years
    bikes_2022 = bikes.where(created_at: begin_2022..Time.current).count
    bikes_2021 = bikes.where(created_at: (begin_2022 - 1.year)..begin_2022).count
    bikes_2020 = bikes.where(created_at: begin_2020..(begin_2020 + 1.year)).count
    bikes_2019 = bikes.where(created_at: (begin_2020 - 1.year)..begin_2020).count
    bikes_2018 = bikes.where(created_at: (begin_2020 - 2.years)..(begin_2020 - 1.year)).count
    bikes_2017 = bikes.where(created_at: (begin_2020 - 3.years)..(begin_2020 - 2.years)).count
    country_name = bikes.where.not(country_id: nil).first&.country&.name
    vals = [country_name, city, zipcode, bikes.count,bikes_2022, bikes_2021, bikes_2020, bikes_2019, bikes_2018, (cities.uniq - [city.downcase]).join(", ")]
    redis.append(comma_wrapped_string(vals) + "\n")
  end
end
