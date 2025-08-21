# == Schema Information
#
# Table name: impound_record_updates
#
#  id                :bigint           not null, primary key
#  kind              :integer
#  notes             :text
#  processed         :boolean          default(FALSE)
#  transfer_email    :string
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  impound_claim_id  :bigint
#  impound_record_id :bigint
#  location_id       :bigint
#  user_id           :bigint
#
# Indexes
#
#  index_impound_record_updates_on_impound_claim_id   (impound_claim_id)
#  index_impound_record_updates_on_impound_record_id  (impound_record_id)
#  index_impound_record_updates_on_location_id        (location_id)
#  index_impound_record_updates_on_user_id            (user_id)
#
FactoryBot.define do
  factory :impound_record_update do
    impound_record { FactoryBot.create(:impound_record_with_organization) }
    kind { ImpoundRecordUpdate.kinds.first }
    user { impound_record.user }
  end
end
