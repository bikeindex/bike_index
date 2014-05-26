require 'spec_helper'

describe StolenRecord do
  
  describe :validations do 
    it { should validate_presence_of :bike }
    it { should validate_presence_of :date_stolen }
    it { should belong_to :bike }
    it { should belong_to :country }
    it { should belong_to :state }
    it { should belong_to :creation_organization }
  end

  it "should mark current true by default" do 
    stolen_record = StolenRecord.new
    stolen_record.current.should be_true
  end

  it "should only allow one current stolen record per bike"

  describe :address do 
    it "should create an address" do 
      c = Country.create(name: "Neverland", iso: "XXX")
      s = State.create(country_id: c.id, name: "BullShit", abbreviation: "XXX")
      stolen_record = FactoryGirl.create(:stolen_record, street: "2200 N Milwaukee Ave", city: "Chicago", state_id: s.id, zipcode: "60647", country_id: c.id)
      stolen_record.address.should eq("2200 N Milwaukee Ave, Chicago, XXX, 60647, Neverland")
    end
  end

  describe "default scope" do 
    it "should only include current descriptions" do 
      StolenRecord.scoped.to_sql.should == StolenRecord.where(current: true).to_sql
    end
  end

  describe :tsv_row do 
    it "should return the tsv row" do 
      stolen_record = FactoryGirl.create(:stolen_record)
      stolen_record.bike.update_attribute :description, "I like tabs because i'm a jerk\t sometimes\n"
      row = stolen_record.tsv_row
      row.gsub("/\t",'').split("\t").count.should eq(9)
      row.split("\n").count.should eq(1)
    end
  end

  describe :stolen_record do 
    it "it should set_phone" do 
      stolen_record = FactoryGirl.create(:stolen_record)
      stolen_record.phone = '000/000/0000'
      stolen_record.secondary_phone = '000/000/0000'
      stolen_record.set_phone
      stolen_record.phone.should eq('0000000000')
      stolen_record.secondary_phone.should eq('0000000000')
    end
    it "should have before_save_callback_method defined as a before_save callback" do
      StolenRecord._save_callbacks.select { |cb| cb.kind.eql?(:before) }.map(&:raw_filter).include?(:set_phone).should == true
    end
  end

end
