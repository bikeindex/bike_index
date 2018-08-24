FactoryGirl.define do
  factory :payment do
    user { FactoryGirl.create(:user) }
    amount_cents 999
    kind "stripe"
    factory :payment_check do
      kind "check"
    end
  end
end
