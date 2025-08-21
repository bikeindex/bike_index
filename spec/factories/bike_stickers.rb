# == Schema Information
#
# Table name: bike_stickers
#
#  id                        :integer          not null, primary key
#  claimed_at                :datetime
#  code                      :string
#  code_integer              :bigint
#  code_number_length        :integer
#  code_prefix               :string
#  kind                      :integer          default("sticker")
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  bike_id                   :integer
#  bike_sticker_batch_id     :integer
#  organization_id           :integer
#  previous_bike_id          :integer
#  secondary_organization_id :bigint
#  user_id                   :integer
#
# Indexes
#
#  index_bike_stickers_on_bike_id                    (bike_id)
#  index_bike_stickers_on_bike_sticker_batch_id      (bike_sticker_batch_id)
#  index_bike_stickers_on_secondary_organization_id  (secondary_organization_id)
#
FactoryBot.define do
  factory :bike_sticker do
    sequence(:code) { |n| "999#{n}" }

    factory :bike_sticker_claimed do
      transient do
        user { FactoryBot.create(:user) }
        bike { FactoryBot.create(:bike) }
      end
      after(:create) do |bike_sticker, evaluator|
        # Have to set these things or previous_bike_id doesn't work correctly,
        # ... because transient doesn't skip assigning the attributes if they exist.
        # NOTE: passing bike_id or user_id (rather than bike/user) doesn't work correctly
        bike_claiming = evaluator.bike || bike_sticker.bike
        user_claiming = evaluator.user || bike_sticker.user
        bike_sticker.bike_id = nil
        bike_sticker.user_id = nil
        bike_sticker.claim(bike: bike_claiming, user: user_claiming)
      end
    end
  end
end
