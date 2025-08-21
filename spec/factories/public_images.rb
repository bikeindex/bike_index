# == Schema Information
#
# Table name: public_images
#
#  id                 :integer          not null, primary key
#  external_image_url :text
#  image              :string(255)
#  imageable_type     :string(255)
#  is_private         :boolean          default(FALSE), not null
#  kind               :integer          default("photo_uncategorized")
#  listing_order      :integer          default(0)
#  name               :string(255)
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  imageable_id       :integer
#
# Indexes
#
#  index_public_images_on_imageable_id_and_imageable_type  (imageable_id,imageable_type)
#
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

    trait :with_image_file do
      transient do
        image_path { "spec/fixtures/bike_photo-landscape.jpeg" }
      end
      image { File.open(Rails.root.join(image_path)) }
    end
  end
end
