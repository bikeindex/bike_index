FactoryBot.define do
  factory :public_image do
    imageable { FactoryBot.create(:bike) }

    transient do
      filename { nil }
    end

    after(:build) do |public_image, evaluator|
      next if public_image.image.present?
      model_type = public_image.imageable_type.underscore
      model_id = public_image.imageable.id
      filename = evaluator.filename || "#{model_type}-#{model_id}.jpg"
      public_image.image = File.open(ApplicationUploader.cache_dir.join(filename), "w+")
      public_image.save
    end

    trait :for_stolen_bike do
      imageable { FactoryBot.create(:stolen_bike) }
    end
  end
end
