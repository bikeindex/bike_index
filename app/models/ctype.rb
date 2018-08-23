class Ctype < ActiveRecord::Base
  # Note: Ctype is short for component_type.
  # The name had to be shortened because of join table key length
  include FriendlySlugFindable

  attr_accessor :cgroup_name

  belongs_to :cgroup

  mount_uploader :image, AvatarUploader

  has_many :components

  def self.other
    where(name: 'other', has_multiple: false, cgroup_id: Cgroup.additional_parts.id).first_or_create
  end

  def self.unknown
    where(name: 'unknown', has_multiple: false, cgroup_id: Cgroup.additional_parts.id).first_or_create
  end

  def self.old_attr_accessible
    %w(name slug secondary_name image image_cache cgroup_id cgroup has_multiple cgroup_name).map(&:to_sym).freeze
  end
  
  before_create :set_calculated_attributes
  def set_calculated_attributes
    return true unless self.cgroup_name.present?
    self.cgroup_id = Cgroup.friendly_find(cgroup_name)&.id
  end
end
