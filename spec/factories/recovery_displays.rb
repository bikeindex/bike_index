FactoryBot.define do
  factory :recovery_display do
    quote { "Recovered!" }
    factory :recovery_display_with_stolen_record do
      stolen_record { FactoryBot.create(:stolen_record_recovered) }
    end
    factory :recovery_display_with_photo do
      after(:create) do |recovery_display|
        recovery_display.photo_processed.attach(io: StringIO.new("processed image"), filename: "processed.jpg",
          content_type: "image/jpeg")
      end
    end
  end
end
