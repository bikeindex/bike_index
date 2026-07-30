FactoryBot.define do
  factory :public_image do
    imageable { FactoryBot.create(:bike) }

    transient do
      filename { nil }
      image_path { "spec/fixtures/bike_photo-landscape.jpeg" }
    end

    after(:build) do |public_image, evaluator|
      next if public_image.image.present? || public_image.file.attached?

      model_type = public_image.imageable_type.underscore
      model_id = public_image.imageable.id
      filename = evaluator.filename || "#{model_type}-#{model_id}.jpg"
      public_image.image = File.open(ApplicationUploader.cache_dir.join(filename), "w+")
      public_image.save
    end

    trait :for_stolen_bike do
      imageable { FactoryBot.create(:stolen_bike) }
    end

    trait :with_image_file do
      image { File.open(Rails.root.join(image_path)) }
    end

    # ActiveStorage rather than CarrierWave
    trait :with_attached_file do
      file { {io: File.open(Rails.root.join(image_path)), filename: File.basename(image_path)} }
    end
  end
end
