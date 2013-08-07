require 'spec_helper'

describe StolenRecord do
  
  describe :validations do 
    it { should validate_presence_of :bike }
    it { should validate_presence_of :date_stolen }
  end

  it "should mark current true by default" do 
    stolen_record = StolenRecord.new
    stolen_record.current.should be_true
  end

  it "should only allow one current stolen record per bike"

  describe :address do 
    it "should create an address" do 
      stolen_record = FactoryGirl.create(:stolen_record, street: "2200 N Milwaukee Ave", city: "Chicago", state: "IL", zipcode: "60647" )
      stolen_record.address.should eq("2200 N Milwaukee Ave, Chicago, IL, 60647, United States")
    end
  end

  describe "default scope" do 
    it "should only include current descriptions" do 
      StolenRecord.scoped.to_sql.should == StolenRecord.where(current: true).to_sql
    end
  end
end
