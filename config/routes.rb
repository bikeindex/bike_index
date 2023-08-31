# frozen_string_literal: true

require "soulheart/server"
require "sidekiq/web"

Rails.application.routes.draw do
  use_doorkeeper do
    controllers applications: "oauth/applications"
    controllers authorizations: "oauth/authorizations"
    controllers authorized_applications: "oauth/authorized_applications"
  end

  get "/shop", to: redirect("https://bikeindex.org/info/bike-index-store"), as: :shop
  get "/store", to: redirect("https://bikeindex.org/info/bike-index-store"), as: :store
  get "/discuss", to: redirect("https://discuss.bikeindex.org"), as: :discuss
  get "discourse_authentication", to: "discourse_authentication#index"

  resources :organizations do
    member do
      get :embed
      get :embed_extended, as: :embed_extended
      get :embed_create_success
    end
  end

  root to: "welcome#index"

  get "/user_root_url_redirect", to: "welcome#user_root_url_redirect", as: :user_root_url_redirect

  LandingPages::ORGANIZATIONS.each do |slug|
    get slug, to: "landing_pages#show", organization_id: slug
  end

  %w[
    ambassadors_current
    ambassadors_how_to
    ascend
    bike_shop_packages
    campus_packages
    cities_packages
    for_bike_shops
    for_community_groups
    for_cities
    for_law_enforcement
    for_schools
  ].freeze.each do |page|
    get page, controller: "landing_pages", action: page
  end

  get "for_advocacy", to: redirect("/for_community_groups")
  get "for_shops", to: redirect("/for_bike_shops")
  get "ambassadors", to: redirect("/ambassadors_how_to") # Because convenience
  get "ambassadors/new", to: redirect("https://docs.google.com/forms/d/e/1FAIpQLSenRXqarY4KFNw1AQ3u5iHwIaaIpgy6cb1sD3YTSQiR0ICeCQ/viewform"), as: :new_ambassador

  %w[update_browser choose_registration goodbye bike_creation_graph].freeze.each do |page|
    get page, controller: "welcome", action: page
  end

  get "update_browser", to: "welcome#update_browser"
  get "choose_registration", to: "welcome#choose_registration"
  get "goodbye", to: "welcome#goodbye"
  get "bike_creation_graph", to: "welcome#bike_creation_graph"
  get "recovery_stories", to: "welcome#recovery_stories", as: :recovery_stories

  resource :session, only: %i[new create destroy] do
    collection do
      get :magic_link
      post :sign_in_with_magic_link
      post :create_magic_link
    end
  end
  get "logout", to: "sessions#destroy"

  resources :payments, only: %i[new create] do
    collection { get :success }
  end
  get "/.well-known/apple-developer-merchantid-domain-association", to: "payments#apple_verification"
  resources :documentation, only: [:index] do
    collection do
      get :api_v1
      get :api_v2
      get :api_v3
      get :o2c
      get :authorize
    end
  end

  resources :ownerships, only: [:show]

  resources :stolen_notifications, only: %i[create new]

  resources :feedbacks, only: %i[index create]
  get "vendor_signup", to: redirect("/organizations/new")
  get "lightspeed_interface", to: "organizations#lightspeed_interface"
  get "help", to: "feedbacks#index"
  get "feedbacks/new", to: redirect("/help")
  %w[support contact contact_us].each { |p| get p, to: redirect("/help") }

  resources :users, only: %i[new create show edit update] do
    collection do
      get "please_confirm_email"
      post "resend_confirmation_email"
      get "confirm" # Get because needs to be called from a link in an email
      # Replacing
      get :request_password_reset_form
      post :send_password_reset_email
      get :update_password_form_with_reset_token
      post :update_password_with_reset_token
    end
    member do
      get "unsubscribe"
      post "unsubscribe_update"
    end
  end
  resource :my_account, only: %i[show update]
  get "my_account/edit(/:edit_template)", to: "my_accounts#edit", as: :edit_my_account
  # Legacy - there are places where user_home existed in emails, etc, so keep this
  get "user_home", to: redirect("/my_account")
  get :accept_vendor_terms, to: "users#accept_vendor_terms"
  get :accept_terms, to: "users#accept_terms"
  resources :user_alerts, only: %i[update]
  resources :user_embeds, only: [:show]
  resources :user_phones, only: %i[update destroy]
  resources :user_emails, only: [:destroy] do
    member do
      post "resend_confirmation"
      get "confirm"
      post "make_primary"
    end
  end
  resources :news, only: %i[show index]
  resources :blogs, only: %i[show index]
  get "blog", to: redirect("/news")

  resources :public_images, only: %i[create show edit update destroy] do
    collection do
      post :order
    end
    member { post :is_private }
  end

  resources :registrations, only: [:new, :create] do
    collection { get :embed }
  end

  resources :bikes, except: [:edit] do
    collection { get :scanned }
    member do
      get :spokecard
      get :scanned
      get :pdf
      put :resolve_token
    end
    resource :recovery, only: %i[edit update], controller: "bikes/recovery"
    resource :theft_alert, only: %i[new create show], controller: "bikes/theft_alerts"
  end
  get "bikes/:id/edit(/:edit_template)", to: "bikes/edits#show", as: :edit_bike
  get "bikes/scanned/:scanned_id", to: "bikes#scanned"
  get "stickers/:scanned_id", to: "bikes#scanned"

  resources :bike_versions, except: [:edit]
  get "bike_versions/:id/edit(/:edit_template)", to: "bike_versions/edits#show", as: :edit_bike_version

  resources :bike_stickers, only: [:update]
  resources :locks, except: %(show index)
  resources :impound_claims, only: [:create, :update]
  resources :review_impound_claims, only: [:show, :update]

  namespace :admin do
    root to: "dashboard#index", as: :root
    resources :ambassador_tasks, except: :show
    resources :ambassador_task_assignments, only: [:index]
    resources :exchange_rates, only: %i[index new create edit update destroy]

    resources :external_registry_bikes, only: %i[index show]
    resources :external_registry_credentials, only: %i[index new create edit update] do
      member do
        put :reset
      end
    end

    resources :bikes do
      collection do
        get :duplicates
        put :ignore_duplicate_toggle
        get :missing_manufacturer
        post :update_manufacturers
        put :unrecover
      end
      member { get :get_destroy }
    end
    get "credibility_badges", to: "dashboard#credibility_badges"
    get "maintenance", to: "dashboard#maintenance"
    get "scheduled_jobs", to: "dashboard#scheduled_jobs"
    put "update_tsv_blocklist", to: "dashboard#update_tsv_blocklist"
    get "tsvs", to: "dashboard#tsvs"
    get "bust_z_cache", to: "dashboard#bust_z_cache"
    get "destroy_example_bikes", to: "dashboard#destroy_example_bikes"
    resources :memberships, :bulk_imports, :exports, :bike_sticker_updates,
      :paints, :ads, :recovery_displays, :mail_snippets, :organization_features, :payments,
      :ctypes, :parking_notifications, :impound_records, :graduated_notifications,
      :content_tags, :impound_claims, :mailchimp_values, :mailchimp_data, :user_alerts,
      :notifications, :user_registration_organizations, :theft_alerts, :superuser_abilities

    resources :bike_stickers do
      collection { get :reassign }
    end
    resources :invoices, only: [:index]
    resources :theft_alert_plans, only: %i[index edit update new create]

    resources :organizations do
      resources :custom_layouts, only: %i[index edit update], controller: "organizations/custom_layouts"
      resources :invoices, controller: "organizations/invoices"
      collection { get :show_deleted }
    end
    get "recover_organization", to: "organizations#recover"

    resources :stolen_bikes do
      member { post :approve }
    end
    resources :customer_contacts, only: %i[create show]
    resources :recoveries do
      collection { post :approve }
    end
    resources :stolen_notifications do
      member { get :resend }
    end
    resources :graphs, only: [:index] do
      collection do
        get :tables
        get :variable
      end
    end
    resources :b_params, only: %i[index show]
    resources :feedbacks, only: %i[index show]
    resources :ownerships, only: %i[edit update index]
    resources :tweets
    resources :twitter_accounts, except: %i[new] do
      member { get :check_credentials }
    end

    get "blog", to: redirect("/news")
    resources :news do
      collection do
        get :listicle_image_edit
      end
    end
    resources :manufacturers do
      collection { post :import }
    end
    resources :users, only: [:index, :show, :edit, :update, :destroy]

    mount Flipper::UI.app(Flipper) => "/feature_flags",
      :constraints => AdminRestriction,
      :as => :feature_flags
  end

  namespace :api, defaults: {format: "json"} do
    get "/", to: redirect("/documentation")
    namespace :v1 do
      resources :bikes, only: [:index, :show, :create] do
        collection do
          get :search_tags
          get :close_serials
          get :serials_containing
          get :stolen_ids
        end
      end
      resources :stolen_locking_response_suggestions, only: [:index]
      resources :cycle_types, only: [:index]
      resources :wheel_sizes, only: [:index]
      resources :component_types, only: [:index]
      resources :colors, only: [:index]
      resources :handlebar_types, only: [:index]
      resources :frame_materials, only: [:index]
      resources :manufacturers, only: %i[index show]
      resources :notifications, only: [:create]
      resources :organizations, only: [:show, :update]
      resources :users do
        collection do
          get :current
          post :request_serial_update
          post :send_request
        end
      end
      get "not_found", to: "api_v1#not_found"
      get "*a", to: "api_v1#not_found"
    end
    mount Soulheart::Server, at: "/autocomplete"
  end
  mount API::Base => "/api"

  resources :stolen, only: [:index, :show] do
    collection do
      get "current_tsv"
      get "current_tsv_rapid"
    end
  end

  resources :manufacturers, only: [:index] do
    collection { get "tsv" }
  end
  get "manufacturers_tsv", to: "manufacturers#tsv"

  get "theft-rings", to: "stolen_bike_listings#index" # Temporary, may switch to being an info post
  get "theft-ring", to: redirect("theft-rings")
  resources :stolen_bike_listings, only: [:index]

  resource :integrations, only: [:create]
  get "/auth/twitter/callback", to: "admin/twitter_accounts#create"
  get "/auth/:provider/callback", to: "integrations#create"
  get "/auth/failure", to: "integrations#integrations_controller_creation_error"

  %w[donate support_bike_index support_the_index support_the_bike_index protect_your_bike
    serials about where vendor_terms resources image_resources privacy terms security
    how_not_to_buy_stolen dev_and_design lightspeed].freeze.each do |page|
    get page, controller: "info", action: page
  end
  get "why-donate", to: "info#why_donate", as: "why_donate"
  get "why_donate", to: redirect("/why-donate")
  get "lightspeed_integration", to: redirect("/lightspeed")
  get "/info/how-to-get-your-stolen-bike-back", controller: "info", action: "show", id: "how-to-get-your-stolen-bike-back", as: :get_your_stolen_bike_back
  resources :info, only: [:show]

  %w[stolen_bikes roadmap spokecard how_it_works].freeze.each { |p| get p, to: redirect("/resources") }

  get "/400", to: "errors#bad_request", via: :all
  get "/401", to: "errors#unauthorized", via: :all
  get "/404", to: "errors#not_found", via: :all
  get "/422", to: "errors#unprocessable_entity", via: :all
  get "/500", to: "errors#server_error", via: :all

  mount Sidekiq::Web => "/sidekiq", :constraints => AdminRestriction

  # No actions are defined here, this `resources` declaration
  # prepends a :organization_id/ to every nested URL.
  # Down here so that it doesn't override any other routes
  resources :organizations, only: [], path: "o", module: "organized" do
    get "/", to: "dashboard#root", as: :root
    resources :dashboard, only: [:index]
    get "landing", to: "manages#landing", as: :landing
    resources :bikes, only: %i[index new create show update] do
      collection do
        get :recoveries
        get :incompletes
        get :multi_serial_search
        get :new_iframe
      end
      member { post :resend_incomplete_email }
    end
    resources :exports, except: [:edit]
    resources :bulk_imports, only: %i[index show new create]
    resources :emails, only: %i[index show edit update]
    resources :parking_notifications
    resources :graduated_notifications, only: %w[index show]
    resources :impound_records, only: %i[index show update]
    resources :impound_claims, only: %i[index show update]
    resources :stickers, only: %i[index show edit update]
    resource :hot_sheet, only: %i[show edit update]
    resource :ambassador_dashboard, only: %i[show] do
      collection do
        get :resources
        get :getting_started
      end
    end
    resources :ambassador_task_assignments, only: %i[update]

    # Organized Admin resources (below here controllers should inherit Organized::AdminController)
    resource :manage, only: %i[show update destroy] do
      collection do
        get :locations
      end
    end
    resource :manage_impounding
    resources :users, except: [:show]
  end

  # This is the public organizations section
  resources :organization, only: [], path: "", module: "org_public" do
    resources :impounded_bikes, only: %i[index]
  end

  get "*unmatched_route", to: "errors#not_found" if Rails.env.production? # Handle 404s with lograge
end
