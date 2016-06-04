class Ctype < ActiveRecord::Base
  # Note: Ctype is short for component_type.
  # The name had to be shortened because of join table key length
  attr_accessible :name,
    :slug,
    :secondary_name,
    :image,
    :image_cache,
    :cgroup_id,
    :cgroup,
    :has_multiple,
    :cgroup_name

  attr_accessor :cgroup_name

  validates_presence_of :name
  # validates_presence_of :cgroup
  validates_uniqueness_of :name, :slug

  belongs_to :cgroup

  mount_uploader :image, AvatarUploader

  has_many :components

  def to_param
    slug
  end

  def self.other
    where(name: 'other', has_multiple: false, cgroup_id: Cgroup.additional_parts.id).first_or_create
  end
  
  def self.import(file)
    CSV.foreach(file.path, headers: true) do |row|
      component_group = find_by_name(row["name"]) || new
      component_group.attributes = row.to_hash.slice(*accessible_attributes)
      component_group.save!
    end
  end

  before_create :set_cgroup_from_name
  def set_cgroup_from_name
    if self.cgroup_name.present?
      self.cgroup_id = Cgroup.find_by_name(self.cgroup_name).id
    end
  end

  before_save :set_slug
  def set_slug
    # We don't care about updating the slug, since this information will rarely
    # if ever change, and the slug can always stay the same.
    self.slug = Slugifyer.slugify(name)
  end

  def self.fuzzy_name_find(n)
    if !n.blank?
      n = Slugifyer.slugify(n)
      found = self.find(:first, conditions: [ "slug = ?", n ])
      return found if found.present?
    end
    nil
  end

end
