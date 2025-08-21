# frozen_string_literal: true

# == Schema Information
#
# Table name: front_gear_types
#
#  id         :integer          not null, primary key
#  count      :integer
#  internal   :boolean          default(FALSE), not null
#  name       :string(255)
#  slug       :string(255)
#  standard   :boolean
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
FactoryBot.define do
  factory :front_gear_type do
    sequence(:name) { |n| "Front Gear #{n}" }
    count { 1 }
  end
end
