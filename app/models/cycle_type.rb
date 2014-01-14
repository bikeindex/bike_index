class CycleType < ActiveRecord::Base
  # Defines things like unicycles and recumbent
  attr_accessible :name, :slug

  validates_presence_of :name
  validates_uniqueness_of :name, :slug

  has_many :bikes

  before_create :set_slug
  def set_slug
    self.slug = Slugifyer.slugify(self.name)
  end

  def self.fuzzy_name_find(n)
    if !n.blank?
      self.find(:first, :conditions => [ "lower(name) = ?", n.downcase.strip ])
    else
      nil
    end
  end

end
