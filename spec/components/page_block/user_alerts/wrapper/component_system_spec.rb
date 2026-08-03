# frozen_string_literal: true

require "rails_helper"

RSpec.describe PageBlock::UserAlerts::Wrapper::Component, :js, type: :system do
  # These carry the alerts rather than being one - the wrapper picks between them, and the
  # other two are the chrome the interrupting and non-interrupting alerts share
  let(:carriers) { %w[banner bike_list_modal wrapper] }

  # Text that only appears once that alert rendered, keyed by the component's directory
  # so the keys can be checked against what's on disk
  let(:alert_text) do
    {"phone_waiting_confirmation" => "Confirm your phone number",
     "stolen_bike_without_location" => "Please add theft location",
     "theft_alert_without_photo" => "Please add a photo",
     "unfinished_registration" => "Finish registering your"}
  end

  let(:preview_path) { "/rails/view_components/page_block/user_alerts/wrapper/component" }

  def alert_names
    Rails.root.glob("app/components/page_block/user_alerts/*")
      .select(&:directory?).map { |dir| dir.basename.to_s }.sort - carriers
  end

  it "has a preview scenario and a spec for every kind of alert" do
    scenarios = PageBlock::UserAlerts::Wrapper::ComponentPreview.public_instance_methods(false).map(&:to_s)

    # The wrapper switches on general_kinds, so a kind there with no component renders nothing
    expect(alert_names).to eq UserAlert.general_kinds.sort
    expect(alert_names).to eq alert_text.keys.sort
    alert_names.each do |alert|
      expect(scenarios).to include(alert), "UserAlerts::#{alert.camelize} has no preview scenario"
      spec = Rails.root.join("spec/components/page_block/user_alerts/#{alert}/component_spec.rb")
      expect(spec.exist?).to be_truthy, "UserAlerts::#{alert.camelize} has no component spec"
    end
  end

  it "renders the alert each scenario is named for, and none of the others" do
    alert_text.each do |scenario, text|
      visit "#{preview_path}/#{scenario}"

      expect(page).to have_content(text)
      alert_text.except(scenario).each_value { |other| expect(page).to have_no_content(other) }
    end
  end
end
