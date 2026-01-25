# frozen_string_literal: true

require "rails_helper"

RSpec.describe AdminHelper, type: :helper do
  # This is sort of gross, because of all the stubbing, but it's still useful, so...
  describe "admin_nav_display_view_all" do
    before do
      allow(helper).to receive(:request) { double("request", url: bikes_path) }
      allow(helper).to receive(:dev_nav_select_links) { [] } # Can't get current_user to stub :(
      controller.params = ActionController::Parameters.new(passed_params)
      admin_nav_active = helper.admin_nav_select_links.find { |v| v[:title] == "Bikes" }
      allow(helper).to receive(:admin_nav_select_link_active) { admin_nav_active }
      allow(view).to receive(:current_page?) { true }
    end

    context "period all" do
      let(:passed_params) { {period: "all", timezone: "Party"} }
      it "is false" do
        expect(helper.admin_nav_select_link_active[:match_controller]).to be_truthy
        expect(helper.admin_nav_display_view_all).to be_falsey
      end
      context "with sort" do
        let(:passed_params) { {direction: "desc", render_chart: "true", sort: "manufacturer_id"} }
        it "is false" do
          expect(helper.admin_nav_display_view_all).to be_falsey
        end
      end
      context "with period != all" do
        let(:passed_params) { {period: "week", timezone: "Party"} }
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

  describe "mail_snippet_edit_path" do
    it "returns organization edit path for organization message" do
      mail_snippet = MailSnippet.new(kind: "parked_incorrectly_notification", organization_id: 12, id: 1)
      expect(edit_mail_snippet_path_for(mail_snippet)).to eq edit_organization_email_path("parked_incorrectly_notification", organization_id: 12)
    end
    it "returns admin path for custom" do
      mail_snippet = MailSnippet.new(kind: "custom", organization_id: 12, id: 2)
      expect(edit_mail_snippet_path_for(mail_snippet)).to eq edit_admin_mail_snippet_path(2)
    end
  end

  describe "credibility_scorer_color" do
    it "returns yellow for 50" do
      expect(credibility_scorer_color(50)).to eq "#ffc107"
      expect(credibility_scorer_color_table(50)).to eq ""
    end
    it "returns red for 25" do
      expect(credibility_scorer_color(25)).to eq "#dc3545"
      expect(credibility_scorer_color_table(25)).to eq "#dc3545"
    end
    it "returns green for 80" do
      expect(credibility_scorer_color(80)).to eq "#28a745"
    end
  end

  describe "admin_path_for_object" do
    it "returns blank" do
      expect(admin_path_for_object).to be_blank
    end
    context "theft_alert" do
      it "returns" do
        expect(admin_path_for_object(TheftAlert.new(id: 69))).to eq admin_theft_alert_path(69)
      end
    end
    context "user_phone" do
      it "returns" do
        expect(admin_path_for_object(UserPhone.new(id: 2, user_id: 42))).to eq admin_user_path(42)
      end
    end
    context "stolen_record" do
      it "returns" do
        expect(admin_path_for_object(StolenRecord.new(id: 22))).to eq admin_stolen_bike_path(22, stolen_record_id: 22)
      end
    end
    context "payment" do
      it "returns" do
        expect(admin_path_for_object(Payment.new(id: 412))).to eq admin_payment_path(412)
      end
    end
    context "impound_claim" do
      it "returns" do
        expect(admin_path_for_object(ImpoundClaim.new(id: 12))).to eq admin_impound_claim_path(12)
      end
    end
    context "impound_record" do
      it "returns" do
        expect(admin_path_for_object(ImpoundRecord.new(id: 11))).to eq admin_impound_record_path("pkey-11")
      end
    end
  end
end
