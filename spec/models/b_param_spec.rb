require 'spec_helper'

describe BParam do
  describe :validations do
    it { should belong_to :created_bike }
    it { should belong_to :creator }
    it { should validate_presence_of :creator }
  end

  describe :bike do 
    it "returns the bike attribs" do 
      b_param = BParam.new 
      b_param.stub(:params).and_return({bike: {serial_number: "XXX"}})
      b_param.bike[:serial_number].should eq("XXX")
    end
    it "does not fail if there isn't a bike" do 
      user = FactoryGirl.create(:user)
      b_param = BParam.new(creator_id: user.id, params: { stolen: true })
      b_param.save.should be_true
    end
  end

  describe :massage_if_v2 do 
    it "renames v2 keys" do 
      p = {
        serial: 'something',
        manufacturer: 'something else',
        test: true,
        stolen_record: {
          date_stolen: '',
          phone: nil
        }
      }
      b_param = BParam.new(params: p, api_v2: true)
      b_param.massage_if_v2
      k = b_param.params[:bike]
      (k.keys.include?(:serial_number)).should be_true
      (k.keys.include?(:manufacturer)).should be_true
      k.keys.length.should eq(2)
      b_param.params[:test].should be_true
      b_param.params[:stolen].should be_false
      b_param.params[:stolen_record].should_not be_present
    end
    it "gets the organization id" do
      org = FactoryGirl.create(:organization, name: "Something")
      p = { organization_slug: org.slug }
      b_param = BParam.new(params: p, api_v2: true)
      b_param.massage_if_v2
      b_param.params[:bike][:creation_organization_id].should eq(org.id)
    end
    it "has before_save_callback_method defined as a before_save callback" do
      BParam._save_callbacks.select { |cb| cb.kind.eql?(:before) }.map(&:raw_filter).include?(:massage_if_v2).should == true
    end
  end

  describe :set_foreign_keys do 
    it "calls set_foreign_keys" do 
      b_param = BParam.new
      bike = {
        frame_material_slug: "something",
        handlebar_type_slug: "else",
        cycle_type_slug: "entirely"
      }
      b_param.stub(:params).and_return({bike: bike})
      b_param.should_receive(:set_manufacturer_key).and_return(true)
      b_param.should_receive(:set_color_key).and_return(true)
      b_param.should_receive(:set_wheel_size_key).and_return(true)
      b_param.should_receive(:set_cycle_type_key).and_return(true)
      b_param.should_receive(:set_handlebar_type_key).and_return(true)
      b_param.should_receive(:set_frame_material_key).and_return(true)
      b_param.set_foreign_keys
    end
    it "has before_save_callback_method defined as a before_save callback" do
      BParam._save_callbacks.select { |cb| cb.kind.eql?(:before) }.map(&:raw_filter).include?(:set_foreign_keys).should == true
    end
  end

  describe :clean_errors do 
    it "removes error messages we don't want to show users" do 
      errors = ["Manufacturer can't be blank", "Bike can't be blank", "Association error Ownership wasn't saved. Are you sure the bike was created?"]
      b_param = BParam.new(bike_errors: errors)
      b_param.clean_errors
      b_param.bike_errors.length.should eq(1)
    end
    it "has before_save_callback_method defined as a before_save callback" do
      BParam._save_callbacks.select { |cb| cb.kind.eql?(:before) }.map(&:raw_filter).include?(:clean_errors).should == true
    end
  end

  describe :set_wheel_size_key do
    it "sets rear_wheel_size_id to the bsd submitted" do
      ws = FactoryGirl.create(:wheel_size, iso_bsd: "Bike")
      bike = { rear_wheel_bsd: ws.iso_bsd }
      b_param = BParam.new
      b_param.stub(:params).and_return({bike: bike})
      b_param.set_wheel_size_key
      b_param.params[:bike][:rear_wheel_size_id].should eq(ws.id)
    end
  end

  describe :set_cycle_type_key do
    it "sets cycle_type_id to the cycle type from name submitted" do
      ct = FactoryGirl.create(:cycle_type, name: "Boo Boo", slug: "boop")
      bike = { serial_number: "gobble gobble", cycle_type_slug: " booP " }
      b_param = BParam.new
      b_param.stub(:params).and_return({bike: bike})
      b_param.set_cycle_type_key
      b_param.params[:bike][:cycle_type_id].should eq(ct.id)
      b_param.params[:bike][:cycle_type_slug].present?.should be_false
    end
  end

  describe :set_frame_material_key do
    it "sets cycle_type_id to the cycle type from name submitted" do
      fm = FactoryGirl.create(:frame_material, name: "poo poo", slug: "poop")
      bike = { serial_number: "gobble gobble", frame_material_slug: " POOP " }
      b_param = BParam.new
      b_param.stub(:params).and_return({bike: bike})
      b_param.set_frame_material_key
      b_param.params[:bike][:frame_material_slug].present?.should be_false
      b_param.params[:bike][:frame_material_id].should eq(fm.id)
    end
  end

  describe :set_handlebar_type_key do
    it "sets cycle_type_id to the cycle type from name submitted" do
      ht = FactoryGirl.create(:handlebar_type, name: "poo poo", slug: "poopie")
      bike = { serial_number: "gobble gobble", handlebar_type_slug: " POOPie " }
      b_param = BParam.new
      b_param.stub(:params).and_return({bike: bike})
      b_param.set_handlebar_type_key
      b_param.params[:bike][:handlebar_type_slug].present?.should be_false
      b_param.params[:bike][:handlebar_type_id].should eq(ht.id)
    end
  end

  describe :set_manufacturer_key do
    it "adds other manufacturer name and set the set the foreign keys" do
      m = FactoryGirl.create(:manufacturer, name: "Other")
      bike = { manufacturer: "gobble gobble" }
      b_param = BParam.new
      b_param.stub(:params).and_return({bike: bike})
      b_param.set_manufacturer_key
      b_param.params[:bike][:manufacturer].should_not be_present
      b_param.params[:bike][:manufacturer_id].should eq(m.id)
      b_param.params[:bike][:manufacturer_other].should eq('Gobble Gobble')
    end
    it "looks through book slug" do
      m = FactoryGirl.create(:manufacturer, name: "Something Cycles")
      bike = { manufacturer: "something" }
      b_param = BParam.new
      b_param.stub(:params).and_return({bike: bike})
      b_param.set_manufacturer_key
      b_param.params[:bike][:manufacturer].should_not be_present
      b_param.params[:bike][:manufacturer_id].should eq(m.id)
    end
  end

  describe :set_color_key do
    it "sets the color if it's a color and remove the color attr" do
      color = FactoryGirl.create(:color)
      bike = { color: color.name }
      b_param = BParam.new
      b_param.stub(:params).and_return({bike: bike})
      b_param.set_color_key
      b_param.params[:bike][:color].should_not be_present
      b_param.params[:bike][:primary_frame_color_id].should eq(color.id)
    end
    it "set_paint_keys if it it isn't a color" do 
      bike = { color: "Goop" }
      b_param = BParam.new
      b_param.stub(:params).and_return({bike: bike})
      b_param.should_receive(:set_paint_key).and_return(true)
      b_param.set_color_key
    end
  end

  describe :set_paint_key do
    it "associates the paint and set the color if it can" do
      FactoryGirl.create(:color, name: 'Black')
      color = FactoryGirl.create(:color, name: 'Yellow')
      paint = FactoryGirl.create(:paint, name: 'pinkly butter', color_id: color.id)
      b_param = BParam.new(params: {bike: {}})
      # b_param.stub(:params).and_return({bike: {}})
      b_param.set_paint_key(paint.name)
      b_param.params[:bike][:paint_id].should eq(paint.id)
      b_param.params[:bike][:primary_frame_color_id].should eq(color.id)
    end

    it "creates a color shade and set the color to black if we don't know the color" do
      black = FactoryGirl.create(:color, name: "Black")
      b_param = BParam.new
      b_param.stub(:params).and_return({bike: {}})
      lambda {
        b_param.set_paint_key("Paint 69")
      }.should change(Paint, :count).by(1)
      b_param.params[:bike][:paint_id].should eq(Paint.find_by_name("paint 69").id)
      b_param.params[:bike][:primary_frame_color_id].should eq(black.id)
    end

    it "associates the manufacturer with the paint if it's a new bike" do
      color = FactoryGirl.create(:color, name: "Black")
      m = FactoryGirl.create(:manufacturer)
      bike = { registered_new: true, manufacturer_id: m.id }
      b_param = BParam.new
      b_param.stub(:params).and_return({bike: bike})
      b_param.set_paint_key("paint 69")
      p = Paint.find_by_name("paint 69")
      p.manufacturer_id.should eq(m.id)
    end
  end

end
