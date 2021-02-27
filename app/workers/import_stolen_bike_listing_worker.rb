class ImportStolenBikeListingWorker < ApplicationWorker
  def perform(row)
    stolen_bike_listing = StolenBikeListing.new(amount: row["price"),
      frame_model: row["frame_model"],
      listing: row["listing"])
    stolen_bike_listing.listed_at = TimeParser.parse(row["listed_at"]) if row["listed_at"].present?
    stolen_bike_listing.data = { photo_urls: row["photo_urls"] }
    stolen_bike_listing.attrs = manufacturer_attrs(row["manufacturer"])
    stolen_bike_listing.attrs = color_attrs(row["color"])
    stolen_bike_listing.save
    stolen_bike_listing
  end

  def manufacturer_attrs(str)
    mnfg = Manufacturer.friendly_find(str)
    return { manufacturer_id: mnfg.id } if mnfg.present?
    { manufacturer_id: Manufacturer.other.id, manufacturer_other: str }
  end

  def color_attrs(str)
    colors = str.split(/\/|,/).map { |c| Paint.paint_name_parser(c) }
    color_ids = colors.map { |c| Color.friendly_find(c) }.reject(&:blank?)
    {
      primary_frame_color_id: color_ids[0],
      secondary_frame_color_id: color_ids[1],
      tertiary_frame_color_id: color_ids[2]
    }
  end
end
