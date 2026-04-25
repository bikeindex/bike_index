# frozen_string_literal: true

require "rails_helper"

RSpec.describe Alerts::ObjectErrors::Component, type: :component do
  let(:component) { render_inline(described_class.new(object:)) }
  let(:object) do
    user = User.new
    user.errors.add(:email, "can't be blank")
    user.errors.add(:password, "is too short")
    user
  end

  it "renders error messages" do
    expect(component).to have_text("2 prevented this User from being saved:")
    expect(component).to have_text("Email can't be blank")
    expect(component).to have_text("Password is too short")
  end

  context "with no errors" do
    let(:object) { User.new }

    it "does not render" do
      expect(component.to_html).to be_blank
    end
  end

  context "with custom name" do
    it "uses custom name" do
      component = render_inline(described_class.new(object:, name: "Account"))
      expect(component).to have_text("prevented this Account from being saved")
    end
  end

  context "with single error" do
    let(:object) do
      user = User.new
      user.errors.add(:email, "can't be blank")
      user
    end

    it "uses singular 'error'" do
      expect(component).to have_text("1 prevented")
    end
  end
end
