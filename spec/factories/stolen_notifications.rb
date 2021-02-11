FactoryBot.define do
  factory :stolen_notification do
    sender { FactoryBot.create(:user) }
    receiver { FactoryBot.create(:user) }
    bike { FactoryBot.create(:bike) }
    message { "This is a test email." }
  end
end
