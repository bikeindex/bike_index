class Manufacturer < ActiveRecord::Base
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
  default_scope order(:name)

  scope :frames, where(frame_maker: true)
  scope :with_websites, where("website is NOT NULL and website != ''")
  scope :with_logos, where("logo is NOT NULL and logo != ''")

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

  
  before_save :set_slug
  def set_slug
    self.slug = Slugifyer.manufacturer(self.name)
  end

  def sm_options(all=false)
    score = bikes.count
    score = score + components.count if all
    {
      id: id,
      term: name,
      score: score,
      data: {}
    }
  end

  before_save :set_website_and_logo_source
  def set_website_and_logo_source
    self.website = website.present? ? Urlifyer.urlify(website) : nil
    if logo.present?
      self.logo_source ||= 'manual' 
    else
      self.logo_source = nil
    end
    true
  end

end
