FactoryBot.define do
  factory :impound_record_updates do
    impound_record { FactoryBot.create(:impound_record) }
    kind { ImpoundRecord.kinds.first }
    user { impound_record.user }
  end
end
