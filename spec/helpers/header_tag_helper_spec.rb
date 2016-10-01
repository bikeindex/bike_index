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
      describe 'landing' do
        let(:controller_name) { 'landing' }
        let(:action_name) { 'show' }
        it 'returns translation title' do
          expect(helper.auto_title).to eq 'Sweet Bike Org Bike Registration'
        end
      end
    end
  end

  describe 'auto_description' do
    context 'existing meta description translation' do
      let(:controller_name) { 'manufacturers' }
      let(:action_name) { 'index' }
      let(:target) { 'Bicycle related manufacturers listed on the Bike Index - all the brands you know and then some.' }
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
      ['og:description', 'twitter:description', 'og:title', 'twitter:title', 'og:url',
       'og:image', 'og:site_name', 'twitter:card', 'twitter:creator', 'twitter:site']
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

  # describe 'header_tags' do
  #   it 'returns the html for the tags' do
  #     allow(helper).to receive(:set_header_tag_hash).and_return(tags: true)
  #     allow(helper).to receive(:set_social_hash).and_return(tags: true)
  #     allow(helper).to receive(:title_tag_html).and_return("<title>Foo 69 69</title>\n")
  #     allow(helper).to receive(:meta_tags_html).and_return("<meta name=\"charset\" content=\"utf-8\" />\n")
  #     expect(helper.header_tags).to eq("<title>Foo 69 69</title>\n<meta name=\"charset\" content=\"utf-8\" />\n")
  #   end
  # end

  # describe 'title_tag_html' do
  #   context 'from header_tag_hash' do
  #     it 'returns the title wrapped in title tags' do
  #       header_hash = {
  #         title_tag: { title: 'Foo 69 69' },
  #         meta_tags: { charset: 'utf-8' }
  #       }
  #       title_tag = helper.title_tag_html(header_hash)
  #       expect(title_tag).to eq("<title lang='en'>Foo 69 69</title>\n")
  #     end
  #   end
  #   context 'from override' do
  #     before { controller.instance_variable_set(:@page_title, 'OVERRIDE - Fancy Page title') }
  #     it 'returns the override' do
  #       header_hash = {
  #         title_tag: { title: 'Foo 69 69' },
  #         meta_tags: { charset: 'utf-8' }
  #       }
  #       title_tag = helper.title_tag_html(header_hash)
  #       expect(title_tag).to eq("<title lang='en'>OVERRIDE - Fancy Page title</title>\n")
  #     end
  #   end
  # end

  # describe 'meta_tags_html' do
  #   it 'returns the meta tags in html' do
  #     header_hash = {
  #       title_tag: { title: 'Foo 69 69' },
  #       meta_tags: { charset: 'utf-8' }
  #     }
  #     meta_tags = helper.meta_tags_html(header_hash)
  #     expect(meta_tags).to eq("<meta name=\"charset\" content=\"utf-8\" />\n")
  #   end
  # end

  # describe 'set_social_hash' do
  #   it 'has some values' do
  #     d = helper.set_social_hash(title_tag: { title: 'Loosers' }, meta_tags: { description: 'Something 69' })
  #     expect(d[:meta_tags][:"og:title"]).to eq('Loosers')
  #     expect(d[:meta_tags][:"twitter:title"]).to eq('Loosers')
  #     expect(d[:meta_tags][:"og:description"]).to eq('Something 69')
  #     expect(d[:meta_tags][:"twitter:description"]).to eq('Something 69')
  #   end

  #   it 'duplicates the title to twitter' do
  #     hash = helper.set_social_hash({ title_tag: { title: 'Foo Title' }, meta_tags: { description: 'An amazing description of awesome' } })
  #     expect(hash[:meta_tags][:"og:title"]).to eq('Foo Title')
  #     expect(hash[:meta_tags][:"twitter:title"]).to eq('Foo Title')
  #     expect(hash[:meta_tags][:"og:description"]).to eq('An amazing description of awesome')
  #     expect(hash[:meta_tags][:"twitter:description"]).to eq('An amazing description of awesome')
  #   end
  # end

  # describe 'default_hash' do
  #   it 'has some values' do
  #     hash = helper.default_hash
  #     expect(hash[:title_tag][:title]).to eq('Bike Index')
  #     expect(hash[:meta_tags][:description]).not_to be_nil
  #     expect(hash[:meta_tags][:charset]).not_to be_empty
  #     expect(hash[:meta_tags][:'og:image']).to eq '/bike_index.png'
  #   end
  # end
  # describe 'set_header_tag_hash' do
  #   it "calls the controller name header tags if it's listed" do
  #     allow(view).to receive(:controller_name).and_return('bikes')
  #     allow(helper).to receive(:bikes_header_tags).and_return('69 and stuff')
  #     expect(helper.set_header_tag_hash).to eq('69 and stuff')
  #   end

  #   it "returns page default tags if controller doesn't match a condition" do
  #     allow(view).to receive(:controller_name).and_return('Something fucking weird')
  #     allow(helper).to receive(:current_page_auto_hash).and_return('defaulted')
  #     expect(helper.set_header_tag_hash).to eq('defaulted')
  #   end
  # end

  # describe 'current_page_auto_hash' do
  #   before do
  #     allow(view).to receive(:default_hash).and_return(title_tag: { title: 'Default' },
  #                                                      meta_tags: { description: 'Blank' })
  #   end

  #   it 'returns the description and title if localization name exists' do
  #     allow(view).to receive(:action_name).and_return('index')
  #     allow(view).to receive(:controller_name).and_return('bikes')
  #     h = helper.current_page_auto_hash
  #     expect(h[:meta_tags][:description]).to eq('Search for bikes that have been registered on the Bike Index')
  #     expect(h[:title_tag][:title]).to eq('Search Results')
  #   end

  #   it 'returns the action name humanized and default description' do
  #     allow(view).to receive(:action_name).and_return('some_weird_action')
  #     h = helper.current_page_auto_hash
  #     expect(h[:title_tag][:title]).to eq('Some weird action')
  #     expect(h[:meta_tags][:description]).to eq('Some weird action on the Bike Index')
  #   end
  # end

  # describe 'title_auto_hash' do
  #   it 'returns the controller name on Index' do
  #     allow(view).to receive(:action_name).and_return('index')
  #     allow(view).to receive(:controller_name).and_return('cool_thing')
  #     expect(helper.current_page_auto_hash[:title_tag][:title]).to eq('Cool thing')
  #   end

  #   it 'returns the controller name and new on New' do
  #     allow(view).to receive(:action_name).and_return('edit')
  #     allow(view).to receive(:controller_name).and_return('cool_things')
  #     expect(helper.current_page_auto_hash[:title_tag][:title]).to eq('Edit cool thing')
  #   end
  # end

  # describe 'bikes_header_tags' do
  #   before do
  #     allow(helper).to receive(:current_page_auto_hash).and_return(title_tag: { title: 'Default' },
  #                                                                  meta_tags: { description: 'Blank' })
  #     @bike = Bike.new
  #     allow(@bike).to receive(:stock_photo_url).and_return('http://something.com')
  #     allow(@bike).to receive(:title_string).and_return('Something special 1969')
  #     allow(@bike).to receive(:stolen).and_return('true')
  #     allow(@bike).to receive(:stolen_string).and_return('')
  #     allow(@bike).to receive(:frame_colors).and_return(['blue'])
  #   end

  #   xit 'says new stolen on new stolen' do
  #     # It can't find current user. And I don't know why.
  #     # So fuck it
  #     @bike = Bike.new
  #     @bike.stolen = true
  #     user = FactoryGirl.create(:user)
  #     set_current_user(user)
  #     allow(view).to receive(:action_name).and_return('new')
  #     hash = helper.bikes_header_tags
  #     expect(hash[:title_tag][:title]).to eq('Register a stolen bike')
  #     expect(hash[:meta_tags][:description]).not_to eq('Blank')
  #   end

  #   it 'returns the bike name on Show' do
  #     allow(view).to receive(:action_name).and_return('show')
  #     hash = helper.bikes_header_tags
  #     expect(hash[:title_tag][:title]).to eq('Stolen Something special 1969')
  #     expect(hash[:meta_tags][:description]).not_to eq('Blank')
  #     expect(hash[:meta_tags][:"og:image"]).to eq('http://something.com')
  #     expect(hash[:meta_tags][:"twitter:image"]).to eq('http://something.com')
  #   end

  #   it 'has twitter creator if present and shown' do
  #     user = User.new(twitter: 'coolio', show_twitter: true)
  #     allow(@bike).to receive(:owner).and_return(user)
  #     allow(view).to receive(:action_name).and_return('show')
  #     hash = helper.bikes_header_tags
  #     expect(hash[:meta_tags][:"twitter:creator"]).to eq('@coolio')
  #   end

  #   it "doesn't have twitter creator if present and not shown" do
  #     user = User.new(twitter: 'coolio')
  #     allow(@bike).to receive(:owner).and_return(user)
  #     allow(view).to receive(:action_name).and_return('show')
  #     hash = helper.bikes_header_tags
  #     expect(hash[:meta_tags][:"twitter:creator"]).not_to be_present
  #   end
  # end
end
