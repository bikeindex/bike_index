# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Admin::RegistrationSequence::DiscardDraft::Component, type: :component do
  let(:registration_sequence) { FactoryBot.create(:registration_sequence) }

  it "deletes the draft, behind a confirm" do
    rendered = render_inline(described_class.new(registration_sequence:))

    expect(page).to have_css("form[action='/admin/registration_sequences/#{registration_sequence.id}'] button",
      text: "Discard draft")
    expect(page).to have_css("form input[name='_method'][value='delete']", visible: :all)
    expect(rendered.to_html).to include("confirm('Discard this draft and its pages?")
  end

  it "renders for the template's draft too" do
    render_inline(described_class.new(registration_sequence: FactoryBot.create(:registration_sequence_template)))

    expect(page).to have_button("Discard draft")
  end

  context "activated sequence" do
    let(:registration_sequence) { FactoryBot.create(:registration_sequence_active) }

    it "renders nothing - there's no draft to throw away" do
      rendered = render_inline(described_class.new(registration_sequence:))

      expect(rendered.to_html).to be_blank
    end
  end
end
