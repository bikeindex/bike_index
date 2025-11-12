# frozen_string_literal: true

# == Schema Information
#
# Table name: stolen_bike_listings
# Database name: primary
#
#  id                       :bigint           not null, primary key
#  amount_cents             :integer
#  currency_enum            :integer
#  data                     :jsonb
#  frame_model              :text
#  frame_size               :string
#  frame_size_number        :float
#  frame_size_unit          :string
#  group                    :integer
#  line                     :integer
#  listed_at                :datetime
#  listing_order            :integer
#  listing_text             :text
#  manufacturer_other       :string
#  mnfg_name                :string
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  bike_id                  :bigint
#  initial_listing_id       :bigint
#  manufacturer_id          :bigint
#  primary_frame_color_id   :bigint
#  secondary_frame_color_id :bigint
#  tertiary_frame_color_id  :bigint
#
# Indexes
#
#  index_stolen_bike_listings_on_bike_id                   (bike_id)
#  index_stolen_bike_listings_on_initial_listing_id        (initial_listing_id)
#  index_stolen_bike_listings_on_manufacturer_id           (manufacturer_id)
#  index_stolen_bike_listings_on_primary_frame_color_id    (primary_frame_color_id)
#  index_stolen_bike_listings_on_secondary_frame_color_id  (secondary_frame_color_id)
#  index_stolen_bike_listings_on_tertiary_frame_color_id   (tertiary_frame_color_id)
#

# Initially created for mexican stolen bike ring
class StolenBikeListing < ActiveRecord::Base
  include PgSearch::Model
  include Currencyable
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

  enum :group, GROUP_ENUM

  scope :listing_ordered, -> { reorder(listing_order: :desc) }
  scope :initial, -> { where(initial_listing_id: nil) }
  scope :repeat, -> { where.not(initial_listing_id: nil) }

  pg_search_scope :pg_search, against: {
    frame_model: "A",
    mnfg_name: "A",
    listing_text: "B"
  }

  def self.search(interpreted_params)
    non_serial_matches(interpreted_params)
      .listing_ordered
  end

  def self.find_by_folder(str)
    find { |l| l.updated_photo_folder == str }
  end

  def photo_urls
    (data["photo_urls"] || []).sort
  end

  def full_photo_urls
    photo_urls.map { |u| "https://files.bikeindex.org/theft-rings/#{u}" }
  end

  def photo_folder
    data["photo_folder"]
  end

  def amount_usd_formatted
    cents_usd = data["amount_cents_usd"] || calculated_amount_cents_usd
    MoneyFormatter.money_format_without_cents(cents_usd, :USD)
  end

  def calculated_amount_cents_usd
    return 0 unless amount_cents.present?

    Money.new(amount_cents, currency_name).exchange_to(:USD).cents
  end

  def updated_photo_folder
    return nil if photo_folder.blank?

    suffix = photo_folder[/_\d+\z/].to_s
    if suffix.blank? # Sometimes there folders like 2021_OMFG
      suffix = photo_folder[/20\d\d_.*\z/].to_s
      suffix = suffix.gsub(/\A20\d\d/, "")
    end
    suffix = nil if suffix.present? && suffix.match?(/20\d\d/)
    date = TimeParser.parse(photo_folder.gsub(/\d+\//, ""))
    "#{date.year}/#{date.month}/#{date.strftime("%Y-%-m-%-d")}#{suffix}"
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
    self.data ||= {}
    self.mnfg_name = if manufacturer.present?
      manufacturer.other? ? manufacturer_other : manufacturer.short_name
    end
    self.listed_at ||= Time.current
    self.listing_order = listed_at.to_i
    # CSVs are hard. I encode double quotes and then decode them here
    self.listing_text = listing_text.gsub("&#34;", '"') if listing_text.present?
    self.data ||= {}
    self.data["amount_cents_usd"] = calculated_amount_cents_usd
    clean_frame_size
  end
end
