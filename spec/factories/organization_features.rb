# == Schema Information
#
# Table name: organization_features
#
#  id            :integer          not null, primary key
#  amount_cents  :integer
#  currency_enum :integer
#  description   :text
#  details_link  :string
#  feature_slugs :text             default([]), is an Array
#  kind          :integer          default("standard")
#  name          :string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
FactoryBot.define do
  factory :organization_feature do
    kind { "standard" }
    sequence(:name) { |n| "Feature #{n}" }
    amount_cents { 1000 }
    factory :organization_feature_one_time do
      kind { "standard_one_time" }
    end
  end
end
