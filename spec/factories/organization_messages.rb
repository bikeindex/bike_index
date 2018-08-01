FactoryGirl.define do
  factory :organization_message do
    sender { FactoryGirl.create(:organized_user) }
    organization { sender&.organizations&.first || FactoryGirl.create(:organization) }
    bike { FactoryGirl.create(:bike) }
    latitude { 40.7143528 }
    longitude { -74.0059731 }
    address { "278 Broadway, New York, NY 10007, USA" }
  end
end
