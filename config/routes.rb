Bikeindex::Application.routes.draw do

  get "dashboard/show"

  constraints(Subdomain) do
    match '/overview' => 'organizations#show'
    match '/manage' => 'organizations#manage'
    match '/organization_bikes' => 'organizations#bikes'
    match '/settings' => 'organizations#settings'
  end
  
  resources :organizations, only: [:update, :destroy]

  root to: 'welcome#index'

  match 'user_home', to: 'welcome#user_home'
  match 'choose_registration', to: 'welcome#choose_registration'
  match 'goodbye', to: 'welcome#goodbye'

  resource :session, only: [:new, :create, :destroy]
  match 'logout', to: 'sessions#destroy'

  resource :charges, only: [:new, :create]

  resources :ownerships, only: [:show]
  resources :organization_invitations, only: [:new, :create]
  resources :memberships, only: [:update, :destroy]

  resources :stolen_notifications, only: [:create, :new]

  resources :feedbacks, only: [:create, :new]
  match 'vendor_signup', to: 'feedbacks#vendor_signup'
  match 'contact_us', to: 'feedbacks#new'
  
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

  resources :blogs, only: [:show, :index]
  match 'blog', to: "blogs#index"

  resources :public_images, only: [:create, :show, :edit, :update, :destroy] do 
    collection do
      post :order
    end
  end
  
  resources :bikes do
    member do
     get 'spokecard'
   end
  end
  resources :locks

  namespace :admin do
    root :to => 'dashboard#show'
    match 'invitations', to: 'dashboard#invitations'
    resources :discounts, :memberships, :bikes, :organizations, :bike_token_invitations, :organization_invitations
    match 'duplicate_bikes', to: 'bikes#duplicates'
    resources :flavor_texts, only: [:destroy, :create]
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
      resources :bikes, only: [:index, :show]
      resources :manufacturers, only: [:index, :show]
      resources :users do 
        collection { get 'current' }
      end
    end
  end

  resources :manufacturers, only: [:show, :index]
  match 'manufacturers_mock_csv', to: 'manufacturers#mock_csv'


  resource :integrations, only: [:create]
  match '/auth/:provider/callback', :to => "integrations#create"

  %w[stolen_bikes privacy terms serials about where roadmap security vendor_terms resources stolen spokecard].each do |page|
    get page, controller: 'info', action: page
  end

  get 'sitemap.xml' => 'sitemaps#index', as: 'sitemap', defaults: { format: 'xml' }
  match 'sitemap', to: 'sitemaps#index', defaults: { format: 'xml' }

  match '/400', to: 'errors#bad_request'
  match '/404', to: 'errors#not_found'
  match '/422', to: 'errors#unprocessable_entity'
  
  mount Resque::Server.new, :at => '/resque'
end
