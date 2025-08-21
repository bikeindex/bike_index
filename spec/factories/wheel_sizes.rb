# frozen_string_literal: true

# == Schema Information
#
# Table name: wheel_sizes
#
#  id          :integer          not null, primary key
#  description :string(255)
#  iso_bsd     :integer
#  name        :string(255)
#  priority    :integer
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
FactoryBot.define do
  factory :wheel_size do
    sequence(:name) { |n| "Wheel size #{n}" }
    iso_bsd { FactoryBot.generate(:unique_iso) }
    priority { 1 }
    sequence(:description) { |n| "Wheel Description #{n}" }
  end
end
