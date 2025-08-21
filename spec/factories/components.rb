# frozen_string_literal: true

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
FactoryBot.define do
  factory :component do
    bike { FactoryBot.create(:bike) }
    ctype { FactoryBot.create(:ctype) }
  end
end
