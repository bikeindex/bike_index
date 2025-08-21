# == Schema Information
#
# Table name: organization_model_audits
#
#  id                   :bigint           not null, primary key
#  bikes_count          :integer          default(0)
#  certification_status :integer
#  last_bike_created_at :datetime
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  model_audit_id       :bigint
#  organization_id      :bigint
#
# Indexes
#
#  index_organization_model_audits_on_model_audit_id   (model_audit_id)
#  index_organization_model_audits_on_organization_id  (organization_id)
#
FactoryBot.define do
  factory :organization_model_audit do
    organization { FactoryBot.create(:organization) }
    model_audit { FactoryBot.create(:model_audit) }
  end
end
