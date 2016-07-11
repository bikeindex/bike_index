require 'spec_helper'

describe ApplicationHelper do
  describe 'active_link' do
    context 'without a class' do
      it 'returns the link active if it ought to be' do
        allow(view).to receive(:current_page?).and_return(true)
        generated = '<a class=" active" id="" href="http://bikeindex.org">Bike Index about</a>'
        expect(helper.active_link('Bike Index about', 'http://bikeindex.org')).to eq generated
      end
    end
    context 'match controller true' do
      let(:request) { double('request', url: new_bike_url) }
      before { allow(helper).to receive(:request).and_return(request) }
      it 'returns the link active if it is a bikes page' do
        generated = '<a class="seeeeeeee active" id="" href="' + new_bike_url + '">Bike Index bikes page</a>'
        result = helper.active_link('Bike Index bikes page', new_bike_url, match_controller: true, class_name: 'seeeeeeee')
        expect(result).to eq generated
      end
    end
    context 'current with a class' do
      it 'returns the link active if it ought to be' do
        allow(view).to receive(:current_page?).and_return(true)
        generated = '<a class="nav-party-link active" id="" href="http://bikeindex.org">Bike Index about</a>'
        result = helper.active_link('Bike Index about', 'http://bikeindex.org', class_name: 'nav-party-link')
        expect(result).to eq generated
      end
    end
    context 'organization_invitation' do
      it 'returns link, active if it ought to be' do
        allow(view).to receive(:controller_name).and_return('organization_invitations')
        generated = '<a class="" id="" href="/invitations">Invitations</a>'
        expect(helper.active_link('Invitations', '/invitations')).to eq(generated)
      end
    end
  end

  describe 'current_page_skeleton' do
    context 'bikes' do
      before { allow(view).to receive(:controller_name) { 'bikes' } }
      %w(new create).each do |action|
        context action do
          it 'returns nil' do
            allow(view).to receive(:action_name) { action }
            expect(helper.current_page_skeleton).to be_nil
          end
        end
      end
      %w(edit update).each do |action|
        context action do
          it 'returns edit_bike_skeleton' do
            allow(view).to receive(:action_name) { action }
            expect(helper.current_page_skeleton).to eq 'edit_bike_skeleton'
          end
        end
      end
    end
    context 'bikes' do
      before { allow(view).to receive(:controller_name) { 'registrations' } }
      %w(new create edit).each do |action|
        context action do
          it 'returns nil' do
            allow(view).to receive(:action_name) { action }
            expect(helper.current_page_skeleton).to eq 'content_skeleton'
          end
        end
      end
    end
    context 'info' do
      before { allow(view).to receive(:controller_name) { 'info' } }
      %w(about protect_your_bike where serials image_resources resources dev_and_design).each do |action|
        context action do
          it 'returns content_skeleton' do
            allow(view).to receive(:action_name) { action }
            expect(helper.current_page_skeleton).to eq 'content_skeleton'
          end
        end
      end
      context 'support_the_index' do
        it 'returns nil' do
          allow(view).to receive(:action_name) { 'support_the_index' }
          expect(helper.current_page_skeleton).to be_nil
        end
      end
      %w(terms vendor_terms privacy).each do |action|
        context action do
          it 'returns nil' do
            allow(view).to receive(:action_name) { action }
            expect(helper.current_page_skeleton).to be_nil
          end
        end
      end
    end
    context 'news' do
      before { allow(view).to receive(:controller_name) { 'news' } }
      %w(index show).each do |action|
        context action do
          it 'returns content_skeleton' do
            allow(view).to receive(:action_name) { action }
            expect(helper.current_page_skeleton).to eq 'content_skeleton'
          end
        end
      end
    end
    context 'payments' do
      before { allow(view).to receive(:controller_name) { 'payments' } }
      %w(new create).each do |action|
        context action do
          it 'returns nil' do
            allow(view).to receive(:action_name) { action }
            expect(helper.current_page_skeleton).to be_nil
          end
        end
      end
    end
    context 'feedbacks' do
      before { allow(view).to receive(:controller_name) { 'feedbacks' } }
      %w(index).each do |action|
        context action do
          it 'returns content_skeleton' do
            allow(view).to receive(:action_name) { action }
            expect(helper.current_page_skeleton).to eq 'content_skeleton'
          end
        end
      end
    end
    context 'manufacturers' do
      before { allow(view).to receive(:controller_name) { 'manufacturers' } }
      %w(index).each do |action|
        context action do
          it 'returns nil' do
            allow(view).to receive(:action_name) { action }
            expect(helper.current_page_skeleton).to eq 'content_skeleton'
          end
        end
      end
    end
    context 'welcome' do
      before { allow(view).to receive(:controller_name) { 'welcome' } }
      %w(goodbye).each do |action|
        context action do
          it 'returns content_skeleton' do
            allow(view).to receive(:action_name) { action }
            expect(helper.current_page_skeleton).to eq 'content_skeleton'
          end
        end
      end
    end
    context 'organizations' do
      before { allow(view).to receive(:controller_name) { 'organizations' } }
      %w(new lightspeed_integration).each do |action|
        context action do
          it 'returns content_skeleton' do
            allow(view).to receive(:action_name) { action }
            expect(helper.current_page_skeleton).to eq 'content_skeleton'
          end
        end
      end
    end
    context 'organization subrouting' do
      before { allow(view).to receive(:sub_module_name) { 'organized_' } }
      context 'manage' do
        before { allow(view).to receive(:controller_name) { 'manage' } }
        it 'returns organized for index' do
          allow(view).to receive(:action_name) { 'index' }
          expect(helper.current_page_skeleton).to eq 'organized_skeleton'
        end
      end
      context 'bikes' do
        before { allow(view).to receive(:controller_name) { 'bikes' } }
        it 'returns organized for index' do
          allow(view).to receive(:action_name) { 'index' }
          expect(helper.current_page_skeleton).to eq 'organized_skeleton'
        end
      end
      context 'users' do
        before { allow(view).to receive(:controller_name) { 'users' } }
        it 'returns organized for index' do
          allow(view).to receive(:action_name) { 'index' }
          expect(helper.current_page_skeleton).to eq 'organized_skeleton'
        end
      end
    end
    context 'stolen' do
      before { allow(view).to receive(:controller_name) { 'stolen' } }
      %w(index).each do |action|
        context action do
          it 'returns content_skeleton' do
            allow(view).to receive(:action_name) { action }
            expect(helper.current_page_skeleton).to eq 'content_skeleton'
          end
        end
      end
    end
    context 'users' do
      before { allow(view).to receive(:controller_name) { 'users' } }
      %w(create).each do |action|
        context action do
          it 'returns content_skeleton' do
            allow(view).to receive(:action_name) { action }
            expect(helper.current_page_skeleton).to eq 'content_skeleton'
          end
        end
      end
    end
    context 'errors' do
      before { allow(view).to receive(:controller_name) { 'errors' } }
      %w(bad_request not_found unprocessable_entity server_error unauthorized).each do |action|
        context action do
          it 'returns content_skeleton' do
            allow(view).to receive(:action_name) { action }
            expect(helper.current_page_skeleton).to eq 'content_skeleton'
          end
        end
      end
    end
  end

  describe 'content_page_type' do
    context 'info controller' do
      it 'returns info active_page' do
        allow(view).to receive(:controller_name).and_return('info')
        allow(view).to receive(:action_name).and_return('dev_and_design')
        expect(helper.content_page_type).to eq 'dev_and_design'
      end
    end
    context 'news controller' do
      it 'returns news index' do
        allow(view).to receive(:controller_name).and_return('news')
        allow(view).to receive(:action_name).and_return('index')
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

  describe 'content_nav_class' do
    it 'returns active if the section is the active_section' do
      @active_section = 'resources'
      expect(helper.content_nav_class('resources')).to eq('active-menu')
    end
  end

  describe 'listicle_html' do
    it 'returns the html formatted as we want' do
      l = Listicle.new(body: 'body', title: 'title', image_credits: 'credit')
      l.htmlize_content
      html = helper.listicle_html(l)
      target = '<article><div class="listicle-image-credit"><p>credit</p>'
      target << "\n"
      target << '</div><h2 class="list-item-title">title</h2></article><article><p>body</p>'
      target << "\n"
      target << '</article>'
      expect(html).to eq(target)
    end
  end

  describe 'body_id' do
    context 'admin bikes index' do
      it 'returns admin_users_controller index_action' do
        controller = Admin::StolenBikesController.new
        expect(view).to receive(:controller).at_least(:once).and_return(controller)
        allow(view).to receive(:action_name).and_return('index')
        expect(helper.body_id).to eq('admin_stolen_bikes_index')
      end
    end
    context 'normal bikes show' do
      it 'returns bikes_controller show_action' do
        controller = BikesController.new
        expect(view).to receive(:controller).at_least(:once).and_return(controller)
        allow(view).to receive(:action_name).and_return('show')
        expect(helper.body_id).to eq('bikes_show')
      end
    end
  end
end
