# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::OrganizationsTable::Component, type: :component do
  it_behaves_like "cached_markup_digest"

  let(:organization) { FactoryBot.create(:organization, name: "Cool Bikes", short_name: "Cool Bikes") }
  let(:render_deleted) { false }
  let(:component) do
    render_inline(described_class.new(organizations: Organization.unscoped.where(id: organization.id), render_deleted:))
  end

  it "renders the organization, and hides the deleted column" do
    expect(component).to have_link("Cool Bikes", href: "http://test.host/admin/organizations/#{organization.to_param}")
    expect(component.to_html).to include ".deleted-col { display: none; }"
  end

  context "with a parent organization" do
    let!(:parent_organization) { FactoryBot.create(:organization, short_name: "Parent Org") }
    before { organization.update(parent_organization:) }

    it "links to the parent" do
      expect(component).to have_link("Parent Org", href: "http://test.host/admin/organizations/#{parent_organization.to_param}")
    end
  end

  context "rendering deleted" do
    let(:render_deleted) { true }
    before { organization.destroy }

    it "shows the deleted column" do
      expect(component.to_html).to_not include ".deleted-col { display: none; }"
      expect(component).to have_css("td.deleted-col .localizeTime")
    end
  end
end
