FactoryBot.define do
  factory :manufacturer do
    name { FactoryBot.generate(:unique_name) }
    frame_maker { true }
  end
end
