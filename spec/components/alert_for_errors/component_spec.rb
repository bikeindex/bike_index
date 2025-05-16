# frozen_string_literal: true

require "rails_helper"

RSpec.describe AlertForErrors::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) { render_inline(instance) }
  let(:options) { {object:, name:} }
  let(:object) { OrganizationRole.new }
  let(:name) { nil }

  it "renders" do
    expect(object).to_not be_valid
    pp object.errors.full_messages
    expect(component).to be_present
    expect(instance.render?).to be_truthy
  end

  context "no error" do
    let(:object) { FactoryBot.build(:organization_role) }
    it "doesn't render" do
      expect(object).to be_valid
      expect(instance.render?).to be_falsey
    end
  end
end
