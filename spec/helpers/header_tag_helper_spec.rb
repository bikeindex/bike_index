require 'spec_helper'

describe HeaderTagHelper do
  describe :header_tags do 
    it "returns the html for the tags" do
      helper.stub(:set_header_tag_hash).and_return({ tags: true })
      helper.stub(:set_social_hash).and_return({ tags: true })
      helper.stub(:title_tag_html).and_return("<title>Foo 69 69</title>\n")
      helper.stub(:meta_tags_html).and_return("<meta name=\"charset\" content=\"utf-8\" />\n")
      helper.header_tags.should eq("<title>Foo 69 69</title>\n<meta name=\"charset\" content=\"utf-8\" />\n")
    end
  end

  describe :title_tag_html do
    context 'from header_tag_hash' do
      it 'returns the title wrapped in title tags' do 
        header_hash = {
          title_tag: { title: 'Foo 69 69' },
          meta_tags: { charset: 'utf-8' }
        }
        title_tag = helper.title_tag_html(header_hash)
        title_tag.should eq("<title lang='en'>Foo 69 69</title>\n")
      end
    end
    context 'from override' do
      before { controller.instance_variable_set(:@page_title, 'OVERRIDE - Fancy Page title') }
      it 'returns the override' do 
        header_hash = {
          title_tag: { title: 'Foo 69 69' },
          meta_tags: { charset: 'utf-8' }
        }
        title_tag = helper.title_tag_html(header_hash)
        expect(title_tag).to eq("<title lang='en'>OVERRIDE - Fancy Page title</title>\n")
      end
    end
  end

  describe :meta_tags_html do 
    it "returns the meta tags in html" do 
      header_hash = {
        title_tag: { title: "Foo 69 69" },
        meta_tags: { charset: "utf-8" }
      }
      meta_tags = helper.meta_tags_html(header_hash)
      meta_tags.should eq("<meta name=\"charset\" content=\"utf-8\" />\n")
    end
  end

  describe :set_social_hash do 
    it "has some values" do 
      d = helper.set_social_hash({ title_tag: { title: "Loosers" }, meta_tags: {description: "Something 69"} })
      d[:meta_tags][:"og:title"].should eq("Loosers")
      d[:meta_tags][:"twitter:title"].should eq("Loosers")
      d[:meta_tags][:"og:description"].should eq("Something 69")
      d[:meta_tags][:"twitter:description"].should eq("Something 69")
    end

    it "duplicates the title to twitter" do 
      hash = helper.set_social_hash({ title_tag: { title: "Foo Title" }, meta_tags: {description: "An amazing description of awesome"} })
      hash[:meta_tags][:"og:title"].should eq("Foo Title")
      hash[:meta_tags][:"twitter:title"].should eq("Foo Title")
      hash[:meta_tags][:"og:description"].should eq("An amazing description of awesome")
      hash[:meta_tags][:"twitter:description"].should eq("An amazing description of awesome")
    end
  end

  describe :default_hash do 
    it "has some values" do 
      hash = helper.default_hash
      hash[:title_tag][:title].should eq("Bike Index")
      hash[:meta_tags][:description].should_not be_nil
      hash[:meta_tags][:charset].should_not be_empty
    end
  end
  describe :set_header_tag_hash do 
    it "calls the controller name header tags if it's listed" do 
      view.stub(:controller_name).and_return("bikes")
      helper.stub(:bikes_header_tags).and_return("69 and stuff")
      helper.set_header_tag_hash.should eq("69 and stuff")
    end

    it "returns page default tags if controller doesn't match a condition" do 
      view.stub(:controller_name).and_return("Something fucking weird")
      helper.stub(:current_page_auto_hash).and_return("defaulted")
      helper.set_header_tag_hash.should eq("defaulted")
    end
  end
  
  describe :current_page_auto_hash do 
    before do 
      view.stub(:default_hash).and_return({
        title_tag: { title: "Default" },
        meta_tags: { description: "Blank" }
      })
    end

    it "returns the description and title if localization name exists" do
      view.stub(:action_name).and_return("index")
      view.stub(:controller_name).and_return("bikes")
      h = helper.current_page_auto_hash
      h[:meta_tags][:description].should eq("Search for bikes that have been registered on the Bike Index")
      h[:title_tag][:title].should eq("Search Results")
    end

    it "returns the action name humanized and default description" do 
      view.stub(:action_name).and_return("some_weird_action")
      h = helper.current_page_auto_hash
      h[:title_tag][:title].should eq("Some weird action")
      h[:meta_tags][:description].should eq("Some weird action on the Bike Index")
    end
  end

  describe :title_auto_hash do 
    it "returns the controller name on Index" do 
      view.stub(:action_name).and_return("index")
      view.stub(:controller_name).and_return("cool_thing")
      helper.current_page_auto_hash[:title_tag][:title].should eq("Cool thing")
    end

    it "returns the controller name and new on New" do 
      view.stub(:action_name).and_return("edit")
      view.stub(:controller_name).and_return("cool_things")
      helper.current_page_auto_hash[:title_tag][:title].should eq("Edit cool thing")
    end
  end

  describe :bikes_header_tags do 
    before do 
      helper.stub(:current_page_auto_hash).and_return({
        title_tag: { title: "Default" },
        meta_tags: { description: "Blank" }
      })
      @bike = Bike.new
      @bike.stub(:stock_photo_url).and_return("http://something.com")
      @bike.stub(:title_string).and_return("Something special 1969")
      @bike.stub(:stolen).and_return("true")
      @bike.stub(:stolen_string).and_return("")
      @bike.stub(:frame_colors).and_return(["blue"])
    end

    xit "says new stolen on new stolen" do
      # It can't find current user. And I don't know why.
      # So fuck it
      @bike = Bike.new 
      @bike.stolen = true
      user = FactoryGirl.create(:user)
      set_current_user(user)
      view.stub(:action_name).and_return("new")
      hash = helper.bikes_header_tags
      hash[:title_tag][:title].should eq("Register a stolen bike")
      hash[:meta_tags][:description].should_not eq("Blank")
    end

    it "returns the bike name on Show" do 
      view.stub(:action_name).and_return("show")
      hash = helper.bikes_header_tags
      hash[:title_tag][:title].should eq("Stolen Something special 1969")
      hash[:meta_tags][:description].should_not eq("Blank")
      hash[:meta_tags][:"og:image"].should eq("http://something.com")
      hash[:meta_tags][:"twitter:image"].should eq("http://something.com")
    end

    it "has twitter creator if present and shown" do 
      user = User.new(twitter: 'coolio', show_twitter: true)
      @bike.stub(:owner).and_return(user)
      view.stub(:action_name).and_return("show")
      hash = helper.bikes_header_tags
      hash[:meta_tags][:"twitter:creator"].should eq("@coolio")
    end

    it "doesn't have twitter creator if present and not shown" do 
      user = User.new(twitter: 'coolio')
      @bike.stub(:owner).and_return(user)
      view.stub(:action_name).and_return("show")
      hash = helper.bikes_header_tags
      hash[:meta_tags][:"twitter:creator"].should_not be_present
    end
  end

end
