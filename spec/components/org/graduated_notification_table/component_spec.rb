# frozen_string_literal: true

require "rails_helper"

RSpec.describe Org::GraduatedNotificationTable::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) do
    with_request_url("/o/#{organization.to_param}/graduated_notifications") do
      unless vc_test_controller.class.method_defined?(:sort_column)
        vc_test_controller.class.define_method(:sort_column) { "created_at" }
        vc_test_controller.class.define_method(:sort_direction) { "desc" }
        vc_test_controller.class.helper_method :sort_column, :sort_direction
      end
      render_inline(instance)
    end
  end
  let(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: ["graduated_notifications"], graduated_notification_interval: 1.year) }
  let(:graduated_notification) { FactoryBot.create(:graduated_notification, organization:) }
  let(:options) do
    {
      graduated_notifications: [graduated_notification],
      current_organization: organization
    }
  end

  it "renders the table with the notification row" do
    expect(component).to have_css("table")
    expect(component).to have_css("tbody tr", count: 1)
    expect(component).to have_content(graduated_notification.email)
    expect(component).to have_content("Status")
    link_id = graduated_notification.primary_notification_id.presence || graduated_notification.id
    expect(component).to have_link(href: Rails.application.routes.url_helpers.organization_graduated_notification_path(link_id, organization_id: organization.id))
  end

  context "with skip_email and render_remaining_at" do
    let(:options) { super().merge(skip_email: true, render_remaining_at: true) }

    it "omits the email column and includes the remaining column header" do
      expect(component).not_to have_content(graduated_notification.email)
      expect(component).to have_content("Marked Not Graduated")
    end
  end

  context "with separate_secondary_notifications" do
    let(:options) { super().merge(separate_secondary_notifications: true) }

    it "renders the Primary? column" do
      expect(component).to have_content("Primary?")
    end
  end

  context "with skip_status" do
    let(:options) { super().merge(skip_status: true) }

    it "omits the status column header" do
      expect(component).not_to have_content("Status")
    end
  end
end
