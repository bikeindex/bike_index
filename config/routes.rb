require "soulheart/server"
require "sidekiq/web"
Sidekiq::Web.set :session_secret, Rails.application.secrets[:secret_key_base]
Bikeindex::Application.routes.draw do
  use_doorkeeper do
    controllers applications: "oauth/applications"
    controllers authorizations: "oauth/authorizations"
    controllers authorized_applications: "oauth/authorized_applications"
  end

  get "/shop", to: redirect("https://bikeindex.myshopify.com"), as: :shop
  get "/store", to: redirect("https://bikeindex.myshopify.com"), as: :store
  get "/discuss", to: redirect("https://discuss.bikeindex.org"), as: :discuss
  get "discourse_authentication", to: "discourse_authentication#index"

  resources :organizations do
    member do
      get :embed
      get :embed_extended
      get :embed_create_success
    end
  end

  get "/", to: redirect(:root_url, subdomain: false), constraints: { subdomain: "stolen" }
  root to: "welcome#index"

  LandingPages::ORGANIZATIONS.each do |slug|
    get slug, to: "landing_pages#show", organization_id: slug
  end

  %w(for_shops for_advocacy for_law_enforcement for_schools ambassadors_how_to ambassadors_current ascend).freeze.each do |page|
    get page, controller: "landing_pages", action: page
  end

  get "ambassadors", to: redirect("/ambassadors_how_to") # Because convenience
  get "ambassadors/new", to: redirect("https://docs.google.com/forms/d/e/1FAIpQLSenRXqarY4KFNw1AQ3u5iHwIaaIpgy6cb1sD3YTSQiR0ICeCQ/viewform"), as: :new_ambassador

  %w(update_browser user_home choose_registration goodbye bike_creation_graph).freeze.each do |page|
    get page, controller: "welcome", action: page
  end

  get "update_browser", to: "welcome#update_browser"
  get "user_home", to: "welcome#user_home"
  get "choose_registration", to: "welcome#choose_registration"
  get "goodbye", to: "welcome#goodbye"
  get "bike_creation_graph", to: "welcome#bike_creation_graph"
  get "recovery_stories", to: "welcome#recovery_stories", as: :recovery_stories

  resource :session, only: [:new, :create, :destroy]
  get "logout", to: "sessions#destroy"

  resources :payments
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
  resources :memberships, only: [:update, :destroy]

  resources :stolen_notifications, only: [:create, :new]

  resources :feedbacks, only: [:index, :create]
  get "vendor_signup", to: redirect("/organizations/new")
  get "connect_lightspeed", to: "organizations#connect_lightspeed"
  get "help", to: "feedbacks#index"
  get "feedbacks/new", to: redirect("/help")
  %w(support contact contact_us).each { |p| get p, to: redirect("/help") }

  resources :users, only: %i[new create show edit update] do
    collection do
      get "please_confirm_email"
      get "confirm" # Get because needs to be called from a link in an email
      get "request_password_reset"
      post "password_reset"
      get "password_reset"
      get "update_password"
    end
    member { get "unsubscribe" }
  end
  get :my_account, to: "users#edit", as: :my_account
  get :accept_vendor_terms, to: "users#accept_vendor_terms"
  get :accept_terms, to: "users#accept_terms"
  resources :user_embeds, only: [:show]
  resources :user_emails, only: [:destroy] do
    member do
      post "resend_confirmation"
      get "confirm"
      post "make_primary"
    end
  end
  resources :news, only: [:show, :index]
  resources :blogs, only: [:show, :index]
  get "blog", to: redirect("/news")

  resources :public_images, only: [:create, :show, :edit, :update, :destroy] do
    collection do
      post :order
    end
    member { post :is_private }
  end

  resources :registrations, only: [:new, :create] do
    collection { get :embed }
  end

  resources :bikes do
    collection { get :scanned }
    member do
      get :spokecard
      get :scanned
      get :pdf
    end
    resource :recovery, only: [:edit, :update], controller: "bikes/recovery"
  end
  get "bikes/scanned/:scanned_id", to: "bikes#scanned"

  resources :bike_codes, only: [:update]
  resources :locks, except: [:show, :index]

  namespace :admin do
    root to: "dashboard#index"
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
    get "invitations", to: "dashboard#invitations"
    get "maintenance", to: "dashboard#maintenance"
    put "update_tsv_blacklist", to: "dashboard#update_tsv_blacklist"
    get "tsvs", to: "dashboard#tsvs"
    get "bust_z_cache", to: "dashboard#bust_z_cache"
    get "destroy_example_bikes", to: "dashboard#destroy_example_bikes"
    get "invoices", to: "payments#invoices", as: :invoices
    resources :memberships, :organization_invitations, :bulk_imports, :exports,
              :paints, :ads, :recovery_displays, :mail_snippets, :paid_features, :payments
    resources :organizations do
      resources :custom_layouts, only: [:index, :edit, :update], controller: "organizations/custom_layouts"
      resources :invoices, controller: "organizations/invoices"
    end
    get "recover_organization", to: "organizations#recover"
    get "show_deleted_organizations", to: "organizations#show_deleted"

    resources :flavor_texts, only: [:destroy, :create]
    resources :stolen_bikes do
      member { post :approve }
    end
    resources :customer_contacts, only: [:create]
    resources :recoveries do
      collection { post :approve }
    end
    resources :stolen_notifications do
      member { get :resend }
    end
    resources :graphs, only: [:index] do
      collection do
        get :tables
        get :bikes
        get :users
        get :stolen_locations
        get :variable
      end
    end
    resources :failed_bikes, only: [:index, :show]
    resources :feedbacks, only: [:index, :show] do
      collection { get :graphs }
    end
    resources :ownerships, only: [:edit, :update]
    resources :tweets
    get "blog", to: redirect("/news")
    resources :news do
      collection do
        get :listicle_image_edit
      end
    end
    resources :ctypes, only: [:new, :create, :index, :edit, :update, :destroy] do
      collection { post :import }
    end
    resources :manufacturers do
      collection { post :import }
    end
    resources :users, only: [:index, :show, :edit, :update, :destroy]
  end

  namespace :api, defaults: { format: "json" } do
    get "/", to: redirect("/documentation")
    namespace :v1 do
      resources :bikes, only: [:index, :show, :create] do
        collection do
          get :search_tags
          get :close_serials
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
      resources :manufacturers, only: [:index, :show]
      resources :notifications, only: [:create]
      resources :organizations, only: [:show]
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

  resource :integrations, only: [:create]
  get "/auth/:provider/callback", to: "integrations#create"
  get "/auth/failure", to: "integrations#integrations_controller_creation_error"

  %w(support_bike_index support_the_index support_the_bike_index protect_your_bike
     serials about where vendor_terms resources image_resources privacy terms
     how_not_to_buy_stolen dev_and_design lightspeed).freeze.each do |page|
    get page, controller: "info", action: page
  end
  get "lightspeed_integration", to: redirect("/lightspeed")

  %w(stolen_bikes roadmap security spokecard how_it_works).freeze.each { |p| get p, to: redirect("/resources") }

  # get 'sitemap.xml.gz' => redirect('https://files.bikeindex.org/sitemaps/sitemap_index.xml.gz')
  # Somehow the redirect drops the .gz extension, which ruins it so this redirect is handled by Cloudflare
  # get 'sitemaps/(*all)' => redirect('https://files.bikeindex.org/sitemaps/%{all}')

  get "/400", to: "errors#bad_request", via: :all
  get "/401", to: "errors#unauthorized", via: :all
  get "/404", to: "errors#not_found", via: :all
  get "/422", to: "errors#unprocessable_entity", via: :all
  get "/500", to: "errors#server_error", via: :all

  mount Sidekiq::Web => "/sidekiq", constraints: AdminRestriction

  # No actions are defined here, this `resources` declaration
  # prepends a :organization_id/ to every nested URL.
  # Down here so that it doesn't override any other routes
  resources :organizations, only: [], path: "o", module: "organized" do
    get "/", to: "base#index", as: :root
    get "landing", to: "manage#landing", as: :landing
    resources :bikes, only: %i[index new show] do
      collection do
        get :recoveries
        get :incompletes
        get :multi_serial_search
      end
    end
    resources :exports, except: [:edit]
    resources :bulk_imports, only: %i[index show new create]
    resources :messages, only: %i[index show create]
    resources :stickers, only: %i[index show edit update]
    resources :ambassadors, only: %i[index]

    # Organized Admin resources (below here controllers should inherit Organized::AdminController)
    resources :manage, only: %i[index update destroy] do
      collection do
        get :locations
      end
    end
    resources :users, except: [:show]
  end

  get "*unmatched_route", to: "errors#not_found" if Rails.env.production? # Handle 404s with lograge
end
