# frozen_string_literal: true

FactoryBot.define do
  factory :cgroup do
    sequence(:name) { |n| "Cgroup #{n}" }
  end
end
