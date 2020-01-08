# frozen_string_literal: true

require "rails_helper"

RSpec.describe AdminHelper, type: :helper do
  # This is sort of gross, because of all the stubbing, but it's still useful, so...
  describe "admin_nav_display_view_all" do
    before do
      allow(helper).to receive(:request) { double("request", url: bikes_path) }
      controller.params = ActionController::Parameters.new(passed_params)
      admin_nav_active = helper.admin_nav_select_links.select { |v| v[:title] == "Bikes" }.first
      allow(helper).to receive(:admin_nav_select_link_active) { admin_nav_active }
      allow(view).to receive(:current_page?) { true }
    end

    context "period all" do
      let(:passed_params) { { period: "all", timezone: "Party" } }
      it "is false" do
        expect(helper.admin_nav_select_link_active[:match_controller]).to be_truthy
        expect(helper.admin_nav_display_view_all).to be_falsey
      end
      context "with sort" do
        let(:passed_params) { { direction: "desc", render_chart: "true", sort: "manufacturer_id" } }
        it "is false" do
          expect(helper.admin_nav_display_view_all).to be_falsey
        end
      end
      context "with period != all" do
        let(:passed_params) { { period: "week", timezone: "Party" } }
        it "is true" do
          expect(helper.admin_nav_display_view_all).to be_truthy
        end
      end
      context "not actual current_page" do
        it "is true" do
          allow(helper).to receive(:current_page_active?) { false }
          expect(helper.admin_nav_display_view_all).to be_truthy
        end
      end
    end
  end
end
