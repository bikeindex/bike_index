FactoryBot.define do
  factory :doorkeeper_app, class: "Doorkeeper::Application" do
    sequence(:name) { |n| "OAuth App #{n}" }
    redirect_uri { "urn:ietf:wg:oauth:2.0:oob" }

    # confidential { false } # Not used
    # scopes { "public" } # only set on tokens?

    is_internal { false }
    can_send_stolen_notifications { false }

    owner { FactoryBot.create(:user_confirmed) }
  end
end
