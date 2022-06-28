class CountsByYearWorker < ApplicationWorker
  sidekiq_options queue: "low_priority"
  sidekiq_options retry: false

  YEARS = [2017, 2018, 2019, 2020, 2021, 2022].freeze
  COUNT_TYPES = %w[shop_reg other_nonself_reg self_reg stolen_bikes]

  def redis
    Redis.current
  end

  def redis_key
    "bike_counts_by_year"
  end

  def comma_wrapped_string(array)
    array.map { |val| '"' + val.to_s.tr("\\", "").gsub(/(\\)?"/, '\"') + '"'}.join(",") + "\n"
  end

  def headers
    (%w[Country City State Total] +
      YEARS.map { |y| COUNT_TYPES.map { |c| "#{y}-#{c}" } }
    ).flatten
  end

  def perform(city, state_id = nil, country_id = nil)
    row = row_from_place(city, state_id, country_id)
    redis.append(redis_key, comma_wrapped_string(row))
  end

  def row_from_place(city, state_id, country_id)
    bike_ids = Bike.unscoped.where("lower(city) = ?", city)
      .where(state_id: state_id, country_id: country_id)
      .pluck(:id)

    if state_id.present? && country_id == 230
      bike_ids =+ Bike.unscoped.where("lower(city) = ?", city)
        .where(state_id: nil, country_id: country_id)
        .pluck(:id)
    end

    row = [
      Country.find_by_id(country_id)&.iso,
      city,
      State.find_by_id(state_id)&.abbreviation,
      bike_ids.uniq.count
    ]

    YEARS.each do |year|
      year_range = Date.ordinal(year).beginning_of_year..Date.ordinal(year).end_of_year
      ownerships = Ownership.where(created_at: year_range).where(bike_id: bike_ids)

      row += [
        ownerships.where.not(pos_kind: "no_pos").count,
        ownerships.where(pos_kind: "no_pos").not_self_made.count,
        ownerships.where(pos_kind: "no_pos").self_made.count,
        StolenRecord.unscoped.where(date_stolen: year_range).where(bike_id: bike_ids).count
      ]
    end

    row
  end
end
