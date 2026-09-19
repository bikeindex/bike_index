# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Admin::RegistrationSequence::Table::Component, type: :component do
  let(:organization) { FactoryBot.create(:organization) }
  let(:registration_sequence) { FactoryBot.create(:registration_sequence, :with_pages, organization:) }
  let(:sort_state) { ComponentStructs::SortState.new }
  let(:component) do
    render_inline(described_class.new(registration_sequences: [registration_sequence], sort_state:))
  end

  it "links the sequence, with a search for its organization" do
    expect(component).to have_link(href: "/admin/registration_sequences/#{registration_sequence.id}")
    expect(component).to have_link(href: "/admin/registration_sequences?organization_id=#{organization.id}")
  end

  context "with search params" do
    let(:sort_state) do
      ComponentStructs::SortState.new(search_params: {search_status: "draft"}, sort: nil, direction: nil)
    end

    it "keeps them in the organization search" do
      expect(component).to have_link(
        href: "/admin/registration_sequences?organization_id=#{organization.id}&search_status=draft"
      )
    end
  end

  context "template" do
    let(:registration_sequence) { FactoryBot.create(:registration_sequence_template) }

    it "renders without an organization" do
      expect(component).to have_link(href: "/admin/registration_sequences/#{registration_sequence.id}")
      expect(component).to_not have_link(href: /organization_id/)
    end
  end
end
