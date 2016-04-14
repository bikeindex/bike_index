require 'spec_helper'

describe ApplicationHelper do
  describe :active_link do
    context 'without a class' do
      it 'returns the link active if it ought to be' do
        view.stub(:current_page?).and_return(true)
        generated = '<a href="http://bikeindex.org" class=" active">Bike Index about</a>'
        expect(helper.active_link('Bike Index about', 'http://bikeindex.org')).to eq generated
      end
    end
    context 'match controller true' do
      let(:request) { double('request', url: new_bike_url) }
      before { allow(helper).to receive(:request).and_return(request) }
      it 'returns the link active if it is a bikes page' do
        generated = '<a href="' + new_bike_url + '" class="seeeeeeee active">Bike Index bikes page</a>'
        result = helper.active_link('Bike Index bikes page', new_bike_url, match_controller: true, class_name: 'seeeeeeee')
        expect(result).to eq generated
      end
    end
    context 'current with a class' do
      it 'returns the link active if it ought to be' do
        view.stub(:current_page?).and_return(true)
        generated = '<a href="http://bikeindex.org" class="nav-party-link active">Bike Index about</a>'
        result = helper.active_link('Bike Index about', 'http://bikeindex.org', class_name: 'nav-party-link')
        expect(result).to eq generated
      end
    end
    context 'organization_invitation' do
      it 'returns link, active if it ought to be' do
        view.stub(:controller_name).and_return('organization_invitations')
        generated = '<a href="/invitations" class="">Invitations</a>'
        helper.active_link('Invitations', '/invitations').should eq(generated)
      end
    end
  end

  describe :current_page_content_page? do
    it 'returns link, active if it ought to be' do
      view.stub(:controller_name).and_return('info')
      helper.current_page_content_page?.should be true
    end
  end

  describe 'content_page_type' do
    context 'info controller' do
      it 'returns info active_page' do
        view.stub(:controller_name).and_return('info')
        view.stub(:action_name).and_return('dev_and_design')
        expect(helper.content_page_type).to eq 'dev_and_design'
      end
    end
    context 'news controller' do
      it 'returns news index' do
        view.stub(:controller_name).and_return('news')
        view.stub(:action_name).and_return('index')
        expect(helper.content_page_type).to eq 'news'
      end
    end
    context 'bikes controller' do
      let(:request) { double('request', url: new_bike_url) }
      before { allow(helper).to receive(:request).and_return(request) }
      it 'returns nil for non-info pages' do
        expect(helper.content_page_type).to be_nil
      end
    end
  end

  describe :content_nav_class do
    it 'returns active if the section is the active_section' do
      @active_section = 'resources'
      helper.content_nav_class('resources').should eq('active-menu')
    end
  end

  describe :listicle_html do
    it 'returns the html formatted as we want' do
      l = Listicle.new(body: 'body', title: 'title', image_credits: 'credit')
      l.htmlize_content
      html = helper.listicle_html(l)
      target = '<article><div class="listicle-image-credit"><p>credit</p>'
      target << "\n"
      target << '</div><h2 class="list-item-title">title</h2></article><article><p>body</p>'
      target << "\n"
      target << '</article>'
      html.should eq(target)
    end
  end

  describe :body_id do
    context 'admin bikes index' do
      it 'returns admin_users_controller index_action' do
        controller = Admin::StolenBikesController.new
        expect(view).to receive(:controller).at_least(:once).and_return(controller)
        view.stub(:action_name).and_return('index')
        expect(helper.body_id).to eq('admin_stolen_bikes_index')
      end
    end
    context 'normal bikes show' do
      it 'returns bikes_controller show_action' do
        controller = BikesController.new
        expect(view).to receive(:controller).at_least(:once).and_return(controller)
        view.stub(:action_name).and_return('show')
        expect(helper.body_id).to eq('bikes_show')
      end
    end
  end
end
