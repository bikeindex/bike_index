# == Schema Information
#
# Table name: ctypes
#
#  id             :integer          not null, primary key
#  has_multiple   :boolean          default(FALSE), not null
#  image          :string(255)
#  name           :string(255)
#  secondary_name :string(255)
#  slug           :string(255)
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  cgroup_id      :integer
#
class CtypeSerializer < ApplicationSerializer
  attributes :name,
    :slug,
    :has_multiple

  self.root = "component_types"
end
