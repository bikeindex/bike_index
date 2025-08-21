# == Schema Information
#
# Table name: components
#
#  id                 :integer          not null, primary key
#  component_model    :string(255)
#  ctype_other        :string(255)
#  description        :text
#  front              :boolean
#  is_stock           :boolean          default(FALSE), not null
#  manufacturer_other :string(255)
#  mnfg_name          :string
#  rear               :boolean
#  serial_number      :string(255)
#  year               :integer
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  bike_id            :integer
#  bike_version_id    :bigint
#  ctype_id           :integer
#  manufacturer_id    :integer
#
# Indexes
#
#  index_components_on_bike_id          (bike_id)
#  index_components_on_bike_version_id  (bike_version_id)
#  index_components_on_manufacturer_id  (manufacturer_id)
#
class ComponentSerializer < ApplicationSerializer
  attributes :id,
    :description,
    :serial_number,
    :component_type,
    :component_group,
    :rear,
    :front,
    :manufacturer_name,
    :model_name,
    :year

  def model_name
    object.component_model
  end

  def manufacturer_name
    object.mnfg_name
  end
end
