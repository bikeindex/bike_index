class ImportStolenBikeListingJob < ApplicationJob
  sidekiq_options retry: false
  HEADERS = %i[line listed_at folder bike price repost manufacturer model size color bike_index_bike notes listing_text].freeze

  def self.headers
    override_headers = ENV["IMPORT_STOLEN_LISTING_HEADERS"]
    override_headers.present? ? override_headers.split(",").map(&:to_i) : HEADERS
  end

  def self.row_from_str(row_str)
    CSV.new(row_str, headers: headers).first.to_h
  end

  def perform(group, line, row_str)
    row = self.class.row_from_str(row_str)
    return nil if skip_storing?(row)

    stolen_bike_listing = StolenBikeListing.where(group: group, line: line).first
    stolen_bike_listing ||= StolenBikeListing.new(group: group, line: line)
    stolen_bike_listing.attributes = {
      currency: "MXN",
      frame_model: row[:model],
      listing_text: row[:listing_text],
      amount: row[:price].presence,
      frame_size: row[:size],
      data: {
        photo_folder: row[:folder],
        photo_urls: row[:photo_urls],
        notes: row[:notes]
      }
    }
    stolen_bike_listing.listed_at = BinxUtils::TimeParser.parse(row[:listed_at]) if row[:listed_at]
    stolen_bike_listing.attributes = manufacturer_attrs(row[:manufacturer])
    stolen_bike_listing.attributes = color_attrs(row[:color])
    stolen_bike_listing.bike_id = find_bike_id(row[:bike_index_bike])
    stolen_bike_listing.save
    stolen_bike_listing
  end

  def manufacturer_attrs(str)
    mnfg = Manufacturer.friendly_find(str)
    return {manufacturer_id: mnfg.id} if mnfg.present?

    {manufacturer_id: Manufacturer.other.id, manufacturer_other: str}
  end

  def color_attrs(str)
    colors = str.to_s.split(/\/|,/).map { |c| Paint.paint_name_parser(c) }
    color_ids = colors.map { |c| Color.friendly_find_id(c) }.reject(&:blank?)
    {
      primary_frame_color_id: color_ids[0] || Color.black.id,
      secondary_frame_color_id: color_ids[1],
      tertiary_frame_color_id: color_ids[2]
    }
  end

  def find_bike_id(str)
    return nil if str.blank?

    # Just grab any integers longer than 2 digits, good enough for now
    str[/\d\d+/]
  end

  def skip_storing?(row)
    return true if row[:bike].to_s.match?(/no|raffle/i)

    # We aren't storing reposts - just for now, we'll add sometime
    repost = row[:repost].present? && !row[:repost].to_s.match?(/no/i)
    return true if repost

    # Don't store if there is data that is useful in any columns
    row.slice(:color, :manufacturer, :model, :listing_text)
      .values.join("").gsub(/\s+/, " ").gsub("blank", "").gsub("raffle", "")
      .length < 5
  end
end
