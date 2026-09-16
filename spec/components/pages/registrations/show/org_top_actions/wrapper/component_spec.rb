# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Registrations::Show::OrgTopActions::Wrapper::Component, type: :component do
  let(:enabled_feature_slugs) { %w[unstolen_notifications impound_bikes parking_notifications] }
  let(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs:) }
  let(:status) { :status_with_owner }
  let(:bike) { Bike.new(status:, cycle_type: "bike") }
  let(:org_role) { :staff }
  let(:current_user) { nil }

  # The action buttons, named by the panel each one opens
  def action_panels
    render_inline(described_class.new(bike:, organization:, org_role:, current_user:))
    page.all("[data-registrations--show--action-panels-target='trigger']").map { |trigger| trigger["data-panel-name"] }
  end

  it "renders every action" do
    expect(action_panels).to eq(%w[message impound parking notifications_show])
    expect(page).to have_button("Message Owner")
    expect(page).to have_button("Impound", exact: true)
    expect(page).to have_button("New Parking Notification")
    expect(page).to have_button("View Notifications")
  end

  context "when limited" do
    let(:org_role) { :limited }

    it "renders everything but impound" do
      expect(action_panels).to eq(%w[message parking notifications_show])
    end
  end

  context "when the organization has no features" do
    let(:organization) { FactoryBot.create(:organization) }

    it "renders no actions" do
      expect(action_panels).to eq([])
    end
  end

  context "when impounded" do
    let(:status) { :status_impounded }
    let(:impound_organization_id) { organization.id }
    let(:impound_record) { ImpoundRecord.new(organization_id: impound_organization_id, display_id: "0001") }
    let(:bike) { Bike.new(status:, cycle_type: "bike", current_impound_record: impound_record) }

    # The owner isn't messageable, and there's no point filing a parking
    # notification against a bike that's already impounded
    it "renders the impound update" do
      expect(action_panels).to eq(%w[impound_update notifications_show])
      expect(page).to have_button("Update Impound Record")
    end

    context "and limited" do
      let(:org_role) { :limited }

      it "renders no impound update" do
        expect(action_panels).to eq(%w[notifications_show])
      end
    end

    context "by another organization" do
      let(:impound_organization_id) { FactoryBot.create(:organization).id }

      it "renders no impound update" do
        expect(action_panels).to eq(%w[notifications_show])
      end
    end

    # An unorganized impound record has a nil display_id, so rendering the form
    # raised UrlGenerationError rather than just linking to the wrong org
    context "by no organization" do
      let(:impound_record) { ImpoundRecord.new }

      it "renders no impound update" do
        expect(action_panels).to eq(%w[notifications_show])
      end
    end
  end

  # An impounded vehicle is neither stolen nor with its owner, so neither of the other
  # two branches reaches it — the allowance on the impound record is what opens the panel
  context "when impounded, viewed by a trusted organization's staff" do
    let(:finder) { FactoryBot.create(:user_confirmed, phone: "7183914410") }
    let(:bike) { FactoryBot.create(:bike, :impounded, :with_ownership_claimed, user: finder).reload }
    let(:current_user) { FactoryBot.create(:organization_role_claimed, organization:).user.reload }

    it "renders the message action, and the panel asks what they need" do
      expect(bike.current_impound_record.contactable_without_claiming?(current_user)).to be_truthy
      expect(action_panels).to include("message")
      expect(page).to have_button("Message Owner")
      expect(page).to have_text("Know who has this bike?")
      expect(page).to have_link("718-391-4410", href: "tel:718-391-4410")
    end

    context "and limited" do
      let(:org_role) { :limited }

      it "renders no message action" do
        expect(action_panels).to_not include("message")
        expect(page).to_not have_text("Know who has this bike?")
      end
    end

    context "whose organization is trusted with nothing" do
      let(:organization) { FactoryBot.create(:organization) }

      it "renders no message action" do
        expect(bike.current_impound_record.contactable_without_claiming?(current_user)).to be_falsey
        expect(action_panels).to_not include("message")
      end
    end

    # The allowance sits above the opt-out, which covers their own registrations
    context "whose holder declined unstolen notifications" do
      let(:finder) { FactoryBot.create(:user_confirmed, notification_unstolen: false) }

      it "still renders the message action" do
        expect(action_panels).to include("message")
      end
    end

    # They're the ones holding it, so there's nobody to reach - they act on it through
    # the update action instead
    context "impounded by the viewing organization" do
      let(:bike) { FactoryBot.create(:impound_record_with_organization, organization:, display_id: "0001").bike.reload }

      it "renders the impound update rather than the message action" do
        expect(bike.current_impound_record.organization_id).to eq organization.id
        expect(action_panels).to_not include("message")
        expect(action_panels).to include("impound_update")
      end
    end
  end

  context "without unstolen_notifications" do
    let(:enabled_feature_slugs) { %w[impound_bikes parking_notifications] }

    it "renders no message action" do
      expect(action_panels).to eq(%w[impound parking notifications_show])
    end

    context "and stolen" do
      let(:bike) { Bike.new(status: :status_stolen, cycle_type: "bike", current_stolen_record: StolenRecord.new) }

      # A stolen bike's owner is messageable without the feature
      it "renders the message action" do
        expect(action_panels).to eq(%w[message impound parking notifications_show])
      end
    end
  end
end
