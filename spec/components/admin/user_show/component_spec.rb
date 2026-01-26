# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::UserShow::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) { render_inline(instance) }
  let(:options) { {user:, bikes:, bikes_count:} }
  let(:user) { nil }
  let(:bikes) { nil }
  let(:bikes_count) { nil }

  it "renders" do
    expect(component).to have_css("div")
  end
end
