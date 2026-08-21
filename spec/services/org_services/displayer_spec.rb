require "rails_helper"

RSpec.describe OrgServices::Displayer do
  describe "law_enforcement_missing_verified_features?" do
    let(:law_enforcement_organization) { Organization.new(kind: "law_enforcement") }
    let(:bike_shop_organization) { Organization.new(kind: "bike_shop") }
    it "is true for law_enforcement, false for shop, false for law_enforcement with unstolen_notifications" do
      expect(OrgServices::Displayer.law_enforcement_missing_verified_features?(law_enforcement_organization)).to be_truthy
      expect(OrgServices::Displayer.law_enforcement_missing_verified_features?(bike_shop_organization)).to be_falsey
    end
  end

  describe "avatar?" do
    let(:organization) { Organization.new }
    before { allow(organization).to receive(:avatar) { "a pretty picture" } }
    it "displays" do
      expect(OrgServices::Displayer.avatar?(organization)).to be_truthy
    end
    # someday, we might only want to show it for paid organizations
    context "paid" do
      it "displays" do
        organization.is_paid = true
        expect(OrgServices::Displayer.avatar?(organization)).to be_truthy
      end
    end
  end

  describe "bike_shop_display_integration_alert?" do
    let(:organization) { Organization.new(kind: "law_enforcement", pos_kind: "no_pos") }
    it "is falsey for non-shops" do
      expect(OrgServices::Displayer.bike_shop_display_integration_alert?(organization)).to be_falsey
    end
    context "shop" do
      let(:organization) { Organization.new(kind: "bike_shop", pos_kind: pos_kind) }
      let(:pos_kind) { "no_pos" }
      it "is true" do
        expect(OrgServices::Displayer.bike_shop_display_integration_alert?(organization)).to be_truthy
      end
      context "lightspeed_pos" do
        let(:pos_kind) { "lightspeed_pos" }
        it "is false" do
          expect(OrgServices::Displayer.bike_shop_display_integration_alert?(organization)).to be_falsey
        end
      end
      context "ascend_pos" do
        let(:pos_kind) { "ascend_pos" }
        it "is false" do
          expect(OrgServices::Displayer.bike_shop_display_integration_alert?(organization)).to be_falsey
        end
      end
      context "broken_pos" do
        let(:pos_kind) { "broken_lightspeed_pos" }
        it "is true" do
          expect(OrgServices::Displayer.bike_shop_display_integration_alert?(organization)).to be_truthy
        end
      end
      context "does_not_need_pos" do
        let(:pos_kind) { "does_not_need_pos" }
        it "is falsey" do
          expect(OrgServices::Displayer.bike_shop_display_integration_alert?(organization)).to be_falsey
        end
      end
    end
  end

  describe "subscription_expired_alert?" do
    let(:organization) { Organization.new }
    it "is falsey" do
      expect(OrgServices::Displayer.subscription_expired_alert?(organization)).to be_falsey
      organization.is_paid = true
      expect(OrgServices::Displayer.subscription_expired_alert?(organization)).to be_falsey
    end
    context "with current invoice" do
      let(:invoice) { FactoryBot.create(:invoice_with_payment, start_at: Time.current - 1.year, end_at: end_at) }
      let!(:organization) { invoice.organization }
      let(:end_at) { Time.current + 1.week }
      let(:invoice2) { FactoryBot.create(:invoice_paid, organization: organization) }
      it "is falsey" do
        expect(OrgServices::Displayer.subscription_expired_alert?(organization)).to be_falsey
        # With an active free invoice, the result is the same
        expect(invoice2.reload.active?).to be_truthy
        expect(invoice2.paid_money_in_full?).to be_falsey
        expect(OrgServices::Displayer.subscription_expired_alert?(organization.reload)).to be_falsey
      end
      context "expired last week" do
        let(:end_at) { Time.current - 1.week }
        it "is truthy" do
          expect(OrgServices::Displayer.subscription_expired_alert?(organization)).to be_truthy
          # With an active free invoice, the result is the same
          expect(invoice2.reload.active?).to be_truthy
          expect(invoice2.paid_money_in_full?).to be_falsey
          expect(OrgServices::Displayer.subscription_expired_alert?(organization.reload)).to be_truthy
        end
      end
      context "expired last year" do
        let(:end_at) { Time.current - 1.year }
        it "is falsey" do
          expect(OrgServices::Displayer.subscription_expired_alert?(organization)).to be_falsey
        end
      end
    end
  end

  describe "retrieval_link_url" do
    let(:graduated_notification) { FactoryBot.create(:graduated_notification) }
    it "is present" do
      expect(graduated_notification.marked_remaining_link_token).to be_present
      expect(OrgServices::Displayer.retrieval_link_url(graduated_notification)).to match(graduated_notification.marked_remaining_link_token)
    end
    context "parking_notification" do
      let(:parking_notification) { FactoryBot.create(:parking_notification) }
      it "is present" do
        expect(parking_notification.retrieval_link_token).to be_present
        expect(OrgServices::Displayer.retrieval_link_url(parking_notification)).to match(parking_notification.retrieval_link_token)
      end
      context "unregistered" do
        let(:parking_notification) { FactoryBot.create(:parking_notification_unregistered) }
        it "is nil" do
          expect(parking_notification.retrieval_link_token).to be_blank
          expect(OrgServices::Displayer.retrieval_link_url(parking_notification)).to be_nil
        end
      end
    end
  end

  describe "registration_field_label" do
    let(:organization) { Organization.new }

    it "is nil with or without an organization" do
      expect(OrgServices::Displayer.registration_field_label(organization, "extra_registration_number")).to be_nil
      expect(OrgServices::Displayer.registration_field_label(organization, "reg_address")).to be_nil
      expect(OrgServices::Displayer.registration_field_label(nil, "reg_phone")).to be_nil
      expect(OrgServices::Displayer.registration_field_label(nil, "organization_affiliation")).to be_nil
      expect(OrgServices::Displayer.registration_field_label(nil, "reg_student_id")).to be_nil
      expect(OrgServices::Displayer.registration_field_label(organization, "reg_bike_sticker")).to be_nil
      expect(OrgServices::Displayer.registration_field_label(organization, "owner_email")).to be_nil
    end

    context "with labels" do
      let(:labels) { {reg_phone: "You have to put this in, jerk", reg_extra_registration_number: "XXXZZZZ", reg_student_id: "PUT in student ID!"}.as_json }
      let(:feature_slugs) { %w[reg_extra_registration_number reg_address reg_phone reg_organization_affiliation reg_student_id reg_bike_sticker] }
      let(:organization) { Organization.new(enabled_feature_slugs: feature_slugs, registration_field_labels: labels) }

      it "is the organization's own wording, for the fields it named" do
        expect(OrgServices::Displayer.registration_field_label(organization, "reg_extra_registration_number")).to eq "XXXZZZZ"
        expect(OrgServices::Displayer.registration_field_label(organization, "reg_address")).to be_nil
        expect(OrgServices::Displayer.registration_field_label(organization, "reg_phone")).to eq labels["reg_phone"]
        expect(OrgServices::Displayer.registration_field_label(organization, "reg_organization_affiliation")).to be_nil
        expect(OrgServices::Displayer.registration_field_label(organization, "reg_student_id")).to eq "PUT in student ID!"
        expect(OrgServices::Displayer.registration_field_label(organization, "reg_bike_sticker")).to be_nil
        expect(OrgServices::Displayer.registration_field_label(organization, "owner_email")).to be_nil
      end

      context "owner_email with tags" do
        let(:labels) { {reg_address: "ADDY!!", owner_email: "<code>bikeindex.org</code> email"}.as_json }

        it "keeps them, stripping when asked" do
          expect(OrgServices::Displayer.registration_field_label(organization, "reg_address")).to eq "ADDY!!"
          expect(OrgServices::Displayer.registration_field_label(organization, "reg_phone")).to be_nil
          expect(OrgServices::Displayer.registration_field_label(organization, "owner_email")).to eq "<code>bikeindex.org</code> email"
          expect(OrgServices::Displayer.registration_field_label(organization, "owner_email", strip_tags: true)).to eq "bikeindex.org email"
        end
      end
    end
  end
end
