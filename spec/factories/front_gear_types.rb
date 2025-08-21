# frozen_string_literal: true

FactoryBot.define do
  factory :front_gear_type do
    sequence(:name) { |n| "Front Gear #{n}" }
    count { 1 }
  end
end
