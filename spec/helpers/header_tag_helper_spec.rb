require "rails_helper"

RSpec.describe HeaderTagHelper, type: :helper do
  before do
    helper.extend(ControllerHelpers)
    allow(view).to receive(:controller_name) { controller_name }
    allow(view).to receive(:action_name) { action_name }
    # These two methods are defined in application controller
    allow(view).to receive(:controller_namespace) { controller_namespace }
    allow(view).to receive(:page_id) { [controller_namespace, controller_name, action_name].compact.join("_") }
  end
  let(:controller_namespace) { nil }

  describe "header_tags" do
    %w[bikes welcome news my_accounts users landing_pages].each do |controller_name|
      context controller_name do
        let(:controller_name) { controller_name }
        it "calls special_controller name" do
          expect(helper.page_with_custom_header_tags?).to be_truthy
          expect(helper).to receive(:"#{controller_name}_header_tags") { ["tags"] }
          expect(helper.header_tags).to eq "tags"
        end
      end
    end
    context "non-special controller" do
      let(:controller_name) { "standard_names" }
      it "returns default" do
        expect(helper).to receive(:default_header_tag_array) { %w[title description] }
        expect(helper.header_tags).to eq "title\ndescription"
      end
    end
  end

  describe "page_title=" do
    it "sets page_title with strip_tags" do
      helper.page_title = "<script>alert();</script> title <em>stuff</em>"
      expect(helper.page_title).to eq "title stuff"
    end
    context "with organization with &" do
      # There are a lot of organizations with '&' in their name, so don't make it weird
      it "returns with just amp" do
        helper.page_title = "B&P Cycle and Sports bikes"
        expect(helper.page_title).to eq "B&P Cycle and Sports bikes"
      end
    end
  end

  describe "page_description=" do
    it "sets page_description with strip_tags" do
      helper.extend(ControllerHelpers)
      helper.page_description = "<script>alert();</script> description <em>stuff</em>"
      expect(helper.page_description).to eq "description stuff"
    end
  end

  describe "auto_title" do
    context "Assigned title from translation (users new)" do
      let(:controller_name) { "users" }
      let(:action_name) { "new" }
      it "returns the translation title" do
        expect(helper.auto_title).to eq "Sign up - Bike Index"
      end
    end
    context "rendering from controller and action name" do
      let(:controller_name) { "cool_things" }
      context "index action" do
        let(:action_name) { "index" }
        it "returns the humanized, titleized controller_name" do
          expect(helper.auto_title).to eq "Cool things"
        end
      end
      context "new" do
        let(:action_name) { "new" }
        it "returns compiled title" do
          expect(helper.auto_title).to eq "New cool thing"
        end
      end
      context "edit" do
        let(:action_name) { "edit" }
        it "returns compiled title" do
          expect(helper.auto_title).to eq "Edit cool thing"
        end
      end
      context "show" do
        let(:action_name) { "show" }
        it "returns compiled title" do
          expect(helper.auto_title).to eq "View cool thing"
        end
      end
      context "create" do
        let(:action_name) { "create" }
        it "returns compiled title" do
          expect(helper.auto_title).to eq "Created cool thing"
        end
      end
    end
    context "unknown action_name" do
      let(:controller_name) { "organizations" }
      let(:action_name) { "lightspeed_integration" }
      it "returns the weird action name humanized" do
        expect(helper.auto_title).to eq "Lightspeed integration"
      end
    end
    context "admin namespace" do
      let(:controller_namespace) { "admin" }
      describe "bikes" do
        let(:controller_name) { "bikes" }
        let(:action_name) { "index" }
        it "returns prepended title" do
          expect(helper.auto_title).to eq "🧰 Bikes"
        end
      end
    end
    context "organized namespace" do
      let(:controller_namespace) { "organized" }
      let(:organization) { FactoryBot.build(:organization, short_name: "Sweet Bike Org") }
      before do
        allow(view).to receive(:current_organization) { organization }
      end
      describe "bikes" do
        let(:controller_name) { "bikes" }
        let(:action_name) { "index" }
        it "returns title prepended with org name" do
          expect(helper.auto_title).to eq "Sweet Bike Org Bikes"
        end
      end
    end
  end

  describe "auto_description" do
    context "existing meta description translation" do
      let(:controller_name) { "manufacturers" }
      let(:action_name) { "index" }
      let(:target) { "Bicycle related manufacturers listed on Bike Index - all the brands you know and then some." }
      it "returns the translation" do
        expect(helper.auto_description).to eq target
      end
    end
    context "no translation present" do
      let(:controller_name) { "weird_things" }
      let(:action_name) { "index" }
      let(:target) { "The best bike registry: Simple, secure and free." }
      it "returns the default title" do
        expect(helper.auto_description).to eq target
      end
    end
  end

  describe "social_meta_tags" do
    let(:meta_keys) do
      ["og:description", "twitter:description", "og:title", "twitter:title", "og:url", "og:image",
        "og:site_name", "twitter:card", "fb:app_id", "twitter:creator", "twitter:site"]
    end
    describe "default_social_meta_hash" do
      let(:title_keys) { ["og:title", "twitter:title"] }
      let(:description_keys) { ["og:description", "twitter:description"] }
      let(:title) { "SWeet TITLE bro" }
      let(:description) { "A description that is just the right thing for everyone" }
      context "passed description and title" do
        it "uses passed title and description" do
          helper.instance_variable_set(:@page_title, title)
          helper.instance_variable_set(:@page_description, description)
          result = helper.default_meta_hash
          meta_keys.each { |key| expect(result[key]).to be_present }
          title_keys.each { |key| expect(result[key]).to eq title }
          description_keys.each { |key| expect(result[key]).to eq description }
        end
      end
      context "no description or title passed" do
        it "uses auto_title and auto_description" do
          expect(helper).to receive(:auto_title) { title }
          expect(helper).to receive(:auto_description) { description }
          result = helper.default_meta_hash
          meta_keys.each { |key| expect(result[key]).to be_present }
          title_keys.each { |key| expect(result[key]).to eq title }
          description_keys.each { |key| expect(result[key]).to eq description }
        end
      end
    end
    describe "meta_hash_html_tags" do
      it "returns content_tags_for each one" do
        helper.instance_variable_set(:@page_title, "Stuff")
        helper.instance_variable_set(:@page_description, "Description")
        result = helper.social_meta_content_tags(helper.default_meta_hash).join("\n")
        meta_keys.each do |k|
          expect(result.include?("property=\"#{k}\"")).to be_truthy
        end
      end
    end
  end

  describe "main_header_tags" do
    let(:title) { "A really, really sweet title" }
    let(:description) { "Some lame description" }
    let(:target) do
      [
        '<meta charset="utf-8" />',
        '<meta http-equiv="Content-Language" content="en" />',
        '<meta http-equiv="X-UA-Compatible" content="IE=edge" />',
        '<meta name="viewport" content="width=device-width" />',
        "<title>#{title}</title>",
        "<meta name=\"description\" content=\"#{description}\" />",
        '<link rel="shortcut icon" href="/fav.ico" />',
        '<link rel="apple-touch-icon-precomposed apple-touch-icon" href="/apple-touch-icon.png" />',
        nil # csrf_meta_tags is nil in test
      ]
    end
    it "returns main tags" do
      helper.instance_variable_set(:@page_title, title)
      helper.instance_variable_set(:@page_description, description)
      expect(helper.main_header_tags).to eq target
    end
  end

  describe "landing_pages_header_tags" do
    let(:controller_name) { "landing_pages" }
    context "show (organization landing page)" do
      let(:action_name) { "show" }
      let(:organization) { FactoryBot.build(:organization, name: "Sweet University") }
      it "sets the page title" do
        allow(view).to receive(:current_organization) { organization }
        helper.landing_pages_header_tags
        expect(helper.page_title).to eq "Sweet University Bike Registration"
        expect(helper.page_description).to eq "Register your bicycle with Sweet University - powered by Bike Index"
      end
    end
  end

  describe "my_accounts_header_tags" do
    context "show" do
      let(:action_name) { "show" }
      context "nil current_user name" do
        it "sets the page title" do
          allow(view).to receive(:current_user) { nil }
          helper.my_accounts_header_tags
          expect(helper.page_title).to eq "Your bikes"
        end
      end
      context "current_user name" do
        let(:user) { FactoryBot.build(:user, name: "John") }
        it "sets the page title" do
          allow(view).to receive(:current_user) { user }
          helper.my_accounts_header_tags
          expect(helper.page_title).to eq "John on Bike Index"
        end
      end
    end
  end

  describe "welcome_header_tags" do
    context "choose_registration" do
      let(:action_name) { "choose_registration" }
      it "sets the page title" do
        helper.welcome_header_tags
        expect(helper.page_title).to eq "Register a bike!"
        expect(helper.page_description).to eq "Register a bike on Bike Index quickly, easily and for free. Create a permanent verified record of your bike to protect it."
      end
    end
  end

  describe "users_header_tags" do
    let(:avatar) { AvatarUploader.new }
    let(:controller_name) { "users" }
    let(:action_name) { "show" }
    context "with user title, and avatar" do
      let(:user) { FactoryBot.build(:user, name: "John", title: "John's bikes") }
      it "returns the user avatar, title and titled description" do
        allow(avatar).to receive(:url) { "http://something.com" }
        allow(user).to receive(:avatar) { avatar }
        @user = user
        helper.users_header_tags
        expect(helper.page_title).to eq "John's bikes"
        expect(helper.page_description).to eq "John's bikes on Bike Index"
        expect(helper.page_image).to eq "http://something.com"
      end
    end
    context "with no user title and blank avatar" do
      let(:user) { FactoryBot.build(:user, name: "John") }
      it "has default image and a title" do
        allow(avatar).to receive(:url) { "https://files.bikeindex.org/blank.png" }
        allow(user).to receive(:avatar) { avatar }
        @user = user
        helper.users_header_tags
        expect(helper.page_title).to eq "View user"
        expect(helper.page_image).to eq "/bike_index.png"
      end
    end
  end

  describe "bikes_header_tags" do
    let(:bike) { Bike.new(status: "status_stolen") }
    context "new stolen bike" do
      let(:user) { FactoryBot.build(:user) }
      it "says new stolen on new stolen" do
        allow(view).to receive(:current_user).and_return(user)
        allow(view).to receive(:action_name).and_return("new")
        @bike = bike # So that it's assigned in the helper
        helper.bikes_header_tags
        expect(helper.page_title).to eq "Register a stolen bike"
        expect(helper.page_description).to_not eq "Blank"
      end
    end
    describe "show" do
      let(:action_name) { "show" }
      let(:bike) { FactoryBot.create(:bike, frame_model: "Something special", year: 1969, description: "Cool description") }
      let(:title_string) { "1969 #{bike.manufacturer.simple_name} Something special" }
      before { @bike = bike } # So it's assigned in the helper
      context "default" do
        it "returns the bike name on Show" do
          expect(bike.title_string).to eq title_string
          allow(bike).to receive(:stock_photo_url) { "http://something.com" }
          header_tags = helper.bikes_header_tags # Required to be called in here (can't be in a let)
          expect(helper.page_title).to eq title_string
          expect(helper.page_description).to eq "#{@bike.primary_frame_color.name} #{title_string}, serial: #{bike.serial_number.upcase}. Cool description."
          og_image = header_tags.find { |t| t && t[/og.image/] }
          twitter_image = header_tags.find { |t| t&.include?("twitter:image") }
          expect(og_image.include?("http://something.com")).to be_truthy
          expect(twitter_image.include?("http://something.com")).to be_truthy
          expect(header_tags.find { |t| t && t.include?("twitter:card") }).to match "summary_large_image"
        end
        context "stolen" do
          let(:bike) { FactoryBot.create(:stolen_bike_in_chicago) }
          let(:title_string) { bike.manufacturer.simple_name.to_s }
          let(:target_page_description) do
            "#{@bike.primary_frame_color.name} #{title_string}, serial: #{bike.serial_number.upcase}. " \
            "Stolen: #{Time.current.strftime("%Y-%m-%d")}, from: Chicago, IL 60608, US"
          end
          it "returns expected things" do
            expect(bike.reload.current_stolen_record.address).to eq "Chicago, IL 60608, US"
            expect(bike.title_string).to eq title_string
            header_tags = helper.bikes_header_tags
            expect(helper.page_title).to eq "Stolen #{title_string}"
            expect(helper.page_description).to eq target_page_description
            og_image = header_tags.find { |t| t && t[/og.image/] }
            twitter_image = header_tags.find { |t| t&.include?("twitter:image") }
            expect(og_image.include?("/bike_index.png")).to be_truthy
            expect(twitter_image.include?("/bike_index.png")).to be_truthy
            expect(header_tags.find { |t| t && t.include?("twitter:card") }).to match "summary"
          end
        end
        context "found" do
          let!(:impound_record) { FactoryBot.create(:impound_record, :in_nyc, bike: bike) }
          let(:target_page_description) do
            "#{@bike.primary_frame_color.name} #{title_string}, serial: Hidden. Cool description. " \
            "Found: #{Time.current.strftime("%Y-%m-%d")}, in: New York, NY 10007, US"
          end
          it "returns expected things" do
            expect(bike.reload.current_impound_record.address).to eq "New York, NY 10007"
            expect(bike.status_humanized).to eq "found"
            expect(bike.title_string).to eq title_string
            helper.bikes_header_tags
            expect(helper.page_title).to eq "Found #{title_string}"
            expect(helper.page_description).to eq target_page_description
          end
        end
        context "impounded" do
          let(:parking_notification) { FactoryBot.create(:parking_notification_organized, :in_edmonton, bike: bike, use_entered_address: true) }
          let(:organization) { parking_notification.organization }
          let(:impound_record) { FactoryBot.create(:impound_record_with_organization, bike: bike, parking_notification: parking_notification, organization: organization) }
          let(:target_page_description) do
            "#{@bike.primary_frame_color.name} #{title_string}, serial: Hidden. Cool description. " \
            "Impounded: #{Time.current.strftime("%Y-%m-%d")}, in: Edmonton, AB T6G 2B3, CA"
          end
          it "returns expected things" do
            expect(parking_notification.reload.address).to eq "9330 Groat Rd NW, Edmonton, AB T6G 2B3, CA"
            impound_record.reload
            expect(bike.reload.current_impound_record.address).to eq "Edmonton, AB T6G 2B3, CA"
            expect(bike.status_humanized).to eq "impounded"
            expect(bike.title_string).to eq title_string
            helper.bikes_header_tags
            expect(helper.page_title).to eq "Impounded #{title_string}"
            expect(helper.page_description).to eq target_page_description
          end
        end
      end
      context "twitter present and shown" do
        it "has twitter creator if present and shown" do
          user = User.new(twitter: "coolio", show_twitter: true)
          allow(bike).to receive(:owner).and_return(user)
          @bike = bike # So that it's assigned in the helper
          header_tags = helper.bikes_header_tags
          expect(header_tags.find { |t| t && t.include?("twitter:creator") }).to match "@coolio"
        end
      end
      context "twitter present and not shown" do
        it "doesn't include twitter creator" do
          user = User.new(twitter: "coolio")
          allow(bike).to receive(:owner).and_return(user)
          @bike = bike # So that it's assigned in the helper
          header_tags = helper.bikes_header_tags
          expect(header_tags.find { |t| t && t.include?("twitter:creator") }).to match "@bikeindex"
        end
      end
    end
    describe "bikes edit" do
      let(:controller_namespace) { "bikes" }
      let(:controller_name) { "edits" }
      let(:action_name) { "show" }
      it "includes bike edit tags" do
        @edit_templates = "stub"
        @edit_template = "theft_details"
        bike.mnfg_name = "Cool"
        bike.frame_model = "Party"
        @bike = bike # So it's assigned in the helper
        header_tags = helper.bikes_header_tags
        expect(header_tags.find { |t| t.include?("<title>") }).to eq("<title>Theft details - Cool Party</title>")
      end
    end
  end

  describe "news_header_tags" do
    let(:controller_name) { "news" }
    let(:auto_discovery_tag) { '<link rel="alternate" type="application/atom+xml" title="Bike Index news atom feed" href="http://test.host/news.atom" />' }
    describe "index" do
      let(:action_name) { "index" }
      it "adds auto_discovery_link" do
        expect(helper.news_header_tags.last).to eq auto_discovery_tag
      end
    end
    describe "show" do
      let(:action_name) { "show" }
      let(:target_time) { (Time.current - 1.hour).utc }
      # Have to create user so it creates a path for the user
      let(:user) { FactoryBot.create(:user, name: "John", twitter: "stolenbikereg") }
      let(:blog) do
        FactoryBot.build(:blog,
          title: "Cool blog",
          description_abbr: "Bike Index did something cool",
          published_at: target_time,
          updated_at: target_time,
          user: user,
          canonical_url: canonical_url)
      end
      let(:canonical_url) { nil }
      let(:target_url) { "http://something.com" }
      context "index image present" do
        before do
          blog.set_title_slug
          allow(blog).to receive(:index_image) { target_url }
          allow(blog).to receive(:index_image_lg) { target_url }
        end
        it "adds the index image and the tags we want" do
          blog.secondary_title = "Another title for cool stuff"
          @blog = blog
          expect(helper.page_with_custom_header_tags?).to be_truthy
          header_tags = helper.news_header_tags
          expect(helper.page_title).to eq "Cool blog"
          expect(helper.page_description).to eq "Bike Index did something cool"
          expect(helper.page_image).to eq "http://something.com"
          expect(header_tags.find { |t| t&.include?("og:type") }).to match "article"
          expect(header_tags.find { |t| t&.include?("twitter:creator") }).to match "@stolenbikereg"
          expect(header_tags.find { |t| t&.include?("og:published_time") }).to match target_time.to_s
          expect(header_tags.find { |t| t&.include?("og:modified_time") }).to match target_time.to_s
          expect(header_tags.find { |t| t&.include?("property=\"title\"") }).to match "Another title for cool stuff"
          expect(header_tags.include?(auto_discovery_tag)).to be_truthy
          expect(header_tags.include?("<link rel=\"author\" href=\"#{user_url(user)}\" />")).to be_truthy
          canonical_tag = "<link rel=\"canonical\" href=\"http://test.host/news/cool-blog\" />"
          expect(header_tags.find { |t| t&.include?("rel=\"canonical\"") }).to eq canonical_tag
        end
        context "canonical_url" do
          let(:canonical_url) { "https://somewhereelse.com" }
          it "doesn't include creator" do
            @blog = blog
            expect(helper.page_with_custom_header_tags?).to be_truthy
            header_tags = helper.news_header_tags
            expect(helper.page_title).to eq "Cool blog"
            expect(helper.page_description).to eq "Bike Index did something cool"
            expect(helper.page_image).to eq "http://something.com"
            expect(header_tags.find { |t| t&.include?("og:type") }).to match "article"
            expect(header_tags.find { |t| t&.include?("og:published_time") }).to match target_time.to_s
            expect(header_tags.find { |t| t&.include?("og:modified_time") }).to match target_time.to_s
            expect(header_tags.find { |t| t&.include?("og:modified_time") }).to match target_time.to_s
            expect(header_tags.include?(auto_discovery_tag)).to be_truthy
            expect(header_tags.find { |t| t&.include?("twitter:creator") }).to be_blank
            expect(header_tags.find { |t| t&.include?("<link rel=\"author\"") }).to be_blank
            expect(header_tags.include?("<link rel=\"canonical\" href=\"#{canonical_url}\" />")).to be_truthy
          end
        end
      end
      context "public_image present" do
        let(:public_image) { PublicImage.new }
        it "adds the public image we want" do
          blog.set_title_slug
          allow(public_image).to receive(:image_url) { target_url }
          allow(blog).to receive(:public_images) { [public_image] }
          allow(blog).to receive(:index_image_lg) { target_url }
          @blog = blog
          header_tags = helper.header_tag_array
          expect(helper.page_title).to eq "Cool blog"
          expect(helper.page_image).to eq "http://something.com"
          expect(header_tags.include?(auto_discovery_tag)).to be_truthy
          expect(header_tags.include?("<link rel=\"author\" href=\"#{user_url(user)}\" />")).to be_truthy
        end
      end
      describe "info post" do
        let(:controller_name) { "info" }
        it "returns the info tags" do
          blog.kind = "info"
          blog.created_at = target_time
          blog.set_title_slug
          allow(blog).to receive(:index_image) { target_url }
          allow(blog).to receive(:index_image_lg) { target_url }
          @blog = blog
          expect(helper.page_with_custom_header_tags?).to be_truthy
          header_tags = helper.header_tag_array
          expect(helper.page_title).to eq "Cool blog"
          expect(helper.page_description).to eq "Bike Index did something cool"
          expect(helper.page_image).to eq "http://something.com"
          expect(header_tags.find { |t| t && t.include?("og:type") }).to match "article"
          expect(header_tags.find { |t| t && t.include?("twitter:creator") }).to match "@bikeindex"
          expect(header_tags.find { |t| t && t.include?("og:published_time") }).to match target_time.to_s
          expect(header_tags.find { |t| t && t.include?("og:modified_time") }).to match target_time.to_s
          expect(header_tags.include?(auto_discovery_tag)).to be_falsey
          expect(header_tags.include?("<link rel=\"author\" href=\"#{user_url(user)}\" />")).to be_falsey
        end
      end
    end
  end

  describe "about" do
    let(:controller_name) { "info" }
    let(:action_name) { "about" }
    it "returns default about header tags" do
      # testing a non-show info page, to make sure we aren't doing custom header tags
      expect(helper.page_with_custom_header_tags?).to be_falsey
      helper.header_tag_array
      expect(helper.page_title).to eq "Bike Index - Bike registration that works"
      expect(helper.page_description).to eq "Why we made Bike Index and who we are"
    end
  end
end
