Bikeindex::Application.routes.draw do

  get "dashboard/show"
    
  resources :organizations do 
    member do
      get :embed
      get :embed_extended
      get :embed_create_success
    end
    resources :memberships, only: [:edit, :update, :destroy]
    resources :organization_invitations, only: [:new, :create]
  end
  
  match '/' => 'stolen#index', constraints: { subdomain: 'stolen' } 

  root to: 'welcome#index'

  match 'update_browser', to: 'welcome#update_browser'
  match 'user_home', to: 'welcome#user_home'
  match 'choose_registration', to: 'welcome#choose_registration'
  match 'goodbye', to: 'welcome#goodbye'
  
  resource :session, only: [:new, :create, :destroy]
  match 'logout', to: 'sessions#destroy'

  resource :charges, only: [:new, :create]
  resources :documentation, only: [:index] do
    collection { get :api_v1 }
  end


  resources :ownerships, only: [:show]
  resources :memberships, only: [:update, :destroy]

  resources :stolen_notifications, only: [:create, :new]

  resources :feedbacks, only: [:create, :new]
  match 'vendor_signup', to: 'organizations#new'
  match 'contact', to: 'feedbacks#index'
  match 'contact_us', to: 'feedbacks#index'
  match 'help', to: 'feedbacks#index'
  match 'support', to: 'feedbacks#index'

  resources :users, only: [:new, :create, :show, :edit, :update] do
    collection do
      get 'confirm'
      get 'request_password_reset'
      post 'password_reset'
      get 'password_reset'
      get 'update_password'
    end
  end
  match 'my_account', to: 'users#edit'
  match 'accept_vendor_terms', to: 'users#accept_vendor_terms'
  match "accept_terms", to: "users#accept_terms"  
  resources :bike_token_invitations, only: [:create]
  resources :user_embeds, only: [:show]

  resources :news, only: [:show, :index]
  resources :blogs, only: [:show, :index]
  match 'blog', to: redirect("/news")

  resources :public_images, only: [:create, :show, :edit, :update, :index, :destroy] do 
    collection do
      post :order
    end
  end
  
  resources :bikes do
    collection { get :scanned }
    member do
     get 'spokecard'
     get 'scanned'
     get 'pdf'
   end
  end
  resources :locks

  namespace :admin do
    root to: 'dashboard#index'
    resources :bikes do 
      collection do
        get :missing_manufacturer
        post :update_manufacturers
      end
    end
    match 'invitations', to: 'dashboard#invitations'
    match 'maintenance', to: 'dashboard#maintenance'
    match 'bust_z_cache', to: 'dashboard#bust_z_cache'
    match 'destroy_example_bikes', to: 'dashboard#destroy_example_bikes'
    resources :discounts, :memberships, :organizations, :bike_token_invitations,
      :organization_invitations, :paints, :ads
    match 'duplicate_bikes', to: 'bikes#duplicates'
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
    resources :blogs, only: [:new, :create, :index, :edit, :update, :destroy]
    resources :ctypes, only: [:new, :create, :index, :edit, :update, :destroy] do 
      collection { post :import }
    end
    resources :manufacturers do 
      collection { post :import }
    end
    resources :users, only: [:index, :edit, :update, :destroy] do
      get :bike_tokens
      post :add_bike_tokens
    end
  end

  namespace :api, defaults: {format: 'json'} do
    namespace :v1 do
      resources :bikes, only: [:index, :show, :create] do
        collection do
          get 'search_tags'
          get 'close_serials'
          get 'stolen_ids'
        end
      end
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
      mount Soulmate::Server, :at => "/searcher"
      match 'not_found', to: 'api_v1#not_found'
      match '*a', to: 'api_v1#not_found'
    end
  end

  resources :stolen, only: [:index] do 
    collection do 
      get 'current_tsv'
      %w[links faq tech identidots philosophy rfid_tags_for_the_win howworks about merging].each do |page|
        get page
      end
    end
  end
  
  
  resources :manufacturers, only: [:show, :index]
  match 'manufacturers_mock_csv', to: 'manufacturers#mock_csv'

  resources :organization_deals, only: [:create, :new]
  resource :integrations, only: [:create]
  match '/auth/:provider/callback', to: "integrations#create"

  %w[stolen_bikes protect_your_bike privacy terms serials about where roadmap security vendor_terms resources spokecard].each do |page|
    get page, controller: 'info', action: page
  end

  # get 'sitemap.xml.gz' => redirect("https://s3.amazonaws.com/bikeindex/sitemaps/sitemap_index.xml.gz")
  # Somehow the redirect drops the .gz extension, which ruins it so this redirect is handled by Cloudflare
  # get "sitemaps/(*all)" => redirect("https://s3.amazonaws.com/bikeindex/sitemaps/%{all}")
  
  match '/400', to: 'errors#bad_request'
  match '/404', to: 'errors#not_found'
  match '/422', to: 'errors#unprocessable_entity'
  match '/500', to: 'errors#server_error'

  mount Sidekiq::Web => '/sidekiq', constraints: AdminRestriction
  
end
