# frozen_string_literal: true

FactoryBot.define do
  factory :rear_gear_type do
    sequence(:name) { |n| "Rear Gear #{n}" }
    count { 1 }
  end
end
