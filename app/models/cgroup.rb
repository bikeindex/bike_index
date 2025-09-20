# == Schema Information
#
# Table name: cgroups
#
#  id          :integer          not null, primary key
#  description :string(255)
#  name        :string(255)
#  priority    :integer          default(1)
#  slug        :string(255)
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
class Cgroup < ApplicationRecord
  # Note: Cgroup is short for component_group
  include FriendlySlugFindable

  validates_presence_of :name, :priority

  has_many :ctypes

  scope :commonness, -> { reorder("cgroups.priority ASC, cgroups.name DESC") }

  def self.additional_parts
    find_by(name: "Additional parts") || create(name: "Additional parts", priority: 4)
  end
end
