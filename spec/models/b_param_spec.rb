require 'spec_helper'

describe BParam do
  describe :validations do
    it { should belong_to :created_bike }
    it { should belong_to :creator }
    it { should validate_presence_of :creator }
  end

  describe :bike do 
    it "should return the bike attribs" do 
      b_param = BParam.new 
      b_param.stub(:params).and_return({:bike => {serial_number: "XXX"}})
      b_param.bike[:serial_number].should eq("XXX")
    end
  end


  describe :set_foreign_keys do
    it "should remove association names and replace them with ids" do
      FactoryGirl.create(:manufacturer, name: "Other")
      color = FactoryGirl.create(:color)
      bike = { serial_number: "69",
        manufacturer_name: "gobble gobble",
        primary_frame_color_name: color.name
      }
      b_param = FactoryGirl.create(:b_param, params: {bike: bike})
      b_param.set_foreign_keys
      b_param.reload
      b_param.reload.params[:bike][:manufacturer_name].should_not be_present
      b_param.reload.params[:bike][:manufacturer_other].should eq('Gobble Gobble')
      b_param.reload.params[:bike][:primary_frame_color_name].should_not be_present
      b_param.reload.params[:bike][:primary_frame_color_id].should eq(color.id)
    end
  end

end
