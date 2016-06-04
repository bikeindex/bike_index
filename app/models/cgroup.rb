class Cgroup < ActiveRecord::Base
  # Note: Cgroup is short for component_group
  attr_accessible :name, :slug, :description

  validates_presence_of :name
  validates_uniqueness_of :name, :slug
  has_many :ctypes


  before_create :set_slug
  def set_slug
    # We don't care about updating the slug, since this information will rarely
    # if ever change, and the slug can always stay the same.
    self.slug = Slugifyer.slugify(self.name)
  end

  def self.additional_parts
    where(name: 'Additional parts').first_or_create
  end

end
