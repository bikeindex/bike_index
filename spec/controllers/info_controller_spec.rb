require 'spec_helper'

describe InfoController do
  describe 'revised views' do
    pages = %w(about protect_your_bike where serials image_resources resources dev_and_design support_the_index terms vendor_terms support_the_index)
    context 'no user' do
      pages.each do |page|
        context "#{page} with revised_layout enabled" do
          it 'renders with revised_layout' do
            get page.to_sym
            expect(response.status).to eq(200)
            expect(response).to render_template(page.to_sym)
            if page == 'support_the_index'
              expect(response).to render_with_layout('payments_layout')
            else
              expect(response).to render_with_layout('application_revised')
            end
          end
        end
      end
    end
    context 'signed in user' do
      let(:user) { FactoryGirl.create(:user) }
      # Since we're rendering things, and these are important pages,
      # let's test with users as well
      before do
        set_current_user(user)
      end
      pages.each do |page|
        context "#{page} with revised_layout enabled" do
          it 'renders with revised_layout' do
            get page.to_sym
            expect(response.status).to eq(200)
            expect(response).to render_template(page.to_sym)
            if page == 'support_the_index'
              expect(response).to render_with_layout('payments_layout')
            else
              expect(response).to render_with_layout('application_revised')
            end
          end
        end
      end
    end
  end
end
