# == Schema Information
#
# Table name: manufacturers
#
#  id                 :integer          not null, primary key
#  close_year         :integer
#  description        :text
#  frame_maker        :boolean
#  logo               :string(255)
#  logo_source        :string(255)
#  motorized_only     :boolean          default(FALSE)
#  name               :string(255)
#  notes              :text
#  open_year          :integer
#  priority           :integer
#  secondary_slug     :string
#  slug               :string(255)
#  total_years_active :string(255)
#  twitter_name       :string
#  website            :string(255)
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#
class Manufacturer < ApplicationRecord
  include AutocompleteHashable
  MEMOIZE_OTHER = ENV["SKIP_MEMOIZE_MANUFACTURER_OTHER"].blank? # enable skipping for testing

  has_many :bikes
  has_many :locks
  has_many :paints
  has_many :components

  mount_uploader :logo, ManufacturerLogoUploader

  before_validation :set_calculated_attributes

  validates_presence_of :name
  validates_uniqueness_of :name
  validates_uniqueness_of :slug
  validates_uniqueness_of :secondary_slug, allow_nil: true
  validate :ensure_non_blocking_name

  default_scope { order(:name) }

  scope :frame_makers, -> { where(frame_maker: true) }
  scope :with_websites, -> { where("website is NOT NULL and website != ''") }
  scope :with_logos, -> { where("logo is NOT NULL and logo != ''") }

  class << self
    def export_columns
      %w[name slug website frame_maker open_year close_year logo remote_logo_url
        logo_cache logo_source description].map(&:to_sym).freeze
    end

    # Secondary_slug is the slug of the stuff in the paretheses
    def find_by_secondary_slug(str)
      return nil if str.blank?
      super
    end

    def friendly_find(n)
      return nil if n.blank?
      if n.is_a?(Integer) || n.match(/\A\d+\z/).present?
        where(id: n).first
      else
        ns = Slugifyer.manufacturer(n)
        find_by_slug(ns) || find_by_slug(fill_stripped(ns)) ||
          find_by_secondary_slug(ns)
      end
    end

    def friendly_find_id(n)
      friendly_find(n)&.id
    end

    def other
      return @other if MEMOIZE_OTHER && defined?(@other)
      @other = where(name: "Other", frame_maker: true).first_or_create
    end

    def fill_stripped(n)
      n.gsub!(/accell/i, "") if n.match(/accell/i).present?
      Slugifyer.manufacturer(n)
    end

    def import(file)
      CSV.foreach(file.path, headers: true, header_converters: :symbol) do |row|
        mnfg = find_by_name(row[:name]) || new
        mnfg.attributes = row.to_h.slice(*export_columns)
        next if mnfg.save
        puts "\n#{row} \n"
        fail mnfg.errors.full_messages.to_sentence
      end
    end

    def to_csv
      CSV.generate do |csv|
        csv << column_names
        all.each do |mnfg|
          csv << mnfg.attributes.values_at(*column_names)
        end
      end
    end

    def calculated_mnfg_name(manufacturer, manufacturer_other)
      return nil if manufacturer.blank?
      if manufacturer.other? && manufacturer_other.present?
        InputNormalizer.sanitize(manufacturer_other)
      else
        manufacturer.simple_name
      end.strip.truncate(60)
    end
  end

  def to_param
    slug
  end

  def official_organization
    @official_organization ||= Organization.find_by_manufacturer_id(id)
  end

  # Because of issues with autocomplete if the names are the same
  # Also, probably just a good idea in general
  def ensure_non_blocking_name
    return true unless name
    errors.add(:name, :cannot_match_a_color_name) if Color.pluck(:name).map(&:downcase).include?(name.strip.downcase)
  end

  def secondary_name
    s_name = name&.gsub(/\A[^(]*/, "")&.gsub(/\(|\)/, "")
    s_name.present? ? s_name : nil
  end

  def set_calculated_attributes
    self.name = InputNormalizer.string(name)
    self.secondary_slug = Slugifyer.manufacturer(secondary_name)
    self.slug = Slugifyer.manufacturer(name)
    self.website = website.present? ? Urlifyer.urlify(website) : nil
    self.logo_source = logo.present? ? (logo_source || "manual") : nil
    self.twitter_name = twitter_name.present? ? twitter_name.gsub(/\A@/, "") : nil
    self.description = nil if description.blank?
    self.priority = calculated_priority # scheduled updates via UpdateManufacturerLogoAndPriorityJob
    true
  end

  def autocomplete_hash_category
    frame_maker ? "frame_mnfg" : "cmp_mnfg"
  end

  def autocomplete_hash
    {
      id: id,
      text: name,
      category: autocomplete_hash_category,
      priority: priority,
      data: {
        slug: slug,
        priority: priority,
        search_id: search_id
      }
    }
  end

  def search_id
    "m_#{id}"
  end

  def other?
    name == "Other"
  end

  def simple_name
    name.gsub(/\s?\([^)]*\)/i, "")
  end

  def alternate_name
    return nil unless name.match?(/\(/)

    name.split("(").last.tr(")", "")
  end

  # Can't be private because it's called by UpdateManufacturerLogoAndPriorityJob
  def calculated_priority
    return 100 if b_count > 999
    return 0 if (b_count + c_count) == 0
    pop = (2 * b_count + c_count) / 20 + 10
    (pop > 100) ? 100 : pop
  end

  private

  def b_count
    @b_count ||= bikes.limit(1000).count
  end

  def c_count
    @c_count ||= components.limit(2000).count
  end
end
