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
    data["photo_urls"] || []
  end

  def frame_colors
    [
      primary_frame_color&.name,
      secondary_frame_color&.name,
      tertiary_frame_color&.name
    ].compact
  end

  # TODO: Refactor - this duplicates bike#clean_frame_size, they should both be better
  def clean_frame_size
    return true unless frame_size.present? || frame_size_number.present?
    if frame_size.present? && frame_size.match(/\d+\.?\d*/).present?
      # Don't overwrite frame_size_number if frame_size_number was passed
      if frame_size_number.blank? || !frame_size_number_changed?
        self.frame_size_number = frame_size.match(/\d+\.?\d*/)[0].to_f
      end
    end

    if frame_size_unit.blank?
      self.frame_size_unit = if frame_size_number.present?
        if frame_size_number < 30 # Good guessing?
          "in"
        else
          "cm"
        end
      else
        "ordinal"
      end
    end

    self.frame_size = if frame_size_number.present?
      frame_size_number.to_s.gsub(".0", "") + frame_size_unit
    else
      case frame_size.downcase
                        when /xxs/
                          "xxs"
                        when /x*sma/, "xs"
                          "xs"
                        when /sma/, "s"
                          "s"
                        when /med/, "m"
                          "m"
                        when /(lg)|(large)/, "l"
                          "l"
                        when /xxl/
                          "xxl"
                        when /x*l/, "xl"
                          "xl"
      end
    end
    true
  end

  def set_calculated_attributes
    self.mnfg_name = if manufacturer.present?
      manufacturer.other? ? manufacturer_other : manufacturer.simple_name
    end
    self.listed_at ||= Time.current
    self.listing_order = listed_at.to_i
    # CSVs are hard. I encode double quotes and then decode them here
    self.listing_text = listing_text.gsub("&#34;", '"') if listing_text.present?
    clean_frame_size
  end
end
