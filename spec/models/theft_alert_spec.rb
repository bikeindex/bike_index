require "rails_helper"

RSpec.describe TheftAlert, type: :model do
  describe "factory" do
    let(:theft_alert) { FactoryBot.build(:theft_alert) }
    it "is valid" do
      expect(theft_alert.save).to be_truthy
      expect(TheftAlert.paid.pluck(:id)).to eq([])
    end
    context "begun" do
      let(:theft_alert) { FactoryBot.build(:theft_alert_begun) }
      it "is valid" do
        expect(theft_alert.save).to be_truthy
      end
    end
    context "paid" do
      let(:theft_alert) { FactoryBot.build(:theft_alert_paid) }
      it "is valid" do
        expect(theft_alert.save).to be_truthy
        expect(theft_alert.payment).to be_present
        expect(TheftAlert.paid.pluck(:id)).to eq([theft_alert.id])
        expect(theft_alert.objective_campaign).to be_nil
        expect(theft_alert.objective_adset).to be_nil
      end
    end
  end

  describe "recovered bike" do
    let(:stolen_record) { FactoryBot.create(:stolen_record_recovered) }
    let!(:stolen_record2) { FactoryBot.create(:stolen_record_recovered) }
    let!(:theft_alert) { FactoryBot.create(:theft_alert, stolen_record: stolen_record) }
    let!(:theft_alert2) { FactoryBot.create(:theft_alert) }
    it "returns the bike" do
      expect(theft_alert.stolen_record).to eq stolen_record
      expect(theft_alert.recovered?).to be_truthy
      expect(StolenRecord.unscoped.with_theft_alerts.pluck(:id)).to match_array([stolen_record.id, theft_alert2.stolen_record_id])
      expect(StolenRecord.recovered.with_theft_alerts.pluck(:id)).to eq([stolen_record.id])
    end
  end

  describe "activateable?" do
    let(:theft_alert) { FactoryBot.create(:theft_alert, facebook_data: {no_notify: true}) }
    it "is false" do
      expect(theft_alert.missing_location?).to be_truthy
      expect(theft_alert.missing_photo?).to be_truthy
      expect(theft_alert.stolen_record_approved?).to be_falsey
      expect(theft_alert.paid?).to be_falsey
      expect(theft_alert.activateable?).to be_falsey
      expect(theft_alert.posted?).to be_falsey
      expect(theft_alert.notify?).to be_falsey
    end
    context "is activateable" do
      # let(:bike) { FactoryBot.create(:bike) }
      let(:stolen_record) { FactoryBot.create(:stolen_record, :with_images, :in_vancouver, approved: true) }
      let(:theft_alert) { FactoryBot.create(:theft_alert, :paid, stolen_record: stolen_record, facebook_data: {campaign_id: "xxxx"}) }
      it "is truthy" do
        expect(theft_alert.reload.missing_location?).to be_falsey
        expect(stolen_record.reload.images_attached?).to be_truthy
        expect(theft_alert.missing_photo?).to be_falsey
        expect(theft_alert.stolen_record_approved?).to be_truthy
        expect(theft_alert.paid?).to be_truthy
        expect(theft_alert.activateable?).to be_truthy
        expect(theft_alert.posted?).to be_falsey
        expect(theft_alert.failed_to_activate?).to be_falsey
        expect(TheftAlert.activating.pluck(:id)).to eq([])
        expect(TheftAlert.failed_to_activate.pluck(:id)).to eq([])
        # Also, test notify? in here too
        expect(theft_alert.notify?).to be_truthy
        stolen_record.update(receive_notifications: false)
        theft_alert.reload
        expect(theft_alert.notify?).to be_falsey
      end
    end
    context "with alert_image" do
      let(:stolen_record) { FactoryBot.create(:stolen_record, :with_alert_image, :in_vancouver, approved: true) }
      let(:theft_alert) { FactoryBot.create(:theft_alert, :paid, stolen_record: stolen_record, facebook_data: {campaign_id: "xxxx"}) }
      it "is activateable" do
        expect(theft_alert.missing_location?).to be_falsey
        expect(stolen_record.reload.images_attached?).to be_falsey
        expect(stolen_record.alert_image.present?).to be_truthy
        expect(theft_alert.missing_photo?).to be_falsey
        expect(theft_alert.stolen_record_approved?).to be_truthy
        expect(theft_alert.paid?).to be_truthy
        expect(theft_alert.activateable?).to be_truthy
        expect(theft_alert.posted?).to be_falsey
        expect(theft_alert.failed_to_activate?).to be_falsey
        expect(TheftAlert.activating.pluck(:id)).to eq([])
        expect(TheftAlert.failed_to_activate.pluck(:id)).to eq([])
        # Also, test notify? in here too
        expect(theft_alert.notify?).to be_truthy
        stolen_record.update(receive_notifications: false)
        theft_alert.reload
        expect(theft_alert.notify?).to be_falsey
      end
    end
  end

  describe "failed_to_activate?" do
    let(:theft_alert) do
      FactoryBot.create(:theft_alert, status: "pending", facebook_data: {activating_at:})
    end
    let(:activating_at) { (Time.current - 6.minutes).to_i }
    let(:start_at) { nil }
    it "is falsey" do
      expect(theft_alert.reload.start_at).to be_nil
      expect(theft_alert.failed_to_activate?).to be_truthy
      expect(TheftAlert.activating.pluck(:id)).to eq([theft_alert.id])
      expect(TheftAlert.failed_to_activate.pluck(:id)).to eq([theft_alert.id])

      theft_alert.update(start_at: Time.current, end_at: Time.current + 1.day, status: "active")
      expect(theft_alert.reload.start_at).to be_present
      expect(theft_alert.failed_to_activate?).to be_falsey
      expect(TheftAlert.activating.pluck(:id)).to eq([])
      expect(TheftAlert.failed_to_activate.pluck(:id)).to eq([])
    end
    context "start_at more recently" do
      let(:activating_at) { (Time.current - 2.minutes).to_i }

      it "is falsey" do
        expect(theft_alert.reload.failed_to_activate?).to be_falsey
        expect(TheftAlert.activating.pluck(:id)).to eq([theft_alert.id])
        expect(TheftAlert.failed_to_activate.pluck(:id)).to eq([])
      end
    end
  end

  describe "facebook names" do
    let(:theft_alert_plan) { TheftAlertPlan.new(amount_cents_facebook: 1999) }
    let(:theft_alert) { TheftAlert.new(id: 12, theft_alert_plan: theft_alert_plan) }
    let(:facebook_name) { "Theft Alert 12 - $19.99" }
    it "returns the theft alert plan" do
      expect(theft_alert.facebook_name("campaign")).to eq facebook_name
      expect(theft_alert.facebook_name("adset")).to eq "#{facebook_name} - adset"
      expect(theft_alert.facebook_name("ad")).to eq "#{facebook_name} - ad"
      expect(theft_alert.amount_cents_facebook).to eq 1999
      # Setting facebook_data overrides
      theft_alert.facebook_data = {"amount_cents" => 2909}
      expect(theft_alert.amount_cents_facebook).to eq 2909
      expect(theft_alert.facebook_name("ad")).to eq "Theft Alert 12 - $29.09 - ad"
    end
  end

  describe "facebook_updateable? and should_update_facebook?" do
    let(:theft_alert) { FactoryBot.create(:theft_alert, facebook_data: {}) }
    it "is falsey for no campaign_id" do
      expect(theft_alert.reload.facebook_updateable?).to be_falsey
      expect(theft_alert.should_update_facebook?).to be_falsey
      expect(TheftAlert.should_update_facebook.pluck(:id)).to eq([])
    end
    context "campaign_id" do
      let(:end_at) { Time.current - 1.hour }
      let(:theft_alert) { FactoryBot.create(:theft_alert, facebook_data: {campaign_id: "cxcxc"}, start_at: Time.current - 1.week, end_at: end_at) }
      it "is truthy" do
        expect(theft_alert.reload.facebook_updateable?).to be_truthy
        expect(theft_alert.live?).to be_falsey
        expect(theft_alert.should_update_facebook?).to be_truthy
        expect(TheftAlert.should_update_facebook.pluck(:id)).to eq([theft_alert.id])
        theft_alert.update(facebook_updated_at: Time.current - 1.hour)
        expect(theft_alert.reload.should_update_facebook?).to be_falsey
        expect(TheftAlert.should_update_facebook.pluck(:id)).to eq([theft_alert.id])
      end
      context "really ended" do
        let(:end_at) { Time.current - 3.days }
        it "is falsey" do
          expect(theft_alert.live?).to be_falsey
          expect(theft_alert.should_update_facebook?).to be_falsey
          expect(TheftAlert.should_update_facebook.pluck(:id)).to eq([])
        end
      end
    end
  end

  describe "admin differences" do
    let(:theft_alert_plan) { FactoryBot.create(:theft_alert_plan, ad_radius_miles: 24) }
    let(:stolen_record) { FactoryBot.create(:stolen_record, :with_images, :in_vancouver, approved: true) }
    let(:theft_alert) do
      FactoryBot.create(:theft_alert,
        theft_alert_plan: theft_alert_plan,
        ad_radius_miles: 333,
        stolen_record: stolen_record,
        admin: admin)
    end
    let(:admin) { false }
    it "is default attributes" do
      expect(theft_alert.reload.ad_radius_miles).to eq 24
      expect(theft_alert.activateable?).to be_falsey
      theft_alert.facebook_data = {activating_at: Time.current.to_i}
      expect(theft_alert.notify?).to be_truthy
      expect(TheftAlert.cities_count).to eq([["Canada", "Vancouver", nil, 1]])
    end
    context "admin" do
      let(:admin) { true }
      it "is what is set" do
        expect(theft_alert.reload.ad_radius_miles).to eq 333
        expect(theft_alert.activateable?).to be_truthy
        theft_alert.facebook_data = {activating_at: Time.current.to_i}
        expect(theft_alert.notify?).to be_falsey
      end
    end
  end
end
