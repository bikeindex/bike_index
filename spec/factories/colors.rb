# == Schema Information
#
# Table name: colors
#
#  id         :integer          not null, primary key
#  display    :string(255)
#  name       :string(255)
#  priority   :integer
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
FactoryBot.define do
  factory :color do
    sequence(:name) { |n| "Color #{n}" }
    priority { 1 }
  end
end
