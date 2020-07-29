FactoryBot.define do
  factory :appointment do
    location { FactoryBot.create(:location, :with_virtual_line_on) }
    organization { location.organization }
    # if user is present, saving the appointment will assign users email
    sequence(:email) { |n| user.present? ? nil : "bike_owner#{n}@example.com" }
    sequence(:name) { |n| "some name #{n}" }
    reason { AppointmentConfiguration.default_reasons.first }
    status { "waiting" }
    creator_kind { "no_user" }
    trait :claimed do
      user { FactoryBot.create(:user) }
    end
  end
end
