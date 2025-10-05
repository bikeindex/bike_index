# frozen_string_literal: true

FactoryBot.define do
  factory :wheel_size do
    sequence(:name) { |n| "Wheel size #{n}" }
    iso_bsd { FactoryBot.generate(:unique_iso) }
    priority { 1 }
    sequence(:description) { |n| "Wheel Description #{n}" }
  end
end
