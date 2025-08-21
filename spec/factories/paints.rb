# frozen_string_literal: true

# == Schema Information
#
# Table name: paints
#
#  id                 :integer          not null, primary key
#  bikes_count        :integer          default(0), not null
#  name               :string(255)
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  color_id           :integer
#  manufacturer_id    :integer
#  secondary_color_id :integer
#  tertiary_color_id  :integer
#
FactoryBot.define do
  factory :paint do
    sequence(:name) { |n| "Paint #{n}" }
  end
end
