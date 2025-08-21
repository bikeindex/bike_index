# == Schema Information
#
# Table name: primary_activities
#
#  id                         :bigint           not null, primary key
#  family                     :boolean
#  name                       :string
#  priority                   :integer
#  slug                       :string
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  primary_activity_family_id :bigint
#
# Indexes
#
#  index_primary_activities_on_primary_activity_family_id  (primary_activity_family_id)
#
FactoryBot.define do
  factory :primary_activity do
    sequence(:name) { |n| "Bike Activity Type #{n}" }
    family { false }

    factory :primary_activity_family do
      family { true }
    end

    trait :with_family do
      primary_activity_family { FactoryBot.create(:primary_activity_family) }
    end

    factory :primary_activity_flavor_with_family, traits: [:with_family]
  end
end
