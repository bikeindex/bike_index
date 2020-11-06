FactoryBot.define do
  factory :ownership_evidence do
    impound_record { FactoryBot.create(:impound_record) }
    user { FactoryBot.create(:user) }
    factory :ownership_evidence_with_stolen_record do
      transient do
        bike { FactoryBot.create(:bike, :with_ownership_claimed, creator: user, user: user) }
      end
      stolen_record { FactoryBot.create(:stolen_record, bike: bike) }
    end
  end
end
