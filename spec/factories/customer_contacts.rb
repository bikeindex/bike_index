FactoryBot.define do
  factory :customer_contact do
    creator { FactoryBot.create(:user) }
    bike { FactoryBot.create(:bike) }
    title { "Some title" }
    body { "some message" }
    creator_email { "something@example.com" }
    user_email { "something_else@example.com" }
    kind { :stolen_contact }

    trait :stolen_bike do
      bike { FactoryBot.create(:stolen_bike) }
    end

    factory :customer_contact_potentially_found_bike do
      creator { FactoryBot.create(:user) }
      bike { FactoryBot.create(:stolen_bike) }
      kind { :bike_possibly_found }

      transient do
        match { FactoryBot.create(:impounded_bike) }
      end

      after(:create) do |cc, evaluator|
        info_hash = {
          "match_id" => evaluator.match.id.to_s,
          "match_type" => evaluator.match.class.to_s,
          "stolen_record_id" => cc.bike.current_stolen_record.id.to_s
        }
        cc.update(
          info_hash: info_hash,
          user_email: cc.bike.owner_email,
          creator_email: cc.creator.email,
          title: "We may have found your stolen #{cc.bike.title_string}",
          body: "Check this matching bike: #{evaluator.match.title_string}"
        )
      end
    end
  end
end
