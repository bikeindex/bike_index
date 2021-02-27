# frozen_string_literal: true

class TheftRingListing < ActiveRecord::Base
  include PgSearch::Model
  include Amountable
  include BikeSearchable

  belongs_to :bike
  belongs_to :manufacturer
  belongs_to :primary_frame_color, class_name: "Color"
  belongs_to :secondary_frame_color, class_name: "Color"
  belongs_to :tertiary_frame_color, class_name: "Color"
  belongs_to :initial_listing, class_name: "TheftRingListing"

  scope :listing_ordered, -> { reorder(listed_at: :desc) }
  scope :initial, -> { where(initial_listing_id: nil) }
  scope :repeat, -> { where.not(initial_listing_id: nil) }

  pg_search_scope :pg_search, against: {
    listing: "A",
  }

  def self.default_currency
    "PESO" # IDK the abbreviation
  end

  def self.search(interpreted_params)
    non_serial_matches(interpreted_params)
      .listing_ordered
  end

  def self.import(row)
    create(
      manufacturer: )
  end

  def photo_urls
    data["photo_urls"]
  end

  # be rails g model theft_ring_record

  # t.references :bike
  # t.references :initial_listing
  # t.string :manufacturer_other
  # t.references :manufacturer
  # t.references :primary_frame_color
  # t.references :secondary_frame_color
  # t.references :tertiary_frame_color
  # t.text :frame_model
  # t.datetime :listed_at
  # t.integer :amount_cents
  # t.text :listing
  # t.jsonb :data
end
