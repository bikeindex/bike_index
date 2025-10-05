# frozen_string_literal: true

FactoryBot.define do
  factory :blog do
    user { FactoryBot.create(:user) }
    body { "Some sweet blog content that everyone loves" }
    sequence(:title) { |n| "Blog title #{n}" }

    trait :published do
      published { true }
    end

    trait :dutch do
      language { "nl" }
    end
  end
end
