FactoryBot.define do
  factory :organization_message do
    sender { FactoryBot.create(:organized_user) }
    organization { sender&.organizations&.first || FactoryBot.create(:organization) }
    bike { FactoryBot.create(:bike) }
    latitude { 40.7143528 }
    longitude { -74.0059731 }
    address { "278 Broadway, New York, NY 10007, USA" }
  end
end
