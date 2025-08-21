# frozen_string_literal: true

FactoryBot.define do
  factory :lock_type do
    sequence(:name) { |n| "Lock type #{n}" }
  end

  factory :lock do
    user { FactoryBot.create(:user) }
    manufacturer { FactoryBot.create(:manufacturer) }
    lock_type { FactoryBot.create(:lock_type) }
  end
end
