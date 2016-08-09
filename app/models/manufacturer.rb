class Manufacturer < ActiveRecord::Base
  include AutocompleteHashable

  validates_presence_of :name
  validates_uniqueness_of :name
  validates_uniqueness_of :slug
  has_many :bikes
  has_many :locks
  has_many :paints
  has_many :components

  mount_uploader :logo, AvatarUploader
  default_scope { order(:name) }

  scope :frames, -> { where(frame_maker: true) }
  scope :with_websites, -> { where("website is NOT NULL and website != ''") }
  scope :with_logos, -> { where("logo is NOT NULL and logo != ''") }

  validate :ensure_non_blocking_name

  def to_param
    slug
  end

  class << self
    def old_attr_accessible
    %w(name slug website frame_maker open_year close_year logo remote_logo_url
       logo_cache logo_source description).map(&:to_sym).freeze
    end

    def friendly_find(n)
      return nil if n.blank?
      if n.is_a?(Integer) || n.match(/\A\d*\z/).present?
        where(id: n).first
      else
        ns = Slugifyer.manufacturer(n)
        find_by_slug(ns) || find_by_slug(fill_stripped(ns))
      end
    end

    def friendly_id_find(n)
      m = friendly_find(n)
      m && m.id
    end

    def other_manufacturer
      where(name: 'Other', frame_maker: true).first_or_create
    end

    def fill_stripped(n)
      n.gsub!(/accell/i,'') if n.match(/accell/i).present?
      Slugifyer.manufacturer(n)
    end

    def import(file)
      CSV.foreach(file.path, headers: true, header_converters: :symbol) do |row|
        mnfg = find_by_name(row[:name]) || new
        mnfg.attributes = row.to_hash.slice(*old_attr_accessible)
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
  end

  validate :ensure_non_blocking_name
  # Because of issues with autocomplete if the names are the same
  # Also, probably just a good idea in general
  def ensure_non_blocking_name
    return true unless name
    errors.add(:name, 'Cannot be the same as a color name') if Color.pluck(:name).map(&:downcase).include?(name.strip.downcase)
  end

  before_save :set_slug, :set_website_and_logo_source
  def set_slug
    self.slug = Slugifyer.manufacturer(name)
  end

  def set_website_and_logo_source
    self.website = website.present? ? Urlifyer.urlify(website) : nil
    self.logo_source = logo.present? ? (logo_source || 'manual') : nil
    true
  end

  def autocomplete_hash_category
    frame_maker ? 'frame_mnfg' : 'mnfg'
  end

  def autocomplete_hash_priority
    return 0 unless (bikes.count + components.count) > 0
    pop = (2*bikes.count + components.count) / 20 + 10
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
        search_id: "m_#{id}"
      }
    }.as_json
  end
end
