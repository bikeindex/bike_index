require 'spec_helper'

describe InfoController do
  describe 'non-react views' do
    %w(about protect_your_bike where serials image_resources resources dev_and_design).each do |page|
      context page do
        it 'renders with content layout' do
          get page.to_sym
          expect(response.status).to eq(200)
          expect(response).to render_template(page.to_sym)
          expect(response).to render_with_layout('content')
        end
      end
    end
    %w(support_the_index).each do |page|
      context page do
        it 'renders with application_updated' do
          get page.to_sym
          expect(response.status).to eq(200)
          expect(response).to render_template(page.to_sym)
          expect(response).to render_with_layout('application_updated')
        end
      end
    end
    %w(privacy terms vendor_terms).each do |page|
      context "#{page} renders" do
        it 'renders with legal' do
          get page.to_sym
          expect(response.status).to eq(200)
          expect(response).to render_template(page.to_sym)
          expect(response).to render_with_layout('legal')
        end
      end
    end
  end

  describe 'revised views' do
    # Because layouts are set manually, we aren't testing:
    # privacy terms vendor_terms support_the_index
    %w(about protect_your_bike where serials image_resources resources dev_and_design).each do |page|
      context "#{page} with revised_layout enabled" do
        it 'renders with revised_layout' do
          allow(controller).to receive(:revised_layout_enabled) { true }
          get page.to_sym
          expect(response.status).to eq(200)
          expect(response).to render_template(page.to_sym)
          expect(response).to render_with_layout('application_revised')
        end
      end
    end
  end
end
