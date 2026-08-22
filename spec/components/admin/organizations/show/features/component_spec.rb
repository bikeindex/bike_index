# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::Organizations::Show::Features::Component, type: :component do
  # regional_ids is derived from geography on save, so the two have to share a location and
  # the parent has to be touched after the child exists
  let!(:organization) { FactoryBot.create(:organization, :in_nyc) }
  let!(:regional_parent) do
    FactoryBot.create(:organization_with_regional_bike_counts, :in_nyc, name: "Regional Overview")
      .tap { |parent| parent.update(updated_at: Time.current) }
  end

  def regional_lookups
    queries = []
    subscription = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      queries << payload[:sql] if payload[:sql].include?("regional_ids @>")
    end
    yield
    queries.count
  ensure
    ActiveSupport::Notifications.unsubscribe(subscription)
  end

  # regional_ids has no index, so every call is a seq scan. The memo exists for that, and
  # the template asks four times - it went straight to the organization once already
  it "looks the regional parents up once, however often the template asks" do
    count = regional_lookups do
      render_inline(described_class.new(organization:))
    end

    expect(page).to have_link("Regional Overview")
    expect(count).to eq 1
  end
end
