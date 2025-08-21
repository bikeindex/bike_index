# frozen_string_literal: true

FactoryBot.define do
  factory :paint do
    sequence(:name) { |n| "Paint #{n}" }
  end
end
