class ImportStolenBikeListingWorker < ApplicationWorker
  def perform(group, line, row)
    stolen_bike_listing = StolenBikeListing.new(currency: "MXN",
                                                frame_model: row["frame_model"],
                                                listing_text: row["listing"],
                                                amount: row["price"],
                                                group: group,
                                                line: line,
                                                data: {
                                                  photo_folder: row["folder"],
                                                  photo_urls: row["photo_urls"],
                                                  notes: row["notes"],
                                                })
    stolen_bike_listing.listed_at = TimeParser.parse(row["listed_at"]) if row["listed_at"].present?
    stolen_bike_listing.attributes = manufacturer_attrs(row["manufacturer"])
    stolen_bike_listing.attributes = color_attrs(row["color"])
    stolen_bike_listing.bike_id = find_bike_id(row["owner_found"])
    stolen_bike_listing.save
    stolen_bike_listing
  end

  def manufacturer_attrs(str)
    mnfg = Manufacturer.friendly_find(str)
    return {manufacturer_id: mnfg.id} if mnfg.present?
    {manufacturer_id: Manufacturer.other.id, manufacturer_other: str}
  end

  def color_attrs(str)
    colors = str.split(/\/|,/).map { |c| Paint.paint_name_parser(c) }
    color_ids = colors.map { |c| Color.friendly_id_find(c) }.reject(&:blank?)
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
end
