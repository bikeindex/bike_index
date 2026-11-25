# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Registrations::Show::CurrentAlerts::NotificationToken::Component, type: :component do
  let(:component) do
    described_class.new(bike:, token:, token_type:, matching_notification: notification)
  end
  let(:bike) { FactoryBot.create(:bike) }
  let(:token) { notification.retrieval_link_token }
  let(:token_type) { "parked_incorrectly_notification" }
  let(:organization) { FactoryBot.create(:organization, name: "Brakebills") }
  let(:notification) { FactoryBot.create(:parking_notification, bike:, organization:, message: "Please move it") }

  it "renders the message and a form to mark it retrieved" do
    render_inline(component)

    expect(page).to have_text("Please move it")
    expect(page).to have_text("Brakebills sent this notification")
    expect(page).to have_css("form[action='/bikes/#{bike.id}/resolve_token']")
    expect(page).to have_css("input[name='token'][value='#{token}']", visible: :all)
    expect(page).to have_css("input[name='token_type'][value='#{token_type}']", visible: :all)
    expect(page).to have_button("Mark bike retrieved")
  end

  context "already resolved" do
    # Retrieving keeps the token, so the link in the email still resolves here
    before { notification.mark_retrieved!(retrieved_kind: "organization_recovery", retrieved_by_id: notification.user_id) }

    it "confirms it's resolved instead of offering the form" do
      render_inline(component)
      expect(page).to have_text("You have marked this notification resolved")
      expect(page).to have_text("no further action necessary")
      expect(page).to_not have_button("Mark bike retrieved")
    end
  end

  context "graduated notification" do
    let(:token_type) { "graduated_notification" }
    let(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: ["graduated_notifications"], graduated_notification_interval: 1.year) }
    let(:bike) { FactoryBot.create(:bike_organized, creation_organization: organization) }
    let(:notification) { FactoryBot.create(:graduated_notification, bike:, organization:) }
    let(:token) { notification.marked_remaining_link_token }

    it "offers to mark the bike remaining" do
      render_inline(component)
      expect(page).to have_button("Mark bike remaining")
    end

    context "already marked remaining" do
      # Graduated says "remaining" — the other arm of resolved_text. Reload because
      # mark_remaining! updates a separate instance loaded inside the job
      before do
        notification.mark_remaining!
        notification.reload
      end

      it "confirms it's resolved instead of offering the form" do
        render_inline(component)
        expect(page).to have_text("You have already marked this bike remaining")
        expect(page).to have_text("no further action necessary")
        expect(page).to_not have_button("Mark bike remaining")
      end
    end
  end

  context "no matching notification" do
    let(:component) { described_class.new(bike:, token: "xxx", token_type:, matching_notification: nil) }

    it "does not render" do
      render_inline(component)
      expect(page.native.text).to be_blank
    end
  end
end
