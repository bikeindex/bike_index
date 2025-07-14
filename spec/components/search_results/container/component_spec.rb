# frozen_string_literal: true

require "rails_helper"

RSpec.describe SearchResults::Container::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) { render_inline(instance) }
  let(:options) { {vehicles:, kind:, skip_cache:} }
  let(:vehicles) { [FactoryBot.build(:bike, id: 42)] }
  let(:kind) { :thumbnail }
  let(:skip_cache) { nil }

  it "renders" do
    expect(component).to be_present
    expect(component.css("ul")).to be_present
    expect(component.css("li")).to be_present
    expect(component.css("a").first["href"]).to match("/bikes/42")
  end
end
