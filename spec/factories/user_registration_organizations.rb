# == Schema Information
#
# Table name: user_registration_organizations
#
#  id                   :bigint           not null, primary key
#  all_bikes            :boolean          default(FALSE)
#  can_not_edit_claimed :boolean          default(FALSE)
#  deleted_at           :datetime
#  registration_info    :jsonb
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  organization_id      :bigint
#  user_id              :bigint
#
# Indexes
#
#  index_user_registration_organizations_on_organization_id  (organization_id)
#  index_user_registration_organizations_on_user_id          (user_id)
#
FactoryBot.define do
  factory :user_registration_organization do
    user { FactoryBot.create(:user_confirmed) }
    organization { FactoryBot.create(:organization) }
    all_bikes { organization.user_registration_all_bikes? }
  end
end
