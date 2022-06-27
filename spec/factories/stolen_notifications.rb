FactoryBot.define do
  factory :stolen_notification do
    sender { FactoryBot.create(:user) }
    bike { FactoryBot.create(:bike, :with_stolen_record, :with_ownership) }
    message { "This is a test email." }
  end
end
