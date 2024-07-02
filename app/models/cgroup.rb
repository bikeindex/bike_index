# == Schema Information
#
# Table name: cgroups
#
#  id          :integer          not null, primary key
#  description :string(255)
#  name        :string(255)
#  slug        :string(255)
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
class Cgroup < ApplicationRecord
  # Note: Cgroup is short for component_group
  include FriendlySlugFindable

  has_many :ctypes

  def self.additional_parts
    where(name: "Additional parts").first_or_create
  end
end
