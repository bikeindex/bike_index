# Uncomment get the coverage. Leave commented most of the time,
# it slows down the test suite

# require 'simplecov'
# SimpleCov.start 'rails' do
#   add_group "Services", "app/services"
#   add_group "Serializers", "app/serializers"
#   add_group "Decorators", "app/decorators"
#   add_group "Uploaders", "app/uploaders"
#   minimum_coverage 80
# end

require 'sidekiq/testing'
if ENV['CODECLIMATE_REPO_TOKEN']
  require "codeclimate-test-reporter"
  CodeClimate::TestReporter.start
end

ENV["RAILS_ENV"] ||= 'test'
require File.expand_path("../../config/environment", __FILE__)
require 'rspec/rails'
require 'rspec/autorun'
require 'database_cleaner'

DatabaseCleaner.strategy = :truncation

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[Rails.root.join("spec/support/**/*.rb")].each {|f| require f}

RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.infer_base_class_for_anonymous_controllers = false
  
  config.before :suite do
    DatabaseCleaner.clean
  end

  config.before(:each) do
    DatabaseCleaner.start
  end

  config.after(:each) do
    DatabaseCleaner.clean
  end
end

def set_current_user(user)
  cookies.signed[:auth] = {secure: true, httponly: true, value: [user.id, user.auth_token]}
end

def create_doorkeeper_app(opts={})
  @user = FactoryGirl.create(:user)
  @application = Doorkeeper::Application.new(name: "MyApp", redirect_uri: "http://app.com")
  @application.owner = @user
  @application.save
  @token = Doorkeeper::AccessToken.create!(application_id: @application.id, resource_owner_id: @user.id, scopes: opts && opts[:scopes])
end

OmniAuth.config.mock_auth[:facebook] = OmniAuth::AuthHash.new({
  "provider"=>"facebook", 
  "uid"=>"64901670", 
  "info"=>{
    "nickname"=>"foo.user.5", 
    "email"=>"foo.user@gmail.com", 
    "name"=>"foo user", 
    "first_name"=>"foo", 
    "last_name"=>"user", 
    "image"=>"http://graph.facebook.com/64901670/picture?type=square", 
    "urls"=>{
      "Facebook"=>"http://www.facebook.com/foo.user.5"
    }, 
    "verified"=>true
  }, 
  "credentials"=>{
    "token"=>"CAAGW44SIv5sBACqokzRSPaAhh3xiQntB8GD6oRKHToSLWFzz4kv32tJUpK2aZCg3pdzyUNODKjtvXdJyMqCnyZCqPgJvluOK08sbDgRXgQ5oIggVl2pxnokDD09kF1xkQIyUhTI55sUyxOkjKo",
    "expires_at"=>1373982961, 
    "expires"=>true
  }, 
  "extra"=>{
    "raw_info"=>{
      "id"=>"64901670", 
      "name"=>"foo user", 
      "first_name"=>"foo", 
      "last_name"=>"user", 
      "link"=>"http://www.facebook.com/foo.user.5", 
      "username"=>"foo.user.5", 
      "gender"=>"male", 
      "email"=>"foo.user@gmail.com", 
      "timezone"=>-5, 
      "locale"=>"en_US", 
      "verified"=>true, 
      "updated_time"=>"2012-08-06T23:32:31+0000"
    }
  }
})

Geocoder.configure(:lookup => :test)
Geocoder::Lookup::Test.set_default_stub(
[
  {
    'latitude'     => 40.7143528,
    'longitude'    => -74.0059731,
    'address'      => 'New York, NY, USA',
    'state'        => 'New York',
    'state_code'   => 'NY',
    'country'      => 'United States',
    'country_code' => 'US'
  }
 ]
)