class Ctype < ActiveRecord::Base
  # Note: Ctype is short for component_type.
  # The name had to be shortened because of join table key length
  include FriendlySlugFindable

  attr_accessor :cgroup_name

  validates_presence_of :name
  validates_uniqueness_of :name, :slug

  belongs_to :cgroup

  mount_uploader :image, AvatarUploader

  has_many :components

  class << self
    def other
      where(name: 'other', has_multiple: false, cgroup_id: Cgroup.additional_parts.id).first_or_create
    end

    def unknown
      where(name: 'unknown', has_multiple: false, cgroup_id: Cgroup.additional_parts.id).first_or_create
    end

    def old_attr_accessible
      %w(name slug secondary_name image image_cache cgroup_id cgroup has_multiple cgroup_name).map(&:to_sym).freeze
    end
  end
  
  before_create :set_cgroup_from_name
  def set_cgroup_from_name
    if self.cgroup_name.present?
      self.cgroup_id = Cgroup.find_by_name(self.cgroup_name).id
    end
  end
end
