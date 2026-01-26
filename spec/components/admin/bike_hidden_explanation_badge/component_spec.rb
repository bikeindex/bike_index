# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::BikeHiddenExplanationBadge::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) { render_inline(instance) }
  let(:options) { {bike:} }
  let(:bike) { Bike.new }

  it "doesn't renders" do
    expect(component.to_html).not_to include("small")
  end

  context "with deleted bike" do
    let(:deleted_at) { Time.current - 1.minute }
    let(:bike) { Bike.new(deleted_at:) }
    it "renders" do
      expect(component).to have_css("small")
      expect(component).to have_content I18n.l(deleted_at, format: :convert_time)
      expect(component).not_to have_text "test"
      expect(component).not_to have_text "user hidden"
    end

    context "also example and user_hidden" do
      let(:bike) { Bike.new(deleted_at:, example: true, user_hidden: true) }

      it "renders" do
        expect(component).to have_css("small")
        expect(component).to have_text "deleted"
        expect(component).to have_content I18n.l(deleted_at, format: :convert_time)
        expect(component).to have_text "user hidden"
        expect(component).to have_text "test"
      end
    end
  end

  context "with user_hidden" do
    let(:bike) { Bike.new(user_hidden: true) }
    it "renders" do
      expect(component).to have_css("small")
      expect(component).to have_content "user hidden"
    end
  end

  context "with example" do
    let(:bike) { Bike.new(example: true) }
    it "renders" do
      expect(component).to have_css("small")
      expect(component).to have_content "test"
      expect(component).not_to have_content "deleted"
    end
  end

  context "with likely_spam" do
    let(:bike) { Bike.new(likely_spam: true) }
    it "renders" do
      expect(component).to have_css("small")
      expect(component).to have_content "spam"
      expect(component).not_to have_content "test"
    end
  end
end
