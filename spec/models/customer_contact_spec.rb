require 'spec_helper'

describe CustomerContact do
  describe :validations do
    it { should validate_presence_of :user_email }
    it { should validate_presence_of :creator_email }
    # it { should validate_presence_of :creator_id }
    it { should validate_presence_of :contact_type }
    it { should validate_presence_of :bike_id }
    it { should validate_presence_of :title }
    it { should validate_presence_of :body }
    it { should belong_to :user }
    it { should belong_to :creator }
    it { should belong_to :bike }
    it { should serialize :info_hash }
  end

  describe :normalize_email_and_find_user do 
    it "finds email and associate" do 
      user = FactoryGirl.create(:user)
      cc = CustomerContact.new
      cc.stub(:user_email).and_return(user.email)
      cc.normalize_email_and_find_user
      cc.user_id.should eq(user.id)
    end
    it "has before_save_callback_method defined as a before_save callback" do
      CustomerContact._save_callbacks.select { |cb| cb.kind.eql?(:before) }.map(&:raw_filter).include?(:normalize_email_and_find_user).should == true
    end
  end


end
