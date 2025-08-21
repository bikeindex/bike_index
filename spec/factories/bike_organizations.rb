# == Schema Information
#
# Table name: bike_organizations
#
#  id                   :integer          not null, primary key
#  can_not_edit_claimed :boolean          default(FALSE), not null
#  deleted_at           :datetime
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  bike_id              :integer
#  organization_id      :integer
#
# Indexes
#
#  index_bike_organizations_on_bike_id          (bike_id)
#  index_bike_organizations_on_deleted_at       (deleted_at)
#  index_bike_organizations_on_organization_id  (organization_id)
#
FactoryBot.define do
  factory :bike_organization do
    bike { FactoryBot.create(:bike) }
    organization { FactoryBot.create(:organization) }
  end
end
