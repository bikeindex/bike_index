require 'spec_helper'

describe Organization do
  
  describe :validations do
    # it { should validate_uniqueness_of :slug }
    it { should validate_presence_of :name }
    it { should validate_presence_of :default_bike_token_count }
    it { should have_many :memberships }
    it { should have_many :organization_deals }
    it { should have_many :users }
    it { should have_many :organization_invitations }
    it { should have_many :locations }
    it { should have_many :bikes }
    it { should belong_to :auto_user }
  end

  it "has before_save_callback_method defined for set_website" do
    Organization._save_callbacks.select { |cb| cb.kind.eql?(:before) }.map(&:raw_filter).include?(:set_website).should == true
  end

  describe :set_short_name_and_slug do 
    it "sets the short_name and the slug" do 
      organization = Organization.new(name: 'something')
      organization.set_short_name_and_slug
      organization.short_name.should be_present
      organization.slug.should be_present
      slug = organization.slug 
      organization.save 
      organization.slug.should eq(slug)
    end

    it "protects from name collisions, without erroring because of it's own slug" do 
      org1 = Organization.create(name: 'Bicycle shop')
      org1.reload.save
      org1.reload.slug.should eq('bicycle-shop')
      organization = Organization.new(name: 'Bicycle shop')
      organization.set_short_name_and_slug
      organization.slug.should eq('bicycle-shop-2')
    end

    it "has before_save_callback_method defined for set_short_name_and_slug" do
      Organization._save_callbacks.select { |cb| cb.kind.eql?(:before) }.map(&:raw_filter).include?(:set_short_name_and_slug).should == true
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
    it "sets the embedable user if it isn't set and the org has members" do 
      organization = FactoryGirl.create(:organization)
      user = FactoryGirl.create(:user)
      membership = FactoryGirl.create(:membership, user: user, organization: organization)
      organization.save
      organization.reload.auto_user_id.should_not be_nil
    end
  end

end
