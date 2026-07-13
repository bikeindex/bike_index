# frozen_string_literal: true

require "rails_helper"

RSpec.describe Registrations::New::Heading::Component, type: :component do
  let(:component) { render_inline(described_class.new(title: "Register your bike!", subtitle: "Just the essentials")) }

  it "renders the title and subtitle" do
    expect(component.css("h1").text.strip).to eq "Register your bike!"
    expect(component.css("p").text.strip).to eq "Just the essentials"
  end
end
