require "rails_helper"

RSpec.describe OrganizedServices::EmailPreview do
  let(:organization) { FactoryBot.create(:organization) }
  let(:user) { FactoryBot.create(:user) }
  let(:params) { ActionController::Parameters.new }

  describe "call" do
    subject(:result) { described_class.call(kind:, organization:, user:, params:) }

    context "with a parking_notification kind" do
      let(:kind) { "appears_abandoned_notification" }

      context "without an existing parking_notification" do
        it "builds a parking_notification, falls back to default_bike, and renders the parking_notification template" do
          expect(result[:render]).to eq(template: "/organized_mailer/parking_notification", layout: "email")
          assigns = result[:assigns]
          expect(assigns).to include(kind: kind, organization: organization, email_preview: true)
          expect(assigns[:parking_notification]).to be_a(ParkingNotification)
          expect(assigns[:parking_notification].kind).to eq kind
          expect(assigns[:parking_notification]).to_not be_persisted
          expect(assigns[:bike]).to be_present
        end
      end

      context "with an existing parking_notification" do
        let!(:parking_notification) do
          FactoryBot.create(:parking_notification, organization: organization, kind: kind)
        end
        it "uses the existing parking_notification" do
          expect(result[:assigns][:parking_notification]).to eq parking_notification
          expect(result[:assigns][:bike]).to eq parking_notification.bike
        end
      end

      context "with a parking_notification_id param" do
        let!(:parking_notification) do
          FactoryBot.create(:parking_notification, organization: organization, kind: "parked_incorrectly_notification")
        end
        let(:params) { ActionController::Parameters.new(parking_notification_id: parking_notification.id) }
        let(:kind) { "parked_incorrectly_notification" }

        it "loads the parking_notification by id" do
          expect(result[:assigns][:parking_notification]).to eq parking_notification
        end

        context "for a different organization" do
          let!(:parking_notification) { FactoryBot.create(:parking_notification, kind: "parked_incorrectly_notification") }
          it "raises RecordNotFound" do
            expect { result }.to raise_error(ActiveRecord::RecordNotFound)
          end
        end
      end
    end

    context "with graduated_notification kind" do
      let(:kind) { "graduated_notification" }

      context "without an existing graduated_notification" do
        it "builds a new graduated_notification" do
          expect(result[:render]).to eq(template: "/organized_mailer/graduated_notification", layout: "email")
          assigns = result[:assigns]
          expect(assigns[:graduated_notification]).to be_a(GraduatedNotification)
          expect(assigns[:graduated_notification]).to_not be_persisted
          expect(assigns[:bike]).to be_present
        end
      end

      context "with a graduated_notification_id param" do
        let!(:graduated_notification) { FactoryBot.create(:graduated_notification, organization: organization) }
        let(:params) { ActionController::Parameters.new(graduated_notification_id: graduated_notification.id) }

        it "loads the graduated_notification by id" do
          expect(result[:assigns][:graduated_notification]).to eq graduated_notification
          expect(result[:assigns][:bike]).to eq graduated_notification.bike
        end
      end
    end

    context "with impound_claim_approved kind" do
      let(:kind) { "impound_claim_approved" }

      context "without any impound_records" do
        it "renders the impound_claim template with no impound_claim" do
          expect(result[:render]).to eq(template: "/organized_mailer/impound_claim_approved_or_denied", layout: "email")
          expect(result[:assigns][:impound_claim]).to be_nil
        end
      end

      context "with an impound_record but no claims" do
        let!(:impound_record) { FactoryBot.create(:impound_record_with_organization, organization: organization) }
        it "builds an unsaved impound_claim with the matching status" do
          impound_claim = result[:assigns][:impound_claim]
          expect(impound_claim).to be_a(ImpoundClaim)
          expect(impound_claim).to_not be_persisted
          expect(impound_claim.status).to eq "approved"
          expect(impound_claim.impound_record).to eq impound_record
        end
      end

      context "with an existing approved claim" do
        let!(:impound_claim) { FactoryBot.create(:impound_claim, organization: organization, status: "approved") }
        it "loads the existing claim" do
          expect(result[:assigns][:impound_claim]).to eq impound_claim
        end
      end

      context "for impound_claim_denied" do
        let(:kind) { "impound_claim_denied" }
        let!(:impound_record) { FactoryBot.create(:impound_record_with_organization, organization: organization) }
        it "builds a denied impound_claim" do
          expect(result[:assigns][:impound_claim].status).to eq "denied"
        end
      end
    end

    context "with partial_registration kind" do
      let(:kind) { "partial_registration" }

      context "without any b_params" do
        it "builds a new b_param" do
          expect(result[:render]).to eq(template: "/organized_mailer/partial_registration", layout: "email")
          expect(result[:assigns][:b_param]).to be_a(BParam)
          expect(result[:assigns][:b_param]).to_not be_persisted
          expect(result[:assigns][:b_param].organization_id).to eq organization.id
        end
      end

      context "with an existing b_param" do
        let!(:b_param) { FactoryBot.create(:b_param_with_creation_organization, organization: organization) }
        it "uses the most recent b_param" do
          expect(b_param.reload.organization_id).to eq organization.id
          expect(result[:assigns][:b_param]).to eq b_param
        end
      end
    end

    context "with finished_registration kind" do
      let(:kind) { "finished_registration" }

      it "renders the finished registration component" do
        component = result[:render][:component]
        expect(component).to be_a(Emails::FinishedRegistration::Component)
        expect(result[:render][:layout]).to eq "email"
        assigns = result[:assigns]
        expect(assigns[:bike]).to be_present
        expect(assigns[:ownership]).to eq assigns[:bike].current_ownership
      end

      context "without any organization bikes" do
        it "builds a placeholder bike with id 42" do
          expect(result[:assigns][:bike].id).to eq 42
          expect(result[:assigns][:ownership].id).to eq 420
        end
      end

      context "with an existing organization bike" do
        let!(:bike) { FactoryBot.create(:bike_organized, creation_organization: organization) }
        it "uses the existing bike" do
          expect(result[:assigns][:bike]).to eq bike
        end
      end
    end

    context "with organization_stolen_message kind" do
      let(:kind) { "organization_stolen_message" }

      it "uses default_stolen_bike with a current_stolen_record" do
        expect(result[:render][:component]).to be_a(Emails::FinishedRegistration::Component)
        expect(result[:assigns][:bike].current_stolen_record).to be_present
      end

      context "with an enabled OrganizationStolenMessage" do
        let!(:organization_stolen_message) do
          OrganizationStolenMessage.for(organization).tap { |m| m.update(body: "watch out", is_enabled: true) }
        end
        it "assigns the organization_stolen_message to the stolen_record" do
          expect(result[:assigns][:bike].current_stolen_record.organization_stolen_message).to eq organization_stolen_message
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
