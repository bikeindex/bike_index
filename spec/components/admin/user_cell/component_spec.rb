# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::UserCell::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) { render_inline(instance) }
  let(:options) { {user:} }
  let(:user) { nil }

  context "with user object" do
    let(:user) { FactoryBot.create(:user, email: "test@example.com") }

    it "renders email as link" do
      expect(component.css("a.text-link")).to be_present
      expect(component.css("a[href*='/admin/users/']")).to be_present
      expect(component.text).to include("test@example.com")
      # user_icon helper will render something based on user attributes
      expect(component.to_html).to be_present
    end
  end

  context "with missing user (user_id but no user)" do
    let(:options) { {user_id: 999, email: "missing@example.com"} }

    it "renders missing user warning" do
      expect(component.text).to include("Missing user")
      expect(component).to have_css("small.tw:text-red-800")
      # When email is present, shows email instead of user_id
      expect(component.text).to include("missing@example.com")
    end
  end

  context "with missing user and no email" do
    let(:options) { {user_id: 888} }

    it "renders missing user warning" do
      expect(component.text).to include("Missing user")
      expect(component.text).to include("888")
      expect(component.css("code.small")).to be_present
    end
  end

  context "with email only (no user)" do
    let(:options) { {email: "orphaned@example.com"} }

    it "renders email in span" do
      expect(component.css("span[title='orphaned@example.com']")).to be_present
      expect(component.text).to include("orphaned@example.com")
      expect(component.css("a.text-link")).to be_blank
    end
  end

  context "with long email" do
    let(:long_email) { "very.long.email.address.that.exceeds.thirty.characters@example.com" }
    let(:options) { {email: long_email} }

    it "truncates email display" do
      displayed_text = component.text.strip
      expect(displayed_text.length).to be <= 30
      expect(displayed_text).to end_with("...")
      expect(component.css("span[title='#{long_email}']")).to be_present
    end
  end

  context "without any user data" do
    let(:options) { {} }

    it "renders blank" do
      # With no user, user_icon(nil) returns empty string, component renders completely blank
      expect(component.text.strip).to be_blank
      expect(component.text).not_to include("Missing user")
    end
  end

  context "with user_link_path false" do
    let(:user) { FactoryBot.create(:user, email: "test@example.com") }
    let(:options) { {user:, user_link_path: false} }

    it "does not render email link" do
      expect(component.css("a.text-link")).to be_blank
    end
  end

  context "with custom user_link_path" do
    let(:user) { FactoryBot.create(:user, email: "test@example.com") }
    let(:options) { {user:, user_link_path: "/admin/custom/path"} }

    it "renders email linked to custom path" do
      link = component.css("a.text-link").first
      expect(link).to be_present
      expect(link["href"]).to eq("/admin/custom/path")
      expect(link.text).to include("test@example.com")
    end
  end

  context "with render_search false" do
    let(:user) { FactoryBot.create(:user) }
    let(:options) { {user:, render_search: false} }

    it "renders user email" do
      expect(component.css("a.text-link")).to be_present
      expect(component.css("a.display-sortable-link")).to be_blank
    end
  end
end
