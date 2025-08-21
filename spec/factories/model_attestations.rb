# == Schema Information
#
# Table name: model_attestations
#
#  id                 :bigint           not null, primary key
#  certification_type :string
#  file               :string
#  info               :text
#  kind               :integer
#  replaced           :boolean          default(FALSE)
#  url                :text
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  model_audit_id     :bigint
#  organization_id    :bigint
#  user_id            :bigint
#
# Indexes
#
#  index_model_attestations_on_model_audit_id   (model_audit_id)
#  index_model_attestations_on_organization_id  (organization_id)
#  index_model_attestations_on_user_id          (user_id)
#
FactoryBot.define do
  factory :model_attestation do
    model_audit { FactoryBot.create(:model_audit) }
    kind { :certified_by_manufacturer }
    user { FactoryBot.create(:user) }
  end
end
