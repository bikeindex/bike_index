FactoryBot.define do
  factory :recovery_display do
    quote { "Recovered!" }
    factory :recovery_display_with_stolen_record do
      stolen_record { FactoryBot.create(:stolen_record_recovered) }
    end
  end
end
