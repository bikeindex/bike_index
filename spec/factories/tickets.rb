FactoryBot.define do
  factory :ticket do
    location { FactoryBot.create(:location, :with_virtual_line_on) }
    sequence(:number) { |n| n }

    factory :ticket_claimed do
      transient do
        user { FactoryBot.create(:user) }
      end
      appointment do
        FactoryBot.create(:appointment,
                          location_id: location_id,
                          organization_id: location.organization_id,
                          creator_kind: "ticket_claim",
                          status: "waiting",
                          user: user,
                          ticket_number: number)
      end
    end
  end
end
