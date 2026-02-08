# frozen_string_literal: true

FactoryBot.define do
  factory :strava_request do
    transient do
      strava_integration { FactoryBot.create(:strava_integration) }
    end
    user_id { strava_integration.user_id }
    strava_integration_id { strava_integration.id }
    request_type { :fetch_athlete }
    endpoint { "athlete" }
    parameters { {} }

    trait :fetch_athlete_stats do
      request_type { :fetch_athlete_stats }
      endpoint { "athletes/12345/stats" }
      parameters { {athlete_id: "12345"} }
    end

    trait :list_activities do
      request_type { :list_activities }
      endpoint { "athlete/activities" }
      parameters { {page: 1, per_page: 200} }
    end

    trait :fetch_activity do
      request_type { :fetch_activity }
      endpoint { "activities/12345" }
      parameters { {strava_id: "12345", strava_activity_id: 1} }
    end

    trait :processed do
      requested_at { Time.current }
      response_status { :success }
    end
  end
end
