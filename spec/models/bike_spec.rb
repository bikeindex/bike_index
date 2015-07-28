require 'spec_helper'

describe Bike do

  describe :validations do
    it { should belong_to :manufacturer }
    it { should belong_to :primary_frame_color }
    it { should belong_to :secondary_frame_color }
    it { should belong_to :tertiary_frame_color }
    it { should belong_to :handlebar_type }
    it { should belong_to :rear_wheel_size }
    it { should belong_to :front_wheel_size }
    it { should belong_to :rear_gear_type }
    it { should belong_to :front_gear_type }
    it { should belong_to :frame_material }
    it { should belong_to :propulsion_type }
    it { should belong_to :paint }
    it { should belong_to :cycle_type }
    it { should belong_to :creator }
    it { should belong_to :updator }
    it { should belong_to :creation_organization }
    it { should belong_to :current_stolen_record }
    it { should belong_to :location }
    it { should have_many :b_params }
    it { should have_many :stolen_notifications }
    it { should have_many :stolen_records }
    it { should have_many :ownerships }
    it { should have_many :public_images }
    it { should have_many :components }
    it { should have_many :other_listings }
    it { should accept_nested_attributes_for :stolen_records }
    it { should accept_nested_attributes_for :components }
    it { should validate_presence_of :cycle_type_id }
    it { should validate_presence_of :propulsion_type_id }
    it { should validate_presence_of :creator }
    it { should validate_presence_of :serial_number }
    it { should validate_presence_of :manufacturer_id }
    # it { should validate_presence_of :rear_wheel_size_id }
    it { should validate_presence_of :primary_frame_color_id }
    it { should serialize :cached_attributes }
  end


  describe "scopes" do 
    it "default scopes to created_at desc" do 
      Bike.scoped.to_sql.should == Bike.where(example: false).where(hidden: false).order("listing_order desc").to_sql
    end
    it "scopes to only stolen bikes" do 
      Bike.stolen.to_sql.should == Bike.where(stolen: true).to_sql
    end
    it "non_stolen scopes to only non_stolen bikes" do 
      Bike.non_stolen.to_sql.should == Bike.where(stolen: false).to_sql
    end
  end

  describe :recovered_records do 
    it "default scopes to created_at desc" do 
      o = FactoryGirl.create(:ownership)
      user = o.creator
      bike = o.bike
      recovered_2 = FactoryGirl.create(:stolen_record, bike: bike, current: false)
      recovered_1 = FactoryGirl.create(:stolen_record, bike: bike, current: false, date_stolen: (Time.now - 1.day))
      bike.reload.recovered_records.first.should eq(recovered_2)
    end
  end

  describe :visible_by do 
    it "isn't be visible to owner unless user hidden" do 
      bike = Bike.new(hidden: true)
      user = User.new
      bike.stub(:owner).and_return(user)
      bike.stub(:user_hidden).and_return(false)
      bike.visible_by(user).should be_false
    end
    it "is visible to owner" do 
      bike = Bike.new(hidden: true)
      user = User.new
      bike.stub(:owner).and_return(user)
      bike.stub(:user_hidden).and_return(true)
      bike.visible_by(user).should be_true
    end
    it "is visible to superuser" do 
      bike = Bike.new(hidden: true)
      user = User.new
      user.superuser = true
      bike.visible_by(user).should be_true
    end
    it "is visible if not hidden" do 
      bike = Bike.new
      bike.visible_by.should be_true
    end
  end

  describe :attr_cache_search do
    it "finds bikes by attr cache" do
      bike = FactoryGirl.create(:bike)
      query = ["1c#{bike.primary_frame_color_id}"]
      result = Bike.attr_cache_search(query)
      result.first.should eq(bike)
      result.class.should eq(ActiveRecord::Relation)
    end
    it "finds bikes by wheel size" do
      bike = FactoryGirl.create(:bike)
      query = ["1w#{bike.rear_wheel_size_id}"]
      result = Bike.attr_cache_search(query)
      result.first.should eq(bike)
      result.class.should eq(ActiveRecord::Relation)
    end
  end

  describe :owner do
    it "receives owner from the last ownership" do
      first_ownership = Ownership.new 
      second_ownership = Ownership.new
      user = User.new
      bike = Bike.new 
      bike.stub(:ownerships).and_return([first_ownership, second_ownership])
      second_ownership.stub(:owner).and_return(user)
      bike.owner.should eq(user)
    end
    it "doesn't break if the owner is deleted" do
      delete_user = FactoryGirl.create(:user)
      ownership = FactoryGirl.create(:ownership, user_id: delete_user.id)
      ownership.mark_claimed
      bike = ownership.bike
      expect(bike.owner).to eq(delete_user)
      delete_user.delete
      ownership.reload
      expect(bike.owner).to eq(ownership.creator)
    end
  end

  describe :first_owner_email do
    it "gets owner email from the first ownership" do
      first_ownership = Ownership.new(owner_email: 'foo@example.com')
      second_ownership = Ownership.new
      bike = Bike.new 
      bike.stub(:ownerships).and_return([first_ownership, second_ownership])
      bike.first_owner_email.should eq('foo@example.com')
    end
  end

  describe :frame_size do 
    it "removes crap from bike size strings" do 
      bike = Bike.new(frame_size: "19\\\\\"")
      bike.clean_frame_size
      bike.frame_size_number.should eq(19)
      bike.frame_size.should eq('19in')
      bike.frame_size_unit.should eq('in')
    end
    it "sets things" do 
      bike = Bike.new(frame_size_number: "19.5sa", frame_size_unit: 'in')
      bike.clean_frame_size
      bike.frame_size_number.should eq(19.5)
      bike.frame_size.should eq('19.5in')
      bike.frame_size_unit.should eq('in')
    end
    it "removes extra numbers and other things from size strings" do 
      bike = Bike.new(frame_size: "19.5 somethingelse medium 54cm")
      bike.clean_frame_size
      bike.frame_size_number.should eq(19.5)
      bike.frame_size.should eq('19.5in')
      bike.frame_size_unit.should eq('in')
    end
    it "figures out that it's cm" do 
      bike = Bike.new(frame_size: "Med/54cm")
      bike.clean_frame_size 
      bike.frame_size_number.should eq(54)
      bike.frame_size.should eq('54cm')
      bike.frame_size_unit.should eq('cm')
    end
    it "is cool with ordinal sizing" do 
      bike = Bike.new(frame_size: "Med")
      bike.clean_frame_size 
      bike.frame_size.should eq('m')
      bike.frame_size_unit.should eq('ordinal')
    end
    it "is cool with ordinal sizing" do 
      bike = Bike.new(frame_size: "M")
      bike.clean_frame_size 
      bike.frame_size.should eq('m')
      bike.frame_size_unit.should eq('ordinal')
    end
    
    it "has before_save_callback_method defined for clean_frame_size" do
      Bike._save_callbacks.select { |cb| cb.kind.eql?(:before) }.map(&:raw_filter).include?(:clean_frame_size).should == true
    end
  end

  describe :current_owner_exists do 
    it "returns false if ownership isn't claimed" do
      bike = Bike.new 
      ownership = Ownership.new
      bike.stub(:ownerships).and_return([ownership])
      bike.current_owner_exists.should be_false
    end
    it "returns true if ownership is claimed" do
      bike = Bike.new 
      ownership = Ownership.new(claimed: true)
      bike.stub(:ownerships).and_return([ownership])
      bike.current_owner_exists.should be_true
    end
  end

  describe :can_be_claimed_by do 
    it "returns false if the bike is already claimed" do 
      user = User.new
      bike = Bike.new
      bike.stub(:current_owner_exists).and_return(true)
      bike.can_be_claimed_by(user).should be_false
    end

    it "returns true if the bike can be claimed" do 
      user = User.new
      ownership = Ownership.new
      bike = Bike.new
      bike.stub(:current_ownership).and_return(ownership)
      ownership.stub(:user).and_return(user)
      bike.stub(:current_owner_exists).and_return(false)
      bike.can_be_claimed_by(user).should be_true
    end
  end

  describe :user_hidden do 
    it "is true if bike is hidden and ownership is user hidden" do 
      bike = Bike.new(hidden: true)
      ownership = Ownership.new(user_hidden: true)
      bike.stub(:current_ownership).and_return(ownership)
      bike.user_hidden.should be_true
    end
    it "is false otherwise" do 
      bike = Bike.new(hidden: true)
      bike.user_hidden.should be_false
    end
  end

  describe :fake_deleted do 
    it "is true if bike is hidden and ownership is user hidden" do 
      bike = Bike.new(hidden: true)
      ownership = Ownership.new(user_hidden: true)
      bike.stub(:current_ownership).and_return(ownership)
      bike.fake_deleted.should be_false
    end
    it "is false otherwise" do 
      bike = Bike.new(hidden: true)
      bike.fake_deleted.should be_true
    end
  end

  describe :set_user_hidden do 
    it "unmarks user hidden, saves ownership and marks self unhidden" do 
      ownership = FactoryGirl.create(:ownership, user_hidden: true)
      bike = ownership.bike
      bike.hidden = true
      bike.marked_user_unhidden = true
      bike.set_user_hidden
      bike.hidden.should be_false
      ownership.reload.user_hidden.should be_false
    end

    it "marks updates ownership user hidden, marks self hidden" do 
      ownership = FactoryGirl.create(:ownership)
      bike = ownership.bike
      bike.marked_user_hidden = true
      bike.set_user_hidden
      bike.hidden.should be_true 
      ownership.reload.user_hidden.should be_true
    end

    it "has before_save_callback_method defined for set_user_hidden" do
      Bike._save_callbacks.select { |cb| cb.kind.eql?(:before) }.map(&:raw_filter).include?(:set_user_hidden).should == true
    end
  end

  describe :find_current_stolen_record do 
    it "returns the last current stolen record if bike is stolen" do 
      @bike = Bike.new 
      first_stolen_record = StolenRecord.new
      second_stolen_record = StolenRecord.new
      first_stolen_record.stub(:current).and_return(true)
      second_stolen_record.stub(:current).and_return(true)
      @bike.stub(:stolen).and_return(true)
      @bike.stub(:stolen_records).and_return([first_stolen_record, second_stolen_record])
      @bike.find_current_stolen_record.should eq(second_stolen_record)
    end

    it "is false if the bike isn't stolen" do 
      @bike = Bike.new 
      @bike.stub(:stolen).and_return(false)
      @bike.find_current_stolen_record.should be_false
    end
  end

  describe :manufacturer_name do 
    it "returns the value of manufacturer_other if manufacturer is other" do 
      bike = Bike.new
      other_manufacturer = Manufacturer.new 
      other_manufacturer.stub(:name).and_return("Other")
      bike.stub(:manufacturer).and_return(other_manufacturer)
      bike.stub(:manufacturer_other).and_return("Other manufacturer name")
      bike.manufacturer_name.should eq("Other manufacturer name")
    end

    it "returns the name of the manufacturer if it isn't other" do
      bike = Bike.new
      manufacturer = Manufacturer.new 
      manufacturer.stub(:name).and_return("Mnfg name")
      bike.stub(:manufacturer).and_return(manufacturer)
      bike.manufacturer_name.should eq("Mnfg name")
    end

    it "returns Just SE Bikes" do
      bike = Bike.new
      manufacturer = Manufacturer.new
      manufacturer.stub(:name).and_return("SE Racing (S E Bikes)")
      bike.stub(:manufacturer).and_return(manufacturer)
      bike.manufacturer_name.should eq("SE Racing")
    end
  end

  describe :type do 
    it "returns the cycle type name" do 
      cycle_type = FactoryGirl.create(:cycle_type)
      bike = FactoryGirl.create(:bike, cycle_type: cycle_type)
      bike.type.should eq(cycle_type.name.downcase)
    end
  end

  describe :video_embed_src do 
    it "returns false if there is no video_embed" do 
      @bike = Bike.new 
      @bike.stub(:video_embed).and_return(nil)
      @bike.video_embed_src.should be_nil
    end

    it "returns just the url of the video from a youtube iframe" do 
      youtube_share = '''
          <iframe width="560" height="315" src="//www.youtube.com/embed/Sv3xVOs7_No" frameborder="0" allowfullscreen></iframe>
        '''
      @bike = Bike.new 
      @bike.stub(:video_embed).and_return(youtube_share)
      @bike.video_embed_src.should eq('//www.youtube.com/embed/Sv3xVOs7_No')
    end

    it "returns just the url of the video from a vimeo iframe" do 
      vimeo_share = '''<iframe src="http://player.vimeo.com/video/13094257" width="500" height="281" frameborder="0" webkitAllowFullScreen mozallowfullscreen allowFullScreen></iframe><p><a href="http://vimeo.com/13094257">Fixed Gear Kuala Lumpur, RatsKL Putrajaya</a> from <a href="http://vimeo.com/user3635109">irmanhilmi</a> on <a href="http://vimeo.com">Vimeo</a>.</p>'''
      @bike = Bike.new 
      @bike.stub(:video_embed).and_return(vimeo_share)
      @bike.video_embed_src.should eq('http://player.vimeo.com/video/13094257')
    end
  end

  describe :set_mnfg_name do 
    it "sets a bikes mnfg_name" do 
      manufacturer = FactoryGirl.create(:manufacturer, name: 'SE Racing ( S E Bikes )')
      bike = Bike.new
      bike.stub(:manufacturer).and_return(manufacturer)
      bike.set_mnfg_name
      bike.mnfg_name.should eq("SE Racing")
    end
    it "sets a bikes mnfg_name" do 
      manufacturer = FactoryGirl.create(:manufacturer, name: 'Other')
      bike = Bike.new
      bike.stub(:manufacturer).and_return(manufacturer)
      bike.stub(:manufacturer_other).and_return('<a href="bad_site.js">stuff</a>')
      bike.set_mnfg_name
      bike.mnfg_name.should eq("stuff")
    end
    it "has before_save_callback_method defined for set_mnfg_name" do
      Bike._save_callbacks.select { |cb| cb.kind.eql?(:before) }.map(&:raw_filter).include?(:set_mnfg_name).should == true
    end
  end

  describe :set_normalized_attributes do 
    it "sets a bikes normalized_serial and switches unknown to absent" do 
      bike = Bike.new(serial_number: ' UNKNOWn ')
      SerialNormalizer.any_instance.should_receive(:normalized).and_return('normal')
      bike.normalize_attributes
      bike.serial_number.should eq('absent')
      bike.serial_normalized.should eq('normal')
    end
    it "sets normalized owner email" do 
      bike = Bike.new(owner_email: '  somethinG@foo.orG')
      bike.normalize_attributes
      expect(bike.owner_email).to eq('something@foo.org')
    end
    it "has before_save_callback_method defined" do
      Bike._save_callbacks.select { |cb| cb.kind.eql?(:before) }.map(&:raw_filter).include?(:normalize_attributes).should == true
    end
  end

  describe :serial do 
    it "only returns the serial if we should show people the serial" do 
      # We're hiding serial numbers for bikes that are recovered to provide a method of verifying 
      # ownership
      bike = Bike.new
      bike.stub(:serial_number).and_return('something')
      bike.stub(:recovered).and_return(true)
      bike.serial.should be_nil      
    end
  end


  describe "pg search" do 
    it "returns a bike which has a matching part of its description" do
      @bike = FactoryGirl.create(:bike, description: "Phil wood hub")
      @bikes = Bike.text_search("phil wood hub")
      @bikes.should include(@bike)
    end

    it "returns the bikes in the default scope pattern if there is no query" do 
      bike = FactoryGirl.create(:bike, description: "Phil wood hub")
      bike2 = FactoryGirl.create(:bike)
      bikes = Bike.text_search("")
      bikes.first.should eq(bike)
    end
  end

  describe :set_paints do 
    it "returns true if paint is a color" do 
      FactoryGirl.create(:color, name: "Bluety")
      bike = Bike.new
      bike.stub(:paint_name).and_return(" blueTy")
      lambda { bike.set_paints }.should_not change(Paint, :count)
      bike.paint.should be_nil
    end
    it "removes paint id if paint_name is nil" do 
      paint = FactoryGirl.create(:paint)
      bike = Bike.new(paint_id: paint.id)
      bike.paint_name = ''
      bike.set_paints
      bike.paint.should be_nil
    end
    it "sets the paint if it exists" do 
      FactoryGirl.create(:paint, name: "poopy pile")
      bike = Bike.new
      bike.stub(:paint_name).and_return("Poopy PILE  ")
      lambda { bike.set_paints }.should_not change(Paint, :count)
      bike.paint.name.should eq("poopy pile")
    end
    it "creates a new paint and set it otherwise" do 
      bike = Bike.new
      bike.paint_name = ["Food Time SOOON"]
      lambda { bike.set_paints }.should change(Paint, :count).by(1)
      bike.paint.name.should eq("food time sooon")
    end
    it "has before_save_callback_method defined as a before_save callback" do
      Bike._save_callbacks.select { |cb| cb.kind.eql?(:before) }.map(&:raw_filter).include?(:set_paints).should == true
    end
  end

  describe :cache_photo do 
    it "caches the photo" do 
      bike = FactoryGirl.create(:bike)
      image = FactoryGirl.create(:public_image, imageable: bike)
      bike.reload
      bike.cache_photo
      bike.thumb_path.should_not be_nil
    end
  end

  describe :components_cache_string do 
    it "caches the components" do 
      bike = FactoryGirl.create(:bike)
      c = FactoryGirl.create(:component, bike: bike)
      bike.save
      bike.components_cache_string.should eq("#{c.ctype.name} ")
    end
  end

  describe :cache_attributes do 
    it "caches the colors handlebar_type and wheel_size" do 
      color = FactoryGirl.create(:color)
      handlebar = FactoryGirl.create(:handlebar_type)
      wheel = FactoryGirl.create(:wheel_size)
      bike = FactoryGirl.create(:bike, secondary_frame_color: color, handlebar_type: handlebar, front_wheel_size: wheel)
      bike.cached_attributes[0].should eq("1c#{bike.primary_frame_color_id}")
      bike.cached_attributes[1].should eq("1c#{color.id}")
      bike.cached_attributes[2].should eq("h#{handlebar.id}")
      bike.cached_attributes[3].should eq("1w#{bike.rear_wheel_size_id}")
      bike.cached_attributes[4].should eq("1w#{wheel.id}")
    end
  end

  describe :cache_stolen_attributes do 
    it "saves the stolen description to all description and set stolen_rec_id" do 
      stolen_record = FactoryGirl.create(:stolen_record, theft_description: 'some theft description' )
      bike = stolen_record.bike
      bike.description = 'I love my bike'
      bike.cache_stolen_attributes
      bike.all_description.should eq('I love my bike some theft description')
    end
    it "grabs the desc and erase current_stolen_id" do 
      bike = Bike.new(current_stolen_record_id: 69, description: 'lalalala')
      bike.cache_stolen_attributes
      bike.current_stolen_record_id.should_not be_present
      bike.all_description.should eq('lalalala')
    end
  end


  describe :cache_bike do 
    it "calls cache photo and cache component and erase stolen_rec_id" do 
      bike = FactoryGirl.create(:bike, current_stolen_record_id: 69)
      bike.should_receive(:cache_photo)
      bike.should_receive(:cache_stolen_attributes)
      bike.should_receive(:cache_attributes)
      bike.should_receive(:components_cache_string)
      bike.cache_bike
      bike.current_stolen_record_id.should be_nil
    end
    it "caches all the bike parts" do 
      type = FactoryGirl.create(:cycle_type, name: "Unicycle")
      handlebar = FactoryGirl.create(:handlebar_type)
      material = FactoryGirl.create(:frame_material)
      propulsion = FactoryGirl.create(:propulsion_type, name: "Hand pedaled")
      b = FactoryGirl.create(:bike, cycle_type: type, propulsion_type_id: propulsion.id)
      s = FactoryGirl.create(:stolen_record, bike: b)
      b.update_attributes( year: 1999, frame_material_id: material.id,
        secondary_frame_color_id: b.primary_frame_color_id,
        tertiary_frame_color_id: b.primary_frame_color_id,
        stolen: true,
        frame_size: "56", frame_size_unit: "ballsacks",
        frame_model: "Some model", handlebar_type_id: handlebar.id)
      b.cache_bike
      b.cached_data.should eq("#{b.manufacturer_name} Hand pedaled 1999 #{b.primary_frame_color.name} #{b.secondary_frame_color.name} #{b.tertiary_frame_color.name} #{material.name} 56ballsacks #{b.frame_model} #{b.rear_wheel_size.name} wheel  unicycle ")
      b.current_stolen_record_id.should eq(s.id)
    end
    it "has before_save_callback_method defined as a before_save callback" do
      Bike._save_callbacks.select { |cb| cb.kind.eql?(:before) }.map(&:raw_filter).include?(:cache_bike).should == true
    end
  end


  describe :frame_colors do 
    it "returns an array of the frame colors" do 
      bike = Bike.new 
      color = Color.new
      color2 = Color.new
      color.stub(:name).and_return('Blue')
      color2.stub(:name).and_return('Black')
      bike.stub(:primary_frame_color).and_return(color)
      bike.stub(:secondary_frame_color).and_return(color2)
      bike.stub(:tertiary_frame_color).and_return(color)
      bike.frame_colors.should eq(['Blue', 'Black', 'Blue'])
    end
  end

  describe :cgroup_array do
    it "grabs a list of all the cgroups" do 
      bike = Bike.new
      component1 = Component.new 
      component2 = Component.new 
      component3 = Component.new 
      bike.stub_chain(:components).and_return([component1, component2, component3])
      component1.stub(:cgroup_id).and_return(1)
      component2.stub(:cgroup_id).and_return(2)
      component3.stub(:cgroup_id).and_return(2)
      bike.cgroup_array.should eq([1,2])
    end
  end

  describe :get_listing_order do 
    it "is 1/1000 of the current timestamp" do 
      bike = Bike.new
      time = Time.now
      bike.stub(:updated_at).and_return(time)
      lo = bike.get_listing_order
      lo.should eq(time.to_time.to_i/1000000)
    end
    
    it "is the current stolen record date stolen * 1000" do 
      bike = Bike.new
      bike.stub(:stolen).and_return(true)
      stolen_record = StolenRecord.new 
      yesterday = Time.now - 1.days
      stolen_record.stub(:date_stolen).and_return(yesterday)
      bike.stub(:current_stolen_record).and_return(stolen_record)
      lo = bike.get_listing_order
      lo.should eq(yesterday.to_time.to_i)
    end

    it "is the updated_at" do 
      bike = Bike.new
      last_week = Time.now - 7.days
      bike.stub(:updated_at).and_return(last_week)
      bike.stub(:stock_photo_url).and_return('https://some_photo.cum')
      lo = bike.get_listing_order
      lo.should eq(last_week.to_time.to_i/10000)
    end

    it "does not get out of integer errors" do
      stolen_record = FactoryGirl.create(:stolen_record)
      bike = stolen_record.bike
      problem_date = Date.strptime("07-22-0014", "%m-%d-%Y")
      bike.update_attribute :stolen, true
      stolen_record.update_attribute :date_stolen, problem_date
      bike.update_attribute :listing_order, bike.get_listing_order
      bike.listing_order.should be > (Time.now - 1.year).to_time.to_i
    end
  end

  describe :title_string do 
    it "escapes correctly" do
      bike = Bike.new(frame_model: "</title><svg/onload=alert(document.cookie)>")
      bike.stub(:manufacturer_name).and_return('baller')
      bike.stub(:type).and_return('bike')
      bike.title_string.should_not match('</title><svg/onload=alert(document.cookie)>')
      bike.title_string.length.should be > 5
    end
  end
  
end
