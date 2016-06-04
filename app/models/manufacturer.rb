class Manufacturer < ActiveRecord::Base
  include AutocompleteHashable
  attr_accessible :name,
    :slug,
    :website,
    :frame_maker,
    :open_year,
    :close_year,
    :logo,
    :remote_logo_url,
    :logo_cache,
    :logo_source,
    :description

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

  def self.fuzzy_name_find(n)
    if !n.blank?
      n = Slugifyer.manufacturer(n)
      found = self.find(:first, conditions: [ "slug = ?", n ])
      return found if found.present?
      return self.find(:first, conditions: [ "slug = ?", fill_stripped(n)])
    else
      nil
    end
  end

  def self.other_manufacturer
    where(name: 'Other', frame_maker: true).first_or_create
  end

  def self.fuzzy_id_or_name_find(n)
    if n.kind_of?(Integer) || n.match(/\A\d*\z/).present?
      Manufacturer.where(id: n).first
    else
      Manufacturer.fuzzy_name_find(n)
    end
  end

  def self.fuzzy_id(n)
    m = self.fuzzy_id_or_name_find(n)
    return m.id if m.present?
  end

  def self.fill_stripped(n)
    n.gsub!(/accell/i,'') if n.match(/accell/i).present?
    Slugifyer.manufacturer(n)
  end

  def self.import(file)
    CSV.foreach(file.path, headers: true) do |row|
      manufacturer = find_by_name(row["name"]) || new
      manufacturer.attributes = row.to_hash.slice(*accessible_attributes)
      unless manufacturer.save
        puts "\n\n\n    #{row} \n\n"
      end
    end
  end

  def self.to_csv
    CSV.generate do |csv|
      csv << column_names
      all.each do |manufacturer|
        csv << manufacturer.attributes.values_at(*column_names)
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
    self.slug = Slugifyer.manufacturer(self.name)
  end

  def set_website_and_logo_source
    self.website = website.present? ? Urlifyer.urlify(website) : nil
    if logo.present?
      self.logo_source ||= 'manual'
    else
      self.logo_source = nil
    end
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
