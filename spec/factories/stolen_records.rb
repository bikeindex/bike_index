# == Schema Information
#
# Table name: stolen_records
#
#  id                             :integer          not null, primary key
#  approved                       :boolean          default(FALSE), not null
#  can_share_recovery             :boolean          default(FALSE), not null
#  city                           :string(255)
#  create_open311                 :boolean          default(FALSE), not null
#  current                        :boolean          default(TRUE)
#  date_stolen                    :datetime
#  estimated_value                :integer
#  index_helped_recovery          :boolean          default(FALSE), not null
#  latitude                       :float
#  lock_defeat_description        :string(255)
#  locking_description            :string(255)
#  longitude                      :float
#  neighborhood                   :string
#  no_notify                      :boolean          default(FALSE)
#  phone                          :string(255)
#  phone_for_everyone             :boolean
#  phone_for_police               :boolean          default(TRUE)
#  phone_for_shops                :boolean          default(TRUE)
#  phone_for_users                :boolean          default(TRUE)
#  police_report_department       :string(255)
#  police_report_number           :string(255)
#  proof_of_ownership             :boolean
#  receive_notifications          :boolean          default(TRUE)
#  recovered_at                   :datetime
#  recovered_description          :text
#  recovery_display_status        :integer          default("not_eligible")
#  recovery_link_token            :text
#  recovery_posted                :boolean          default(FALSE)
#  recovery_share                 :text
#  recovery_tweet                 :text
#  secondary_phone                :string(255)
#  street                         :string(255)
#  theft_description              :text
#  tsved_at                       :datetime
#  zipcode                        :string(255)
#  created_at                     :datetime         not null
#  updated_at                     :datetime         not null
#  bike_id                        :integer
#  country_id                     :integer
#  creation_organization_id       :integer
#  organization_stolen_message_id :bigint
#  recovering_user_id             :integer
#  state_id                       :integer
#
# Indexes
#
#  index_stolen_records_on_bike_id                         (bike_id)
#  index_stolen_records_on_latitude_and_longitude          (latitude,longitude)
#  index_stolen_records_on_organization_stolen_message_id  (organization_stolen_message_id)
#  index_stolen_records_on_recovering_user_id              (recovering_user_id)
#
FactoryBot.define do
  factory :stolen_record do
    bike { FactoryBot.create(:bike) }
    date_stolen { Time.current }
    skip_geocoding { true }

    factory :stolen_record_recovered do
      bike { FactoryBot.create(:bike) }
      recovered_at { Time.current }
      recovered_description { "Awesome help by Bike Index" }
      current { false }
    end

    trait :with_images do
      transient do
        filename { Rails.root.join("spec/fixtures/bike_photo-landscape.jpeg") }
      end
      # NOTE: Only attaches 2 photos, because those are the only ones used currently
      after(:build) do |stolen_record, evaluator|
        stolen_record.image_four_by_five.attach(io: File.open(evaluator.filename),
          filename: "stolen-#{stolen_record.id}-four_by_five.jpeg")
        stolen_record.image_opengraph.attach(io: File.open(evaluator.filename),
          filename: "stolen-#{stolen_record.id}-opengraph.jpeg")
      end
    end

    trait :with_alert_image do
      transient do
        filename { nil }
      end

      after(:create) do |stolen_record, evaluator|
        FactoryBot.create(:alert_image,
          :with_image,
          stolen_record: stolen_record,
          filename: evaluator.filename)
      end
    end

    trait :with_bike_image do
      bike { FactoryBot.create(:bike, :with_image) }
    end
  end
end
