FactoryBot.define do
  factory :doorkeeper_app, class: "Doorkeeper::Application" do
    sequence(:name) { |n| "OAuth App #{n}" }

    redirect_uri { "https://app.com" }

    # confidential { false } # Not used
    # scopes { "public" } # only set on tokens?

    is_internal { false }
    can_send_stolen_notifications { false }

    owner { FactoryBot.create(:user_confirmed) }
  end
end
