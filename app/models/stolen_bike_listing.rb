# frozen_string_literal: true

# Initially created for mexican stolen bike ring
class StolenBikeListing < ActiveRecord::Base
  include PgSearch::Model
  include Amountable
  include BikeSearchable

  GROUP_ENUM = {constru: 0}

  belongs_to :bike
  belongs_to :manufacturer
  belongs_to :primary_frame_color, class_name: "Color"
  belongs_to :secondary_frame_color, class_name: "Color"
  belongs_to :tertiary_frame_color, class_name: "Color"
  belongs_to :initial_listing, class_name: "StolenBikeListing"

  has_many :repeat_listings, class_name: "StolenBikeListing", foreign_key: :initial_listing_id

  before_save :set_calculated_attributes

  enum group: GROUP_ENUM

  scope :listing_ordered, -> { reorder(listing_order: :desc) }
  scope :initial, -> { where(initial_listing_id: nil) }
  scope :repeat, -> { where.not(initial_listing_id: nil) }

  pg_search_scope :pg_search, against: {
    frame_model: "A",
    listing: "B"
  }

  def self.search(interpreted_params)
    non_serial_matches(interpreted_params)
      .listing_ordered
  end

  def photo_urls
    data["photo_urls"]
  end

  def set_calculated_attributes
    self.mnfg_name = manufacturer.other? ? manufacturer_other : manufacturer.simple_name
    self.listed_at ||= Time.current
    self.listing_order = listed_at.to_i
  end
end
