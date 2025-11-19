# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::CurrentHeader::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) { with_request_url("/admin") { render_inline(instance) } }
  let(:options) { {params:} }
  let(:params) { {} }

  describe "rendering" do
    context "without header params" do
      it "renders nothing" do
        expect(component.text).not_to include("view for all")
      end
    end

    context "with user_id param" do
      context "when user exists" do
        let(:user) { FactoryBot.create(:user, name: "Test User") }
        let(:params) { {user_id: user.id} }
        let(:options) { {params:, user:, viewing: "Activity"} }

        it "renders user information with link" do
          expect(component.text).to include("Activities for")
          expect(component.text).to include(user.display_name)
          expect(component).to have_css("a", text: "view for all users")
        end
      end

      context "when user does not exist" do
        let(:params) { {user_id: 99999} }

        it "renders missing user message" do
          expect(component.text).to include("User #99999")
          expect(component).to have_css("span.tw:text-red-800 em", text: "missing")
          expect(component).to have_css("a", text: "view for all users")
        end
      end
    end

    context "with organization_id param" do
      context "when organization exists" do
        let(:organization) { FactoryBot.create(:organization) }
        let(:params) { {organization_id: organization.id} }
        let(:options) { {params:, current_organization: organization, viewing: "Bike"} }

        it "renders organization information" do
          expect(component.text).to include("Bikes for")
          expect(component.text).to include(organization.short_name)
          expect(component).to have_css("a", text: "view for all organizations")
        end
      end

      context "when no organization provided" do
        let(:params) { {organization_id: 123} }
        let(:options) { {params:, viewing: "Bike"} }

        it "renders no organization message" do
          expect(component.text).to include("Bikes for")
          expect(component.text).to include("no organization")
          expect(component).to have_css("a", text: "view for all organizations")
        end
      end
    end

    context "with search_bike_id param" do
      context "when bike exists" do
        let(:bike) { FactoryBot.create(:bike) }
        let(:params) { {search_bike_id: bike.id} }
        let(:options) { {params:, bike:, viewing: "Recovery"} }

        it "renders bike information" do
          expect(component.text).to include("Recoveries for")
          expect(component.text).to include(bike.title_string)
          expect(component).to have_css("a", text: "view for all bikes")
        end
      end

      context "when bike does not exist" do
        let(:params) { {search_bike_id: 88888} }

        it "renders missing bike message" do
          expect(component.text).to include("Bike #88888")
          expect(component).to have_css("span.tw:text-red-800 em", text: "missing")
          expect(component).to have_css("a", text: "view for all bikes")
        end
      end
    end

    context "with search_kind param" do
      let(:params) { {search_kind: "bike_shop"} }
      let(:options) { {params:, viewing: "Organization"} }

      it "renders humanized kind" do
        expect(component.text).to include("Organizations for")
        expect(component.text).to include("Bike shop")
        expect(component).to have_css("a", text: "view for all kinds")
      end

      context "with custom kind_humanized" do
        let(:options) { {params:, kind_humanized: "Special Kind", viewing: "Thing"} }

        it "renders custom kind humanized text" do
          expect(component.text).to include("Special Kind")
          expect(component).to have_css("a", text: "view for all kinds")
        end
      end
    end

    context "with search_membership_id param" do
      let(:params) { {search_membership_id: 42} }
      let(:options) { {params:, viewing: "Transaction"} }

      it "renders membership information" do
        expect(component.text).to include("Transactions for")
        expect(component.text).to include("Membership 42")
        expect(component).to have_css("a", text: "view for all memberships")
      end
    end
  end
end
