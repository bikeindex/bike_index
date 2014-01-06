class Manufacturer < ActiveRecord::Base
  attr_accessible :name,
    :slug,
    :website,
    :frame_maker,    
    :open_year,
    :close_year,
    :logo,
    :logo_cache,
    :description

  validates_presence_of :name
  validates_uniqueness_of :name
  validates_uniqueness_of :slug
  has_many :bikes
  has_many :locks

  mount_uploader :logo, AvatarUploader
  default_scope order(:name)

  scope :frames, where(frame_maker: true)

  def to_param
    slug
  end

  def self.fuzzy_name_find(n)
    if !n.blank?
      self.find(:first, :conditions => [ "lower(name) = ?", n.downcase.strip ])
    else
      nil
    end
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

  
  before_create :set_slug
  def set_slug
    self.slug = Slugifyer.slugify(self.name)
  end

end
