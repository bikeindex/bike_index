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

  describe "user_icon" do
    it "returns empty" do
      expect(user_icon_hash(User.new)).to eq({tags: []})
      expect(user_icon(User.new)).to be_blank
    end
    context "donor" do
      let(:payment) { FactoryBot.create(:payment, kind: "donation") }
      let(:user) { payment.user }
      let(:target) { "<span><span class=\"donor-icon user-icon ml-1\" title=\"Donor\">D</span></span>" }
      let(:target_full_text) { "<span><span class=\"donor-icon user-icon ml-1\" title=\"Donor\">D</span><span class=\"less-strong\">onor</span></span>" }
      it "returns donor" do
        expect(user.donor?).to be_truthy
        expect(user_icon_hash(user)).to eq({tags: %i[donor]})
        expect(user_icon(user)).to eq target
        expect(user_icon(user, full_text: true)).to eq target_full_text
      end
      context "promoted alert" do
        let!(:promoted_alert) { FactoryBot.create(:promoted_alert_paid, user: user) }
        let(:target) { "<span><span class=\"donor-icon user-icon ml-1\" title=\"Donor\">D</span><span class=\"theft-alert-icon user-icon ml-1\" title=\"Promoted alert purchaser\">P</span></span>" }
        let(:target_full_text) do
          "<span><span class=\"donor-icon user-icon ml-1\" title=\"Donor\">D</span><span class=\"less-strong\">onor</span>" \
            "<span class=\"theft-alert-icon user-icon ml-1\" title=\"Promoted alert purchaser\">P</span><span class=\"less-strong\">romoted alert</span>" \
            "</span>"
        end
        it "returns donor and promoted alert" do
          expect(user.donor?).to be_truthy
          expect(user.promoted_alert_purchaser?).to be_truthy
          expect(user_icon_hash(user)).to eq({tags: %i[donor promoted_alert]})
          expect(user_icon(user)).to eq target
          expect(user_icon(user, full_text: true)).to eq target_full_text
          user.superuser = true
          expect(user_icon_hash(user)).to eq({tags: %i[superuser]}) # It's just superuser
        end
      end
    end
    context "member" do
      let(:membership) { FactoryBot.create(:membership, start_at: 1.year.ago, end_at:) }
      let(:end_at) { Time.current + 1.day }
      let(:user) { membership.user }
      let(:target) { "<span><span class=\"donor-icon user-icon ml-1\" title=\"Member\">M</span></span>" }
      let(:target_full_text) { "<span><span class=\"donor-icon user-icon ml-1\" title=\"Member\">M</span><span class=\"less-strong\">ember</span></span>" }
      it "returns member" do
        expect(membership.reload.status).to eq "active"
        expect(user.donor?).to be_falsey
        expect(user_icon_hash(user)).to eq({tags: %i[member]})
        expect(user_icon(user)).to eq target
        expect(user_icon(user, full_text: true)).to eq target_full_text
      end
      context "membership ended" do
        let(:end_at) { Time.current - 1.hour }
        it "doesn't return member" do
          expect(membership.reload.status).to eq "ended"
          expect(user_icon_hash(user)).to eq({tags: []})
          expect(user_icon(user)).to be_blank
        end
      end
    end
    context "recovery" do
      let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed) }
      let!(:stolen_record_recovered) { FactoryBot.create(:stolen_record_recovered, bike: bike) }
      let(:user) { bike.user }
      it "returns recovery" do
        expect(user.reload).to be_present
        expect(user_icon_hash(user)).to eq({tags: %i[recovery]})
      end
    end
    context "organization" do
      let(:organization) { FactoryBot.create(:organization, kind: "bike_shop") }
      let(:user) { FactoryBot.create(:organization_user, organization: organization) }
      it "returns paid_org" do
        expect(user.paid_org?).to be_falsey
        expect(user_icon_hash(user)).to eq({tags: %i[organization_role], organization: {kind: :bike_shop, paid: false}})
      end
      context "paid_org" do
        let(:organization) { FactoryBot.create(:organization, :organization_features, kind: "law_enforcement") }
        let(:target) { "<span><span class=\"org-member-icon user-icon ml-1\" title=\"Paid organization member - Law Enforcement\">$O P</span></span>" }
        let(:target_full_text) { "<span><span class=\"org-member-icon user-icon ml-1\" title=\"Paid organization member - Law Enforcement\">$O P</span><span class=\"ml-1 less-strong\">Paid organization member - Law Enforcement</span></span>" }
        it "returns paid_org" do
          expect(user.paid_org?).to be_truthy
          expect(user_icon_hash(user)).to eq({tags: %i[organization_role], organization: {kind: :law_enforcement, paid: true}})
          expect(user_icon(user)).to eq target
          expect(user_icon(user, full_text: true)).to eq target_full_text
        end
      end
    end
  end

  describe "admin_path_for_object" do
    it "returns blank" do
      expect(admin_path_for_object).to be_blank
    end
    context "promoted_alert" do
      it "returns" do
        expect(admin_path_for_object(PromotedAlert.new(id: 69))).to eq admin_promoted_alert_path(69)
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
