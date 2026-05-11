# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::StravaRequestsRateLimitDetails::Component, type: :component do
  let(:instance) { described_class.new(now:) }
  let(:component) { render_inline(instance) }
  let(:now) { Time.current.utc }

  it "renders rate limit, batch, and headroom" do
    expect(component.text).to include("Rate limit")
    expect(component.text).to include("batch:")
    expect(component.text).to include("headroom:")
  end

  it "renders headroom values" do
    expect(component.text).to include(Integrations::Strava::Client::RATE_LIMIT_HEADROOM.to_s)
    expect(component.text).to include(Integrations::Strava::Client::FETCH_ACTIVITY_SHORT_HEADROOM.to_s)
    expect(component.text).to include(Integrations::Strava::Client::FETCH_ACTIVITY_LONG_HEADROOM.to_s)
    expect(component.text).to include("enqueuer fetch_activity headroom:")
    expect(component.css("i").text).to include("enqueuer")
  end

  context "when more than a minute until short reset" do
    let(:now) { Time.current.utc.change(min: 1, sec: 0) }

    it "shows minutes" do
      expect(component.text).to include("14 mins")
    end
  end

  context "when exactly one minute until short reset" do
    let(:now) { Time.current.utc.change(min: 14, sec: 0) }

    it "shows 1 min" do
      expect(component.text).to include("1 min")
    end
  end

  context "when less than a minute until short reset" do
    let(:now) { Time.current.utc.change(min: 14, sec: 30) }

    it "shows seconds" do
      expect(component.text).to include("30 seconds")
    end
  end

  context "when 1 second until short reset" do
    let(:now) { Time.current.utc.change(min: 14, sec: 59) }

    it "shows 1 second" do
      expect(component.text).to include("1 second")
    end
  end

  it "renders long resets time" do
    expect(component.text).to include("long resets:")
    expect(component.css(".localizeTime")).to be_present
  end
end
