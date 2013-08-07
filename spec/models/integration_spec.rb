require 'spec_helper'

describe Integration do
  describe :validations do
    it "should require a user id, refresh_token, provider_name, expires_in, and access_token" do
      i = Integration.new
      i.valid?.should be_false
      e = i.errors.messages
      e[:information].should be_present
      e[:access_token].should be_present
      e[:provider_name].should be_present
    end
  end

  describe :associate_with_user do
    it "should associate with a user if the emails match" do 
      info = {"provider"=>"facebook", "uid"=>"64901670", "info"=>{"nickname"=>"foo.user.5", "email"=>"foo.user@gmail.com", "name"=>"foo user", "first_name"=>"foo", "last_name"=>"user", "image"=>"http://graph.facebook.com/64901670/picture?type=square", "urls"=>{"Facebook"=>"http://www.facebook.com/foo.user.5"}, "verified"=>true}, "credentials"=>{"token"=>"CAAGW44SIv5sBACqokzRSPaAhh3xiQntB8GD6oRKHToSLWFzz4kv32tJUpK2aZCg3pdzyUNODKjtvXdJyMqCnyZCqPgJvluOK08sbDgRXgQ5oIggVl2pxnokDD09kF1xkQIyUhTI55sUyxOkjKo", "expires_at"=>1373982961, "expires"=>true}, "extra"=>{"raw_info"=>{"id"=>"64901670", "name"=>"foo user", "first_name"=>"foo", "last_name"=>"user", "link"=>"http://www.facebook.com/foo.user.5", "username"=>"foo.user.5", "gender"=>"male", "email"=>"foo.user@gmail.com", "timezone"=>-5, "locale"=>"en_US", "verified"=>true, "updated_time"=>"2012-08-06T23:32:31+0000"}}}
      u = FactoryGirl.create(:user, email: "foo.user@gmail.com")
      i = FactoryGirl.create(:integration, information: info)
      u.id.should eq(i.user.id)
    end

    it "should mark the user confirmed but not mark the terms of service agreed" do 
      info = {"provider"=>"facebook", "uid"=>"64901670", "info"=>{"nickname"=>"foo.user.5", "email"=>"foo.user@gmail.com", "name"=>"foo user", "first_name"=>"foo", "last_name"=>"user", "image"=>"http://graph.facebook.com/64901670/picture?type=square", "urls"=>{"Facebook"=>"http://www.facebook.com/foo.user.5"}, "verified"=>true}, "credentials"=>{"token"=>"CAAGW44SIv5sBACqokzRSPaAhh3xiQntB8GD6oRKHToSLWFzz4kv32tJUpK2aZCg3pdzyUNODKjtvXdJyMqCnyZCqPgJvluOK08sbDgRXgQ5oIggVl2pxnokDD09kF1xkQIyUhTI55sUyxOkjKo", "expires_at"=>1373982961, "expires"=>true}, "extra"=>{"raw_info"=>{"id"=>"64901670", "name"=>"foo user", "first_name"=>"foo", "last_name"=>"user", "link"=>"http://www.facebook.com/foo.user.5", "username"=>"foo.user.5", "gender"=>"male", "email"=>"foo.user@gmail.com", "timezone"=>-5, "locale"=>"en_US", "verified"=>true, "updated_time"=>"2012-08-06T23:32:31+0000"}}}
      u = FactoryGirl.create(:user, email: "foo.user@gmail.com", confirmed: false, terms_of_service: false)
      i = FactoryGirl.create(:integration, information: info)
      i.user.confirmed.should be_true
      i.user.terms_of_service.should be_false
    end
    
    it "should create a user, associate it if the emails match and run new user tasks" do 
      info = {"provider"=>"facebook", "uid"=>"64901670", "info"=>{"nickname"=>"foo.user.5", "email"=>"foo.user@gmail.com", "name"=>"foo user", "first_name"=>"foo", "last_name"=>"user", "image"=>"http://graph.facebook.com/64901670/picture?type=square", "urls"=>{"Facebook"=>"http://www.facebook.com/foo.user.5"}, "verified"=>true}, "credentials"=>{"token"=>"CAAGW44SIv5sBACqokzRSPaAhh3xiQntB8GD6oRKHToSLWFzz4kv32tJUpK2aZCg3pdzyUNODKjtvXdJyMqCnyZCqPgJvluOK08sbDgRXgQ5oIggVl2pxnokDD09kF1xkQIyUhTI55sUyxOkjKo", "expires_at"=>1373982961, "expires"=>true}, "extra"=>{"raw_info"=>{"id"=>"64901670", "name"=>"foo user", "first_name"=>"foo", "last_name"=>"user", "link"=>"http://www.facebook.com/foo.user.5", "username"=>"foo.user.5", "gender"=>"male", "email"=>"foo.user@gmail.com", "timezone"=>-5, "locale"=>"en_US", "verified"=>true, "updated_time"=>"2012-08-06T23:32:31+0000"}}}
      lambda do
        CreateUserJobs.any_instance.should_receive(:do_jobs).and_return(true)
        i = FactoryGirl.create(:integration, information: info)
      end.should change(User, :count).by(1)
    end
    
    it "should delete previous integrations with the same service" do
      info = {"provider"=>"facebook", "uid"=>"64901670", "info"=>{"nickname"=>"foo.user.5", "email"=>"foo.user@gmail.com", "name"=>"foo user", "first_name"=>"foo", "last_name"=>"user", "image"=>"http://graph.facebook.com/64901670/picture?type=square", "urls"=>{"Facebook"=>"http://www.facebook.com/foo.user.5"}, "verified"=>true}, "credentials"=>{"token"=>"CAAGW44SIv5sBACqokzRSPaAhh3xiQntB8GD6oRKHToSLWFzz4kv32tJUpK2aZCg3pdzyUNODKjtvXdJyMqCnyZCqPgJvluOK08sbDgRXgQ5oIggVl2pxnokDD09kF1xkQIyUhTI55sUyxOkjKo", "expires_at"=>1373982961, "expires"=>true}, "extra"=>{"raw_info"=>{"id"=>"64901670", "name"=>"foo user", "first_name"=>"foo", "last_name"=>"user", "link"=>"http://www.facebook.com/foo.user.5", "username"=>"foo.user.5", "gender"=>"male", "email"=>"foo.user@gmail.com", "timezone"=>-5, "locale"=>"en_US", "verified"=>true, "updated_time"=>"2012-08-06T23:32:31+0000"}}}
      i = FactoryGirl.create(:integration, information: info)
      i.user.confirmed.should be_true
      i2 =  FactoryGirl.create(:integration, information: info)
      Integration.count.should eq(1)
    end

  end
end
