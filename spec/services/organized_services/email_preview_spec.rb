require "rails_helper"

RSpec.describe OrganizedServices::EmailPreview do
  let(:organization) { FactoryBot.create(:organization) }
  let(:user) { FactoryBot.create(:user) }
  let(:params) { ActionController::Parameters.new }

  describe "view_component" do
    subject(:component) { described_class.view_component(kind:, organization:, user:, params:) }

    context "with a parking_notification kind" do
      let(:kind) { "appears_abandoned_notification" }

      context "without an existing parking_notification" do
        it "returns a parking_notification component built around a default_bike" do
          expect(component).to be_a(Emails::ParkingNotification::Component)
          parking_notification = component.instance_variable_get(:@parking_notification)
          expect(parking_notification).to be_a(ParkingNotification)
          expect(parking_notification).to_not be_persisted
          expect(parking_notification.kind).to eq kind
          expect(component.instance_variable_get(:@bike)).to be_present
          expect(component.instance_variable_get(:@email_preview)).to be true
          expect(component.email_sent_at).to be_nil
        end
      end

      context "with an existing parking_notification" do
        let!(:parking_notification) do
          FactoryBot.create(:parking_notification, organization: organization, kind: kind)
        end
        it "uses the existing parking_notification" do
          expect(component.instance_variable_get(:@parking_notification)).to eq parking_notification
          expect(component.instance_variable_get(:@bike)).to eq parking_notification.bike
        end
      end

      context "with a parking_notification_id param" do
        let!(:parking_notification) do
          FactoryBot.create(:parking_notification, organization: organization, kind: "parked_incorrectly_notification",
            delivery_status: "email_success")
        end
        let(:params) { ActionController::Parameters.new(parking_notification_id: parking_notification.id) }
        let(:kind) { "parked_incorrectly_notification" }

        it "loads the parking_notification by id and exposes email_sent_at" do
          expect(component.instance_variable_get(:@parking_notification)).to eq parking_notification
          expect(component.email_sent_at).to be_within(1.second).of(parking_notification.sent_at)
        end

        context "for a different organization" do
          let!(:parking_notification) { FactoryBot.create(:parking_notification, kind: "parked_incorrectly_notification") }
          it "raises RecordNotFound" do
            expect { component }.to raise_error(ActiveRecord::RecordNotFound)
          end
        end
      end
    end

    context "with graduated_notification kind" do
      let(:kind) { "graduated_notification" }

      context "without an existing graduated_notification" do
        it "returns a graduated_notification component" do
          expect(component).to be_a(Emails::GraduatedNotification::Component)
          graduated_notification = component.instance_variable_get(:@graduated_notification)
          expect(graduated_notification).to be_a(GraduatedNotification)
          expect(graduated_notification).to_not be_persisted
          expect(component.instance_variable_get(:@bike)).to be_present
          expect(component.instance_variable_get(:@email_preview)).to be true
          expect(component.email_sent_at).to be_nil
        end
      end

      context "with a graduated_notification_id param" do
        let!(:graduated_notification) do
          FactoryBot.create(:graduated_notification, organization: organization, delivery_status: "email_success")
        end
        let(:params) { ActionController::Parameters.new(graduated_notification_id: graduated_notification.id) }

        it "loads the graduated_notification by id and exposes email_sent_at" do
          expect(component.instance_variable_get(:@graduated_notification)).to eq graduated_notification
          expect(component.instance_variable_get(:@bike)).to eq graduated_notification.bike
          expect(component.email_sent_at).to be_within(1.second).of(graduated_notification.sent_at)
        end
      end
    end

    context "with impound_claim_approved kind" do
      let(:kind) { "impound_claim_approved" }

      context "without any impound_records" do
        it "returns an impound_claim component with no impound_claim" do
          expect(component).to be_a(Emails::ImpoundClaimApprovedOrDenied::Component)
          expect(component.instance_variable_get(:@impound_claim)).to be_nil
          expect(component.email_sent_at).to be_nil
        end
      end

      context "with an impound_record but no claims" do
        let!(:impound_record) { FactoryBot.create(:impound_record_with_organization, organization: organization) }
        it "builds an unsaved impound_claim with the matching status" do
          impound_claim = component.instance_variable_get(:@impound_claim)
          expect(impound_claim).to be_a(ImpoundClaim)
          expect(impound_claim).to_not be_persisted
          expect(impound_claim.status).to eq "approved"
          expect(impound_claim.impound_record).to eq impound_record
          expect(component.email_sent_at).to be_nil
        end
      end

      context "with an existing approved claim" do
        let!(:impound_claim) do
          FactoryBot.create(:impound_claim, organization: organization, status: "approved", resolved_at: 1.hour.ago)
        end
        it "loads the existing claim and exposes email_sent_at from resolved_at" do
          expect(component.instance_variable_get(:@impound_claim)).to eq impound_claim
          expect(component.email_sent_at).to be_within(1.second).of(impound_claim.resolved_at)
        end
      end

      context "for impound_claim_denied" do
        let(:kind) { "impound_claim_denied" }
        let!(:impound_record) { FactoryBot.create(:impound_record_with_organization, organization: organization) }
        it "builds a denied impound_claim" do
          expect(component.instance_variable_get(:@impound_claim).status).to eq "denied"
        end
      end
    end

    context "with partial_registration kind" do
      let(:kind) { "partial_registration" }

      context "without any b_params" do
        it "returns a partial_registration component with a new b_param" do
          expect(component).to be_a(Emails::PartialRegistration::Component)
          b_param = component.instance_variable_get(:@b_param)
          expect(b_param).to be_a(BParam)
          expect(b_param).to_not be_persisted
          expect(b_param.organization_id).to eq organization.id
          expect(component.instance_variable_get(:@email_preview)).to be true
          expect(component.email_sent_at).to be_nil
        end
      end

      context "with an existing b_param" do
        let!(:b_param) { FactoryBot.create(:b_param_with_creation_organization, organization: organization) }
        it "uses the most recent b_param and exposes email_sent_at from created_at" do
          expect(b_param.reload.organization_id).to eq organization.id
          expect(component.instance_variable_get(:@b_param)).to eq b_param
          expect(component.email_sent_at).to be_within(1.second).of(b_param.created_at)
        end
      end
    end

    context "with finished_registration kind" do
      let(:kind) { "finished_registration" }

      it "returns a finished_registration component" do
        expect(component).to be_a(Emails::FinishedRegistration::Component)
        bike = component.instance_variable_get(:@bike)
        expect(bike).to be_present
        expect(component.instance_variable_get(:@ownership)).to eq bike.current_ownership
        expect(component.instance_variable_get(:@email_preview)).to be true
      end

      context "without any organization bikes" do
        it "builds a placeholder bike with id 42 and has nil email_sent_at" do
          expect(component.instance_variable_get(:@bike).id).to eq 42
          expect(component.instance_variable_get(:@ownership).id).to eq 420
          expect(component.email_sent_at).to be_nil
        end
      end

      context "with an existing organization bike" do
        let!(:bike) { FactoryBot.create(:bike_organized, creation_organization: organization) }
        it "uses the existing bike and exposes email_sent_at from the ownership created_at" do
          expect(component.instance_variable_get(:@bike)).to eq bike
          expect(component.email_sent_at).to be_within(1.second).of(bike.current_ownership.created_at)
        end
      end
    end

    context "with organization_stolen_message kind" do
      let(:kind) { "organization_stolen_message" }

      it "uses default_stolen_bike with a current_stolen_record" do
        expect(component).to be_a(Emails::FinishedRegistration::Component)
        expect(component.instance_variable_get(:@bike).current_stolen_record).to be_present
      end

      context "with an enabled OrganizationStolenMessage" do
        let!(:organization_stolen_message) do
          OrganizationStolenMessage.for(organization).tap { |m| m.update(body: "watch out", is_enabled: true) }
        end
        it "assigns the organization_stolen_message to the stolen_record" do
          stolen_record = component.instance_variable_get(:@bike).current_stolen_record
          expect(stolen_record.organization_stolen_message).to eq organization_stolen_message
        end
      end
    end
  end

  describe "find_or_build_impound_claim" do
    let(:params) { ActionController::Parameters.new }

    context "without an impound_record" do
      it "returns nil" do
        expect(described_class.find_or_build_impound_claim(kind: "impound_claim_approved", organization:, params:)).to be_nil
      end
    end

    context "with an impound_record" do
      let!(:impound_record) { FactoryBot.create(:impound_record_with_organization, organization: organization) }

      it "builds an unsaved impound_claim with status matching the kind" do
        result = described_class.find_or_build_impound_claim(kind: "impound_claim_approved", organization:, params:)
        expect(result).to_not be_persisted
        expect(result.status).to eq "approved"
      end

      context "with an impound_claim_id param" do
        let!(:impound_claim) { FactoryBot.create(:impound_claim, organization: organization) }
        let(:params) { ActionController::Parameters.new(impound_claim_id: impound_claim.id) }

        it "loads by id" do
          result = described_class.find_or_build_impound_claim(kind: "impound_claim_approved", organization:, params:)
          expect(result).to eq impound_claim
        end
      end
    end
  end
end
