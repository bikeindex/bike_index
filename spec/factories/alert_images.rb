# == Schema Information
#
# Table name: alert_images
#
#  id               :integer          not null, primary key
#  image            :string
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  stolen_record_id :integer          not null
#
# Indexes
#
#  index_alert_images_on_stolen_record_id  (stolen_record_id)
#
# Foreign Keys
#
#  fk_rails_...  (stolen_record_id => stolen_records.id)
#
FactoryBot.define do
  factory :alert_image do
    stolen_record { FactoryBot.create(:stolen_record) }
    image { nil }

    trait :with_image do
      transient do
        filename { nil }
      end

      after(:build) do |alert_image, evaluator|
        next if alert_image.image.present?

        stolen_record_id = alert_image.stolen_record_id
        filename = evaluator.filename || "stolen_record-#{stolen_record_id}.jpg"
        alert_image.image = File.open(ApplicationUploader.cache_dir.join(filename), "w+")

        alert_image.save
      end
    end
  end
end
