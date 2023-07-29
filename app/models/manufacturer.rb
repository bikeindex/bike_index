class Manufacturer < ApplicationRecord
  include AutocompleteHashable

  has_many :bikes
  has_many :locks
  has_many :paints
  has_many :components

  mount_uploader :logo, AvatarUploader

  before_validation :set_calculated_attributes

  validates_presence_of :name
  validates_uniqueness_of :name
  validates_uniqueness_of :slug
  validate :ensure_non_blocking_name

  default_scope { order(:name) }

  scope :frame_makers, -> { where(frame_maker: true) }
  scope :with_websites, -> { where("website is NOT NULL and website != ''") }
  scope :with_logos, -> { where("logo is NOT NULL and logo != ''") }

  def self.export_columns
    %w[name slug website frame_maker open_year close_year logo remote_logo_url
      logo_cache logo_source description].map(&:to_sym).freeze
  end

  def self.friendly_find(n)
    return nil if n.blank?
    if n.is_a?(Integer) || n.match(/\A\d+\z/).present?
      where(id: n).first
    else
      ns = Slugifyer.manufacturer(n)
      find_by_slug(ns) || find_by_slug(fill_stripped(ns))
    end
  end

  def self.friendly_find_id(n)
    friendly_find(n)&.id
  end

  def self.other
    where(name: "Other", frame_maker: true).first_or_create
  end

  def self.fill_stripped(n)
    n.gsub!(/accell/i, "") if n.match(/accell/i).present?
    Slugifyer.manufacturer(n)
  end

  def self.import(file)
    CSV.foreach(file.path, headers: true, header_converters: :symbol) do |row|
      mnfg = find_by_name(row[:name]) || new
      mnfg.attributes = row.to_h.slice(*export_columns)
      next if mnfg.save
      puts "\n#{row} \n"
      fail mnfg.errors.full_messages.to_sentence
    end
  end

  def self.to_csv
    CSV.generate do |csv|
      csv << column_names
      all.each do |mnfg|
        csv << mnfg.attributes.values_at(*column_names)
      end
    end
  end

  def self.calculated_mnfg_name(manufacturer, manufacturer_other)
    return nil if manufacturer.blank?
    if manufacturer.other? && manufacturer_other.present?
      ParamsNormalizer.sanitize(manufacturer_other)
    else
      manufacturer.simple_name
    end.strip.truncate(60)
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

  def set_calculated_attributes
    self.slug = Slugifyer.manufacturer(name)
    self.website = website.present? ? Urlifyer.urlify(website) : nil
    self.logo_source = logo.present? ? (logo_source || "manual") : nil
    self.twitter_name = twitter_name.present? ? twitter_name.gsub(/\A@/, "") : nil
    true
  end

  def autocomplete_hash_category
    frame_maker ? "frame_mnfg" : "mnfg"
  end

  def autocomplete_hash_priority
    return 0 unless (bikes.count + components.count) > 0
    pop = (2 * bikes.count + components.count) / 20 + 10
    pop > 100 ? 100 : pop
  end

  def autocomplete_hash
    {
      id: id,
      text: name,
      category: autocomplete_hash_category,
      priority: autocomplete_hash_priority,
      data: {
        slug: slug,
        priority: autocomplete_hash_priority,
        search_id: search_id
      }
    }.as_json
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
end
