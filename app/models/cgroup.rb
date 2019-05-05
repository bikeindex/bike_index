class Cgroup < ActiveRecord::Base
  # Note: Cgroup is short for component_group
  include FriendlySlugFindable

  has_many :ctypes

  def self.additional_parts
    where(name: "Additional parts").first_or_create
  end
end
