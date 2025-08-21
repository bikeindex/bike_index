# == Schema Information
#
# Table name: organization_statuses
#
#  id                      :bigint           not null, primary key
#  end_at                  :datetime
#  kind                    :integer
#  organization_deleted_at :datetime
#  pos_kind                :integer
#  start_at                :datetime
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  organization_id         :bigint
#
# Indexes
#
#  index_organization_statuses_on_organization_id  (organization_id)
#
FactoryBot.define do
  factory :organization_status do
    start_at { Time.current - 5.minutes }
    pos_kind { :lightspeed_pos }
    organization { FactoryBot.create(:organization, pos_kind: pos_kind) }
  end
end
