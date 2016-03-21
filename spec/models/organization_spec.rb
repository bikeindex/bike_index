require 'spec_helper'

describe Organization do
  
  describe :validations do
    # it { should validate_uniqueness_of :slug }
    it { should validate_presence_of :name }
    it { should have_many :memberships }
    it { should have_many :organization_deals }
    it { should have_many :users }
    it { should have_many :organization_invitations }
    it { should have_many :locations }
    it { should have_many :bikes }
    it { should belong_to :auto_user }
  end

  describe :set_and_clean_attributes do 
    it "sets the short_name and the slug on save" do 
      organization = Organization.new(name: 'something')
      organization.set_and_clean_attributes
      organization.short_name.should be_present
      organization.slug.should be_present
      slug = organization.slug 
      organization.save 
      organization.slug.should eq(slug)
    end

    it "doesn't xss" do 
      org = Organization.new(name: '<script>alert(document.cookie)</script>', 
        website: '<script>alert(document.cookie)</script>')
      org.set_and_clean_attributes
      org.name.should eq("alert(document.cookie)")
      org.website.should eq("http://<script>alert(document.cookie)</script>")
      org.short_name.should eq("alert(document.cookie)")
    end

    it "protects from name collisions, without erroring because of it's own slug" do 
      org1 = Organization.create(name: 'Bicycle shop')
      org1.reload.save
      org1.reload.slug.should eq('bicycle-shop')
      organization = Organization.new(name: 'Bicycle shop')
      organization.set_and_clean_attributes
      organization.slug.should eq('bicycle-shop-2')
    end

    it "has before_save_callback_method defined for set_and_clean_attributes" do
      Organization._save_callbacks.select { |cb| cb.kind.eql?(:before) }.map(&:raw_filter).include?(:set_and_clean_attributes).should == true
    end
  end

  describe :set_locations_shown do 
    it "sets the locations shown to be org shown on save" do 
      organization = FactoryGirl.create(:organization)
      country = FactoryGirl.create(:country)
      location = Location.create(country_id: country.id, city: 'Chicago', name: 'stuff', organization_id: organization.id)
      organization.reload.update_attribute :show_on_map, true
      location.reload.shown.should be_true
      organization.update_attribute :show_on_map, false
      location.reload.shown.should be_false
    end
  end

  describe :set_auto_user do 
    it "sets the embedable user" do 
      organization = FactoryGirl.create(:organization)
      user = FactoryGirl.create(:user, email: "embed@org.com")
      membership = FactoryGirl.create(:membership, organization: organization, user: user)
      organization.embedable_user_email = "embed@org.com"
      organization.save
      organization.reload.auto_user_id.should eq(user.id)
    end
    it "does not set the embedable user if user is not a member" do 
      organization = FactoryGirl.create(:organization)
      user = FactoryGirl.create(:user, email: "no_embed@org.com")
      organization.embedable_user_email = "no_embed@org.com"
      organization.save
      organization.reload.auto_user_id.should be_nil
    end
    it "Makes a membership if the user is auto user" do 
      organization = FactoryGirl.create(:organization)
      user = FactoryGirl.create(:user, email: ENV['AUTO_ORG_MEMBER'])
      organization.embedable_user_email = ENV['AUTO_ORG_MEMBER']
      organization.save
      organization.reload.auto_user_id.should eq(user.id)
    end
    it "sets the embedable user if it isn't set and the org has members" do 
      organization = FactoryGirl.create(:organization)
      user = FactoryGirl.create(:user)
      membership = FactoryGirl.create(:membership, user: user, organization: organization)
      organization.save
      organization.reload.auto_user_id.should_not be_nil
    end
  end

  describe :clear_map_cache do 
    it "has before_save_callback_method defined for clear clear_map_cache" do
      Organization._save_callbacks.select { |cb| cb.kind.eql?(:after) }.map(&:raw_filter).include?(:clear_map_cache).should == true
    end
  end


end
