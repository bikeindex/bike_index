FactoryBot.define do
  factory :impound_record_update do
    impound_record { FactoryBot.create(:impound_record_with_organization) }
    kind { ImpoundRecordUpdate.kinds.first }
    user { impound_record.user }
  end
end
