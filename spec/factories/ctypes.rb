# frozen_string_literal: true

FactoryBot.define do
  factory :ctype do
    sequence(:name) { |n| "Component type#{n}" }
    cgroup { FactoryBot.create(:cgroup) }
  end
end
