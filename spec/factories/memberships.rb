# == Schema Information
#
# Table name: memberships
#
#  id         :bigint           not null, primary key
#  end_at     :datetime
#  level      :integer
#  start_at   :datetime
#  status     :integer
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  creator_id :bigint
#  user_id    :bigint
#
# Indexes
#
#  index_memberships_on_creator_id  (creator_id)
#  index_memberships_on_user_id     (user_id)
#
FactoryBot.define do
  factory :membership do
    user { FactoryBot.create(:user_confirmed) }
    level { "basic" }
    start_at { Time.current - 1.hour }
    creator { FactoryBot.create(:superuser) }

    trait :with_payment do
      after(:create) do |membership|
        FactoryBot.create(:payment, membership:, user: membership.user)
      end
    end

    factory :membership_stripe_managed do
      creator { nil }

      after(:create) do |membership|
        FactoryBot.create(:stripe_subscription, membership:)
      end
    end
  end
end
