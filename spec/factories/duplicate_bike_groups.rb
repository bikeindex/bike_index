# This is a little hacky, but it follows the way the code actually generates the duplicate bikes
# == Schema Information
#
# Table name: duplicate_bike_groups
#
#  id            :integer          not null, primary key
#  added_bike_at :datetime
#  ignore        :boolean          default(FALSE), not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
FactoryBot.define do
  factory :duplicate_bike_group do
    transient do
      serial_number { bike1.serial_number }
      bike1 { FactoryBot.create(:bike, serial_number: "duplicateserialnumber") }
      bike2 { FactoryBot.create(:bike, serial_number: serial_number) }
      normalized_serial_segments1 do
        bike1.create_normalized_serial_segments
        bike1.normalized_serial_segments
      end
    end

    after(:create) do |duplicate_bike_group, evaluator|
      evaluator.normalized_serial_segments1.update(duplicate_bike_group: duplicate_bike_group)
      evaluator.bike2.create_normalized_serial_segments
      DuplicateBikeFinderJob.new.perform(evaluator.bike2.id)
      duplicate_bike_group.reload
    end
  end
end
