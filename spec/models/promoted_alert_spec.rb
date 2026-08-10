require "rails_helper"

RSpec.describe PromotedAlert, type: :model do
  describe "duplicate of TheftAlert" do
    it "has everything TheftAlert has" do
      expect(TheftAlert.column_names - PromotedAlert.column_names).to eq([])
      expect(TheftAlert.constants(false) - PromotedAlert.constants(false)).to eq([])
      expect(TheftAlert.instance_methods(false) - PromotedAlert.instance_methods(false)).to eq([])
      expect(TheftAlert.singleton_methods(false) - PromotedAlert.singleton_methods(false)).to eq([])
    end
  end

  describe "id sequence" do
    # Backfills::PromotedAlertJob copies theft_alerts across keeping their ids - CreatePromotedAlerts
    # reserves that range, and MINVALUE is what carries the reservation into db/structure.sql
    let(:min_value) { PromotedAlert.connection.select_value("SELECT min_value FROM pg_sequences WHERE sequencename = 'promoted_alerts_id_seq'") }
    it "starts above the reserved ids" do
      expect(min_value).to be > 1
      expect(FactoryBot.create(:promoted_alert).id).to be >= min_value
    end
  end

  describe "factory" do
    let(:promoted_alert) { FactoryBot.build(:promoted_alert) }
    it "is valid" do
      expect(promoted_alert.save).to be_truthy
      expect(PromotedAlert.paid.pluck(:id)).to eq([])
    end
    context "begun" do
      let(:promoted_alert) { FactoryBot.build(:promoted_alert_begun) }
      it "is valid" do
        expect(promoted_alert.save).to be_truthy
      end
    end
    context "paid" do
      let(:promoted_alert) { FactoryBot.build(:promoted_alert_paid) }
      it "is valid" do
        expect(promoted_alert.save).to be_truthy
        expect(promoted_alert.payment).to be_present
        expect(PromotedAlert.paid.pluck(:id)).to eq([promoted_alert.id])
        expect(promoted_alert.objective_campaign).to be_nil
        expect(promoted_alert.objective_adset).to be_nil
      end
    end
  end

  describe "recovered bike" do
    let(:stolen_record) { FactoryBot.create(:stolen_record_recovered) }
    let!(:promoted_alert) { FactoryBot.create(:promoted_alert, stolen_record: stolen_record) }
    it "returns the bike" do
      expect(promoted_alert.stolen_record).to eq stolen_record
      expect(promoted_alert.recovered?).to be_truthy
    end
  end

  describe "activateable?" do
    let(:promoted_alert) { FactoryBot.create(:promoted_alert, facebook_data: {no_notify: true}) }
    it "is false" do
      expect(promoted_alert.missing_location?).to be_truthy
      expect(promoted_alert.stolen_record_approved?).to be_falsey
      expect(promoted_alert.paid?).to be_falsey
      expect(promoted_alert.activateable?).to be_falsey
      expect(promoted_alert.posted?).to be_falsey
      expect(promoted_alert.notify?).to be_falsey
    end
    context "is activateable" do
      let(:stolen_record) { FactoryBot.create(:stolen_record, :with_images, :in_vancouver, approved:) }
      let(:approved) { false }
      let(:promoted_alert) { FactoryBot.create(:promoted_alert, :paid, stolen_record: stolen_record, facebook_data: {}) }
      it "is truthy" do
        expect(promoted_alert.reload.missing_location?).to be_falsey
        expect(stolen_record.reload.images_attached?).to be_truthy
        expect(promoted_alert.missing_photo?).to be_falsey
        expect(promoted_alert.stolen_record_approved?).to be_falsey
        expect(promoted_alert.paid?).to be_truthy
        expect(promoted_alert.activateable?).to be_truthy
        expect(promoted_alert.posted?).to be_falsey
        expect(promoted_alert.failed_to_activate?).to be_falsey
        expect(PromotedAlert.activating.pluck(:id)).to eq([])
        expect(PromotedAlert.failed_to_activate.pluck(:id)).to eq([])
        # Also, test notify? in here too
        expect(promoted_alert.notify?).to be_falsey
        promoted_alert.update(facebook_data: {campaign_id: "xxxx"})
        expect(promoted_alert.reload.activateable?).to be_truthy
        expect(promoted_alert.posted?).to be_falsey
        expect(promoted_alert.failed_to_activate?).to be_falsey
        expect(promoted_alert.notify?).to be_truthy
        stolen_record.update(receive_notifications: false)
        expect(promoted_alert.reload.notify?).to be_falsey
      end
      context "approved" do
        let(:approved) { true }
        it "is truthy" do
          expect(promoted_alert.reload.paid?).to be_truthy
          expect(promoted_alert.activateable_except_approval?).to be_truthy
          expect(promoted_alert.activateable?).to be_truthy
          expect(promoted_alert.stolen_record_approved?).to be_truthy
          expect(promoted_alert.posted?).to be_falsey
        end
        context "bike user hidden" do
          let!(:bike) { stolen_record.reload.bike }
          it "is falsey" do
            bike.update(user_hidden: true)
            expect(bike.reload.current?).to be_falsey
            expect(Bike.where(id: bike.id).count).to eq 0 # Because default scope
            expect(promoted_alert.reload.missing_location?).to be_falsey
            expect(stolen_record.reload.images_attached?).to be_truthy
            expect(promoted_alert.missing_photo?).to be_falsey
            expect(promoted_alert.stolen_record_approved?).to be_truthy
            expect(promoted_alert.paid?).to be_truthy
            expect(promoted_alert.activateable?).to be_falsey
            expect(promoted_alert.bike).to be_present
            promoted_alert.update(status: :inactive)
            expect(promoted_alert.reload.failed_to_activate?).to be_falsey
            expect(promoted_alert.manual_override_inactive?).to be_truthy
          end
        end
      end
    end
    context "with alert_image" do
      let(:stolen_record) { FactoryBot.create(:stolen_record, :with_alert_image, :in_vancouver, approved: true) }
      let(:promoted_alert) { FactoryBot.create(:promoted_alert, :paid, stolen_record: stolen_record, facebook_data: {campaign_id: "xxxx"}) }
      it "is activateable" do
        expect(promoted_alert.missing_location?).to be_falsey
        expect(stolen_record.reload.images_attached?).to be_falsey
        expect(stolen_record.alert_image.present?).to be_truthy
        expect(promoted_alert.missing_photo?).to be_falsey
        expect(promoted_alert.stolen_record_approved?).to be_truthy
        expect(promoted_alert.paid?).to be_truthy
        expect(promoted_alert.activateable?).to be_truthy
        expect(promoted_alert.posted?).to be_falsey
        expect(promoted_alert.failed_to_activate?).to be_falsey
        expect(PromotedAlert.activating.pluck(:id)).to eq([])
        expect(PromotedAlert.failed_to_activate.pluck(:id)).to eq([])
        # Also, test notify? in here too
        expect(promoted_alert.notify?).to be_truthy
        stolen_record.update(receive_notifications: false)
        promoted_alert.reload
        expect(promoted_alert.notify?).to be_falsey
      end
    end
  end

  describe "failed_to_activate?" do
    let(:promoted_alert) do
      FactoryBot.create(:promoted_alert, status: "pending", facebook_data: {activating_at:})
    end
    let(:activating_at) { (Time.current - 6.minutes).to_i }
    let(:start_at) { nil }
    it "is falsey" do
      expect(promoted_alert.reload.start_at).to be_nil
      expect(promoted_alert.failed_to_activate?).to be_truthy
      expect(PromotedAlert.activating.pluck(:id)).to eq([promoted_alert.id])
      expect(PromotedAlert.failed_to_activate.pluck(:id)).to eq([promoted_alert.id])

      promoted_alert.update(start_at: Time.current, end_at: Time.current + 1.day, status: "active")
      expect(promoted_alert.reload.start_at).to be_present
      expect(promoted_alert.failed_to_activate?).to be_falsey
      expect(PromotedAlert.activating.pluck(:id)).to eq([])
      expect(PromotedAlert.failed_to_activate.pluck(:id)).to eq([])
    end
    context "start_at more recently" do
      let(:activating_at) { (Time.current - 2.minutes).to_i }

      it "is falsey" do
        expect(promoted_alert.reload.failed_to_activate?).to be_falsey
        expect(PromotedAlert.activating.pluck(:id)).to eq([promoted_alert.id])
        expect(PromotedAlert.failed_to_activate.pluck(:id)).to eq([])
      end
    end
  end

  describe "facebook names" do
    let(:theft_alert_plan) { TheftAlertPlan.new(amount_cents_facebook: 1999) }
    let(:promoted_alert) { PromotedAlert.new(id: 12, theft_alert_plan: theft_alert_plan) }
    let(:facebook_name) { "Theft Alert 12 - $19.99" }
    it "returns the theft alert plan" do
      expect(promoted_alert.facebook_name("campaign")).to eq facebook_name
      expect(promoted_alert.facebook_name("adset")).to eq "#{facebook_name} - adset"
      expect(promoted_alert.facebook_name("ad")).to eq "#{facebook_name} - ad"
      expect(promoted_alert.amount_cents_facebook).to eq 1999
      # Setting facebook_data overrides
      promoted_alert.facebook_data = {"amount_cents" => 2909}
      expect(promoted_alert.amount_cents_facebook).to eq 2909
      expect(promoted_alert.facebook_name("ad")).to eq "Theft Alert 12 - $29.09 - ad"
    end
  end

  describe "facebook_updateable? and should_update_facebook?" do
    let(:promoted_alert) { FactoryBot.create(:promoted_alert, facebook_data: {}) }
    it "is falsey for no campaign_id" do
      expect(promoted_alert.reload.facebook_updateable?).to be_falsey
      expect(promoted_alert.should_update_facebook?).to be_falsey
      expect(PromotedAlert.should_update_facebook.pluck(:id)).to eq([])
    end
    context "campaign_id" do
      let(:end_at) { Time.current - 1.hour }
      let(:promoted_alert) { FactoryBot.create(:promoted_alert, facebook_data: {campaign_id: "cxcxc"}, start_at: Time.current - 1.week, end_at: end_at) }
      it "is truthy" do
        expect(promoted_alert.reload.facebook_updateable?).to be_truthy
        expect(promoted_alert.live?).to be_falsey
        expect(promoted_alert.should_update_facebook?).to be_truthy
        expect(PromotedAlert.should_update_facebook.pluck(:id)).to eq([promoted_alert.id])
        promoted_alert.update(facebook_updated_at: Time.current - 1.hour)
        expect(promoted_alert.reload.should_update_facebook?).to be_falsey
        expect(PromotedAlert.should_update_facebook.pluck(:id)).to eq([promoted_alert.id])
      end
      context "really ended" do
        let(:end_at) { Time.current - 3.days }
        it "is falsey" do
          expect(promoted_alert.live?).to be_falsey
          expect(promoted_alert.should_update_facebook?).to be_falsey
          expect(PromotedAlert.should_update_facebook.pluck(:id)).to eq([])
        end
      end
    end
  end

  describe "admin differences" do
    let(:theft_alert_plan) { FactoryBot.create(:theft_alert_plan, ad_radius_miles: 24) }
    let(:stolen_record) { FactoryBot.create(:stolen_record, :with_images, :in_vancouver, approved: true) }
    let(:promoted_alert) do
      FactoryBot.create(:promoted_alert,
        theft_alert_plan: theft_alert_plan,
        ad_radius_miles: 333,
        stolen_record: stolen_record,
        admin: admin)
    end
    let(:admin) { false }
    it "is default attributes" do
      expect(promoted_alert.reload.ad_radius_miles).to eq 24
      expect(promoted_alert.activateable?).to be_falsey
      promoted_alert.facebook_data = {activating_at: Time.current.to_i}
      expect(promoted_alert.notify?).to be_truthy
      expect(PromotedAlert.cities_count).to eq([["Canada", "Vancouver", nil, 1]])
    end
    context "admin" do
      let(:admin) { true }
      it "is what is set" do
        expect(promoted_alert.reload.ad_radius_miles).to eq 333
        expect(promoted_alert.activateable?).to be_truthy
        promoted_alert.facebook_data = {activating_at: Time.current.to_i}
        expect(promoted_alert.notify?).to be_falsey
      end
    end
  end

  describe "paid and admin scoping" do
    let(:payment_unpaid) { FactoryBot.create(:payment, paid_at: nil) }
    let(:promoted_alert_unpaid) { FactoryBot.create(:promoted_alert, payment: payment_unpaid, user: payment_unpaid.user) }
    let!(:stolen_record_unpaid_id) { promoted_alert_unpaid.stolen_record_id }
    let(:promoted_alert_paid) { FactoryBot.create(:promoted_alert, :paid) }
    let!(:stolen_record_paid_id) { promoted_alert_paid.stolen_record_id }
    let(:promoted_alert_admin) { FactoryBot.create(:promoted_alert, admin: true) }
    let!(:stolen_record_admin_id) { promoted_alert_admin.stolen_record_id }
    let(:promoted_alert_admin_and_unpaid) { FactoryBot.create(:promoted_alert, admin: true) }
    let!(:stolen_record_admin_and_unpaid_id) { promoted_alert_admin_and_unpaid.stolen_record_id }
    let!(:promoted_alert_admin_unpaid) { FactoryBot.create(:promoted_alert, stolen_record_id: stolen_record_admin_and_unpaid_id) }
    let(:stolen_record_ids) { [stolen_record_unpaid_id, stolen_record_paid_id, stolen_record_admin_id, stolen_record_admin_and_unpaid_id] }

    it "finds the pertinent alerts" do
      expect(Payment.paid.pluck(:id)).to eq([promoted_alert_paid.payment_id])
      expect(StolenRecord.pluck(:id)).to match_array stolen_record_ids
      expect(PromotedAlert.paid.pluck(:id)).to match_array([promoted_alert_paid.id])
      expect(PromotedAlert.admin.pluck(:id)).to match_array([promoted_alert_admin.id, promoted_alert_admin_and_unpaid.id])
      expect(PromotedAlert.paid_or_admin.pluck(:id)).to match_array([promoted_alert_paid.id, promoted_alert_admin.id, promoted_alert_admin_and_unpaid.id])
    end
  end
end
