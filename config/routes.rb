require 'soulheart/server'
Bikeindex::Application.routes.draw do
  use_doorkeeper do
    controllers applications: 'oauth/applications'
    controllers authorizations: 'oauth/authorizations'
    controllers authorized_applications: 'oauth/authorized_applications'
  end

  match '/shop', to: redirect('https://bikeindex.myshopify.com'), as: :shop
  match '/discuss', to: redirect('https://discuss.bikeindex.org'), as: :discuss
  match 'discourse_authentication', to: 'discourse_authentication#index'

  resources :organizations do
    member do
      get :embed
      get :embed_extended
      get :embed_create_success
    end
    resources :memberships, only: [:edit, :update, :destroy]
    resources :organization_invitations, only: [:new, :create]
  end

  match '/', to: redirect(:root_url, subdomain: false), constraints: { subdomain: 'stolen' }

  root to: 'welcome#index'

  match 'update_browser', to: 'welcome#update_browser'
  match 'user_home', to: 'welcome#user_home'
  match 'choose_registration', to: 'welcome#choose_registration'
  match 'goodbye', to: 'welcome#goodbye'

  resource :session, only: [:new, :create, :destroy]
  match 'logout', to: 'sessions#destroy'

  resources :payments
  resources :documentation, only: [:index] do
    collection do
      get :api_v1
      get :api_v2
      get :o2c
      get :authorize
    end
  end

  resources :ownerships, only: [:show]
  resources :memberships, only: [:update, :destroy]

  resources :stolen_notifications, only: [:create, :new]

  resources :feedbacks, only: [:create]
  match 'vendor_signup', to: redirect('/organizations/new')
  match 'lightspeed_integration', to: 'organizations#lightspeed_integration'
  match 'help', to: 'feedbacks#index'
  match 'feedbacks/new', to: redirect('/help')
  %w(support contact contact_us).each { |p| match p, to: redirect('/help') }

  resources :users, only: [:new, :create, :show, :edit, :update] do
    collection do
      get 'confirm'
      get 'request_password_reset'
      post 'password_reset'
      get 'password_reset'
      get 'update_password'
    end
  end
  get :my_account, to: 'users#edit', as: :my_account
  get :accept_vendor_terms, to: 'users#accept_vendor_terms'
  get :accept_terms, to: 'users#accept_terms'
  resources :user_embeds, only: [:show]
  resources :user_emails, only: [:destroy] do
    member do
      post 'resend_confirmation'
      get 'confirm'
      post 'make_primary'
    end
  end
  resources :news, only: [:show, :index]
  resources :blogs, only: [:show, :index]
  match 'blog', to: redirect('/news')

  resources :public_images, only: [:create, :show, :edit, :update, :destroy] do
    collection do
      post :order
    end
    member { post :is_private }
  end

  resources :bikes do
    collection { get :scanned }
    member do
      get :spokecard
      get :scanned
      get :pdf
    end
  end
  resources :locks

  namespace :admin do
    root to: 'dashboard#index'
    resources :bikes do
      collection do
        get :duplicates
        put :ignore_duplicate_toggle
        get :missing_manufacturer
        post :update_manufacturers
      end
      member { get :get_destroy }
    end
    match 'invitations', to: 'dashboard#invitations'
    match 'maintenance', to: 'dashboard#maintenance'
    put 'update_tsv_blacklist', to: 'dashboard#update_tsv_blacklist'
    match 'tsvs', to: 'dashboard#tsvs'
    match 'bust_z_cache', to: 'dashboard#bust_z_cache'
    match 'destroy_example_bikes', to: 'dashboard#destroy_example_bikes'
    resources :memberships, :organizations, :organization_invitations,
              :paints, :ads, :recovery_displays, :mail_snippets
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
        get :bikes
        get :users
        get :stolen_locations
      end
    end
    resources :failed_bikes, only: [:index, :show]
    resources :ownerships, only: [:edit, :update]
    match 'recover_organization', to: 'organizations#recover'
    match 'show_deleted_organizations', to: 'organizations#show_deleted'
    match 'blog', to: redirect('/news')
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
    resources :users, only: [:index, :edit, :update, :destroy]
  end

  namespace :api, defaults: { format: 'json' } do
    match '/', to: redirect('/documentation')
    namespace :v1 do
      resources :bikes, only: [:index, :show, :create] do
        collection do
          get 'search_tags'
          get 'close_serials'
          get 'stolen_ids'
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
          get 'current'
          post 'request_serial_update'
          post 'send_request'
        end
      end
      match 'not_found', to: 'api_v1#not_found'
      match '*a', to: 'api_v1#not_found'
    end
    mount Soulheart::Server, at: '/autocomplete'
  end
  mount API::Base => '/api'

  resources :stolen, only: [:index, :show] do
    collection do
      get 'current_tsv'
    end
  end

  resources :mailer_integrations, only: [:show, :index]

  resources :manufacturers, only: [:index] do
    collection { get 'tsv' }
  end
  match 'manufacturers_tsv', to: 'manufacturers#tsv'

  resources :organization_deals, only: [:create, :new]
  resource :integrations, only: [:create]
  match '/auth/:provider/callback', to: 'integrations#create'

  %w(support_the_index support_the_bike_index protect_your_bike privacy terms serials
     about where vendor_terms resources image_resources how_not_to_buy_stolen dev_and_design).each do |page|
    get page, controller: 'info', action: page
  end

  %w(stolen_bikes roadmap security spokecard how_it_works).each { |p| match p, to: redirect('/resources') }

  # get 'sitemap.xml.gz' => redirect('https://files.bikeindex.org/sitemaps/sitemap_index.xml.gz')
  # Somehow the redirect drops the .gz extension, which ruins it so this redirect is handled by Cloudflare
  # get 'sitemaps/(*all)' => redirect('https://files.bikeindex.org/sitemaps/%{all}')

  match '/400', to: 'errors#bad_request'
  match '/401', to: 'errors#unauthorized'
  match '/404', to: 'errors#not_found'
  match '/422', to: 'errors#unprocessable_entity'
  match '/500', to: 'errors#server_error'

  mount Sidekiq::Web => '/sidekiq', constraints: AdminRestriction
end
