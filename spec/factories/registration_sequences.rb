FactoryBot.define do
  factory :registration_sequence do
    organization

    # Built rather than created, so they save alongside the sequence - activation
    # freezes the pages, so they have to be there first
    trait :with_pages do
      after(:build) do |registration_sequence|
        2.times do |index|
          registration_sequence.registration_sequence_pages
            .build(title: "Safety check", listing_order: index,
              body: "<ul><li>point one</li><li>point two</li></ul>")
        end
      end
    end

    trait :activated do
      start_at { Time.current }
    end

    factory :registration_sequence_active, traits: [:activated]

    # The template drafts, activates and archives like an organization's sequence
    factory :registration_sequence_template do
      organization { nil }

      factory :registration_sequence_template_active, traits: [:activated]
    end
  end
end
