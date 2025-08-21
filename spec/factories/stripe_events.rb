# == Schema Information
#
# Table name: stripe_events
#
#  id         :bigint           not null, primary key
#  name       :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  stripe_id  :string
#
FactoryBot.define do
  factory :stripe_event do
    stripe_subscription { nil }
    name { "MyString" }
  end
end
