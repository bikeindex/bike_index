# frozen_string_literal: true

# == Schema Information
#
# Table name: cgroups
#
#  id          :integer          not null, primary key
#  description :string(255)
#  name        :string(255)
#  priority    :integer          default(1)
#  slug        :string(255)
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
FactoryBot.define do
  factory :cgroup do
    sequence(:name) { |n| "Cgroup #{n}" }
  end
end
