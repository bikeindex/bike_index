require 'spec_helper'

describe HeaderTagHelper do
  before do
    allow(view).to receive(:controller_name) { controller_name }
    allow(view).to receive(:action_name) { action_name }
    allow(view).to receive(:request_url) { '' }
    # These two methods are defined in application controller
    allow(view).to receive(:controller_namespace) { controller_namespace }
    allow(view).to receive(:page_id) { [controller_namespace, controller_name, action_name].compact.join('_') }
  end
  let(:controller_namespace) { nil }

  describe 'header_tags' do
    %w(bikes welcome news users landing_pages).each do |controller_name|
      context controller_name do
        let(:controller_name) { controller_name }
        it 'calls special_controller name' do
          expect(helper).to receive("#{controller_name}_header_tags".to_sym) { ['tags'] }
          expect(helper.header_tags).to eq 'tags'
        end
      end
    end
    context 'non-special controller' do
      let(:controller_name) { 'standard_names' }
      it 'returns default' do
        expect(helper).to receive(:default_header_tag_array) { %w(title description) }
        expect(helper.header_tags).to eq "title\ndescription"
      end
    end
  end

  describe 'page_title=' do
    it 'sets page_title with strip_tags' do
      helper.page_title = '<script>alert();</script> title <em>stuff</em>'
      expect(helper.page_title).to eq 'title stuff'
    end
  end

  describe 'page_description=' do
    it 'sets page_description with strip_tags' do
      helper.page_description = '<script>alert();</script> description <em>stuff</em>'
      expect(helper.page_description).to eq 'description stuff'
    end
  end

  describe 'auto_title' do
    context 'Assigned title from translation (users new)' do
      let(:controller_name) { 'users' }
      let(:action_name) { 'new' }
      it 'returns the translation title' do
        expect(helper.auto_title).to eq 'Sign up - Bike Index'
      end
    end
    context 'rendering from controller and action name' do
      let(:controller_name) { 'cool_things' }
      context 'index action' do
        let(:action_name) { 'index' }
        it 'returns the humanized, titleized controller_name' do
          expect(helper.auto_title).to eq 'Cool things'
        end
      end
      context 'new' do
        let(:action_name) { 'new' }
        it 'returns compiled title' do
          expect(helper.auto_title).to eq 'New cool thing'
        end
      end
      context 'edit' do
        let(:action_name) { 'edit' }
        it 'returns compiled title' do
          expect(helper.auto_title).to eq 'Edit cool thing'
        end
      end
      context 'show' do
        let(:action_name) { 'show' }
        it 'returns compiled title' do
          expect(helper.auto_title).to eq 'View cool thing'
        end
      end
      context 'create' do
        let(:action_name) { 'create' }
        it 'returns compiled title' do
          expect(helper.auto_title).to eq 'Created cool thing'
        end
      end
    end
    context 'unknown action_name' do
      let(:controller_name) { 'organizations' }
      let(:action_name) { 'lightspeed_integration' }
      it 'returns the weird action name humanized' do
        expect(helper.auto_title).to eq 'Lightspeed integration'
      end
    end
    context 'admin namespace' do
      let(:controller_namespace) { 'admin' }
      describe 'bikes' do
        let(:controller_name) { 'bikes' }
        let(:action_name) { 'index' }
        it 'returns prepended title' do
          expect(helper.auto_title).to eq 'Admin | Bikes'
        end
      end
    end
    context 'organized namespace' do
      let(:controller_namespace) { 'organized' }
      let(:organization) { FactoryGirl.build(:organization, short_name: 'Sweet Bike Org') }
      before do
        allow(view).to receive(:current_organization) { organization }
      end
      describe 'bikes' do
        let(:controller_name) { 'bikes' }
        let(:action_name) { 'index' }
        it 'returns title prepended with org name' do
          expect(helper.auto_title).to eq 'Sweet Bike Org Bikes'
        end
      end
    end
  end

  describe 'auto_description' do
    context 'existing meta description translation' do
      let(:controller_name) { 'manufacturers' }
      let(:action_name) { 'index' }
      let(:target) { 'Bicycle related manufacturers listed on Bike Index - all the brands you know and then some.' }
      it 'returns the translation' do
        expect(helper.auto_description).to eq target
      end
    end
    context 'no translation present' do
      let(:controller_name) { 'weird_things' }
      let(:action_name) { 'index' }
      let(:target) { 'The best bike registry: Simple, secure and free.' }
      it 'returns the default title' do
        expect(helper.auto_description).to eq target
      end
    end
  end

  describe 'social_meta_tags' do
    let(:meta_keys) do
      ['og:description', 'twitter:description', 'og:title', 'twitter:title', 'og:url', 'og:image',
       'og:site_name', 'twitter:card', 'fb:app_id', 'twitter:creator', 'twitter:site']
    end
    describe 'default_social_meta_hash' do
      let(:title_keys) { ['og:title', 'twitter:title'] }
      let(:description_keys) { ['og:description', 'twitter:description'] }
      let(:title) { 'SWeet TITLE bro' }
      let(:description) { 'A description that is just the right thing for everyone' }
      context 'passed description and title' do
        it 'uses passed title and description' do
          helper.instance_variable_set(:@page_title, title)
          helper.instance_variable_set(:@page_description, description)
          result = helper.default_meta_hash
          meta_keys.each { |key| expect(result[key]).to be_present }
          title_keys.each { |key| expect(result[key]).to eq title }
          description_keys.each { |key| expect(result[key]).to eq description }
        end
      end
      context 'no description or title passed' do
        it 'uses auto_title and auto_description' do
          expect(helper).to receive(:auto_title) { title }
          expect(helper).to receive(:auto_description) { description }
          result = helper.default_meta_hash
          meta_keys.each { |key| expect(result[key]).to be_present }
          title_keys.each { |key| expect(result[key]).to eq title }
          description_keys.each { |key| expect(result[key]).to eq description }
        end
      end
    end
    describe 'meta_hash_html_tags' do
      it 'returns content_tags_for each one' do
        helper.instance_variable_set(:@page_title, 'Stuff')
        helper.instance_variable_set(:@page_description, 'Description')
        result = helper.social_meta_content_tags(helper.default_meta_hash).join("\n")
        meta_keys.each do |k|
          expect(result.include?("property=\"#{k}\"")).to be_truthy
        end
      end
    end
  end

  describe 'main_header_tags' do
    let(:title) { 'A really, really sweet title' }
    let(:description) { 'Some lame description' }
    let(:target) do
      [
        '<meta charset="utf-8" />',
        '<meta http-equiv="Content-Language" content="en" />',
        '<meta http-equiv="X-UA-Compatible" content="IE=edge" />',
        '<meta name="viewport" content="width=device-width" />',
        "<title>#{title}</title>",
        "<meta name=\"description\" content=\"#{description}\" />",
        '<link rel="shortcut icon" href="/fav.ico" />',
        '<link rel="apple-touch-icon-precomposed apple-touch-icon" href="/apple_touch_icon.png" />',
        nil # csrf_meta_tags is nil in test
      ]
    end
    it 'returns main tags' do
      helper.instance_variable_set(:@page_title, title)
      helper.instance_variable_set(:@page_description, description)
      expect(helper.main_header_tags).to eq target
    end
  end

  describe 'landing_pages_header_tags' do
    let(:action_name) { 'show' }
    let(:controller_name) { 'landing_pages' }
    let(:organization) { FactoryGirl.build(:organization, name: 'Sweet University') }
    it 'sets the page title' do
      allow(view).to receive(:current_organization) { organization }
      helper.landing_pages_header_tags
      expect(helper.page_title).to eq 'Sweet University Bike Registration'
      expect(helper.page_description).to eq 'Register your bicycle with Sweet University - powered by Bike Index'
    end
  end

  describe 'welcome_header_tags' do
    context 'user_home' do
      let(:action_name) { 'user_home' }
      context 'nil current_user name' do
        it 'sets the page title' do
          allow(view).to receive(:current_user) { nil }
          helper.welcome_header_tags
          expect(helper.page_title).to eq 'Your bikes'
        end
      end
      context 'current_user name' do
        let(:user) { FactoryGirl.build(:user, name: 'John') }
        it 'sets the page title' do
          allow(view).to receive(:current_user) { user }
          helper.welcome_header_tags
          expect(helper.page_title).to eq 'John on Bike Index'
        end
      end
    end
    context 'choose_registration' do
      let(:action_name) { 'choose_registration' }
      it 'sets the page title' do
        helper.welcome_header_tags
        expect(helper.page_title).to eq 'Register a bike!'
        expect(helper.page_description).to eq 'Register a bike on Bike Index quickly, easily and for free. Create a permanent verified record of your bike to protect it.'
      end
    end
  end

  describe 'users_header_tags' do
    let(:avatar) { AvatarUploader.new }
    let(:controller_name) { 'users' }
    let(:action_name) { 'show' }
    context 'with user title, and avatar' do
      let(:user) { FactoryGirl.build(:user, name: 'John', title: "John's bikes") }
      it 'returns the user avatar, title and titled description' do
        allow(avatar).to receive(:url) { 'http://something.com' }
        allow(user).to receive(:avatar) { avatar }
        @user = user
        helper.users_header_tags
        expect(helper.page_title).to eq "John's bikes"
        expect(helper.page_description).to eq "John's bikes on Bike Index"
        expect(helper.page_image).to eq 'http://something.com'
      end
    end
    context 'with no user title and blank avatar' do
      let(:user) { FactoryGirl.build(:user, name: 'John') }
      it 'has default image and a title' do
        allow(avatar).to receive(:url) { 'https://files.bikeindex.org/blank.png' }
        allow(user).to receive(:avatar) { avatar }
        @user = user
        helper.users_header_tags
        expect(helper.page_title).to eq 'View user'
        expect(helper.page_image).to eq '/bike_index.png'
      end
    end
  end

  describe 'bikes_header_tags' do
    let(:bike) { Bike.new(stolen: true) }
    context 'new stolen bike' do
      let(:user) { FactoryGirl.build(:user) }
      it 'says new stolen on new stolen' do
        allow(view).to receive(:current_user).and_return(user)
        allow(view).to receive(:action_name).and_return('new')
        @bike = bike # So that it's assigned in the helper
        helper.bikes_header_tags
        expect(helper.page_title).to eq 'Register a stolen bike'
        expect(helper.page_description).to_not eq 'Blank'
      end
    end
    describe 'show' do
      let(:action_name) { 'show' }
      before { allow(bike).to receive(:title_string) { 'Something special 1969' } }
      context 'default' do
        it 'returns the bike name on Show' do
          allow(bike).to receive(:stock_photo_url) { 'http://something.com' }
          @bike = bike # So that it's assigned in the helper
          header_tags = helper.bikes_header_tags
          expect(helper.page_title).to eq 'Stolen Something special 1969'
          expect(helper.page_description).not_to eq 'Blank'
          og_image = header_tags.select { |t| t && t[/og.image/] }.first
          twitter_image = header_tags.select { |t| t && t.include?('twitter:image') }.first
          expect(og_image.include?('http://something.com')).to be_truthy
          expect(twitter_image.include?('http://something.com')).to be_truthy
          expect(header_tags.select { |t| t && t.include?('twitter:card') }.first).to match 'summary_large_image'
        end
      end
      context 'twitter present and shown' do
        it 'has twitter creator if present and shown' do
          user = User.new(twitter: 'coolio', show_twitter: true)
          allow(bike).to receive(:owner).and_return(user)
          @bike = bike # So that it's assigned in the helper
          header_tags = helper.bikes_header_tags
          expect(header_tags.select { |t| t && t.include?('twitter:creator') }.first).to match '@coolio'
        end
      end
      context 'twitter present and not shown' do
        it "doesn't include twitter creator" do
          user = User.new(twitter: 'coolio')
          allow(bike).to receive(:owner).and_return(user)
          @bike = bike # So that it's assigned in the helper
          header_tags = helper.bikes_header_tags
          expect(header_tags.select { |t| t && t.include?('twitter:creator') }.first).to match '@bikeindex'
        end
      end
    end
  end

  describe 'news_header_tags' do
    let(:controller_name) { 'news' }
    let(:auto_discovery_tag) { '<link rel="alternate" type="application/atom+xml" title="Bike Index news atom feed" href="http://test.host/news.atom" />' }
    describe 'index' do
      let(:action_name) { 'index' }
      it 'adds auto_discovery_link' do
        expect(helper.news_header_tags.last).to eq auto_discovery_tag
      end
    end
    describe 'show' do
      let(:action_name) { 'show' }
      let(:target_time) { (Time.now - 1.hour).utc }
      # Have to create user so it creates a path for the user
      let(:user) { FactoryGirl.create(:user, name: 'John', twitter: 'stolenbikereg') }
      let(:blog) do
        FactoryGirl.build(:blog,
                          title: 'Cool blog',
                          description_abbr: 'Bike Index did something cool',
                          published_at: target_time,
                          updated_at: target_time,
                          user: user)
      end
      let(:target_url) { 'http://something.com' }
      context 'index image present' do
        it 'adds the index image and the tags we want' do
          allow(blog).to receive(:index_image) { target_url }
          allow(blog).to receive(:index_image_lg) { target_url }
          @blog = blog
          header_tags = helper.news_header_tags
          expect(helper.page_title).to eq 'Cool blog'
          expect(helper.page_description).to eq 'Bike Index did something cool'
          expect(helper.page_image).to eq 'http://something.com'
          expect(header_tags.select { |t| t && t.include?('og:type') }.first).to match 'article'
          expect(header_tags.select { |t| t && t.include?('twitter:creator') }.first).to match '@stolenbikereg'
          expect(header_tags.select { |t| t && t.include?('og:published_time') }.first).to match target_time.to_s
          expect(header_tags.select { |t| t && t.include?('og:modified_time') }.first).to match target_time.to_s
          expect(header_tags.include?(auto_discovery_tag)).to be_truthy
          expect(header_tags.include?("<link rel=\"author\" href=\"#{user_url(user)}\" />")).to be_truthy
        end
      end
      context 'public_image present' do
        let(:public_image) { PublicImage.new }
        it 'adds the public image we want' do
          allow(public_image).to receive(:image_url) { target_url }
          allow(blog).to receive(:public_images) { [public_image] }
          allow(blog).to receive(:index_image_lg) { target_url }
          @blog = blog
          header_tags = helper.news_header_tags
          expect(helper.page_title).to eq 'Cool blog'
          expect(helper.page_image).to eq 'http://something.com'
          expect(header_tags.include?(auto_discovery_tag)).to be_truthy
          expect(header_tags.include?("<link rel=\"author\" href=\"#{user_url(user)}\" />")).to be_truthy
        end
      end
    end
  end
end
