require 'spec_helper'

describe ApplicationHelper do
  describe :nav_link do
    context 'without a class' do
      it 'returns the link active if it ought to be' do
        view.stub(:current_page?).and_return(true)
        generated = '<a href="http://bikeindex.org" class=" active">Bike Index about</a>'
        expect(helper.nav_link('Bike Index about', 'http://bikeindex.org')).to eq generated
      end
    end
    context 'match controller true' do
      let(:request) { double('request', url: new_bike_url) }
      before { allow(helper).to receive(:request).and_return(request) }
      it 'returns the link active if it is a bikes page' do
        generated = '<a href="' + new_bike_url + '" class="seeeeeeee active">Bike Index bikes page</a>'
        result = helper.nav_link('Bike Index bikes page', new_bike_url, match_controller: true, class_name: 'seeeeeeee')
        expect(result).to eq generated
      end
    end
    context 'current with a class' do
      it 'returns the link active if it ought to be' do
        view.stub(:current_page?).and_return(true)
        generated = '<a href="http://bikeindex.org" class="nav-party-link active">Bike Index about</a>'
        result = helper.nav_link('Bike Index about', 'http://bikeindex.org', class_name: 'nav-party-link')
        expect(result).to eq generated
      end
    end
  end

  describe :current_page_content_page? do
    it 'returns link, active if it ought to be' do
      view.stub(:controller_name).and_return('info')
      helper.current_page_content_page?.should be true
    end
  end

  describe :current_page_form_well? do
    context 'bikes new' do
      it 'returns link, active if it ought to be' do
        view.stub(:controller_name).and_return('bikes')
        view.stub(:action_name).and_return('new')
        helper.current_page_form_well?.should be_true
      end
    end
    context 'bikes show' do
      it 'returns link, active if it ought to be' do
        view.stub(:controller_name).and_return('bikes')
        view.stub(:action_name).and_return('show')
        helper.current_page_form_well?.should be_false
      end
    end
  end

  describe :admin_nav_link do
    it 'returns link, active if it ought to be' do
      view.stub(:controller_name).and_return('organization_invitations')
      generated = '<a href="/invitations" class="">Invitations</a>'
      helper.nav_link('Invitations', '/invitations').should eq(generated)
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
