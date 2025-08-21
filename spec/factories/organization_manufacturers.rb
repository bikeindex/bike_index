# == Schema Information
#
# Table name: organization_manufacturers
#
#  id              :bigint           not null, primary key
#  can_view_counts :boolean          default(FALSE)
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  manufacturer_id :bigint
#  organization_id :bigint
#
# Indexes
#
#  index_organization_manufacturers_on_manufacturer_id  (manufacturer_id)
#  index_organization_manufacturers_on_organization_id  (organization_id)
#
FactoryBot.define do
  factory :organization_manufacturer do
    organization { FactoryBot.create(:organization) }
    manufacturer { FactoryBot.create(:manufacturer) }
  end
end
