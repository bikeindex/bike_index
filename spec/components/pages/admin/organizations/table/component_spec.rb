# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Admin::Organizations::Table::Component, type: :component do
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

  # Action View's template digest can't see the components these cell blocks render, so
  # the row key carries this component's own digest of them
  describe "row caching" do
    include_context :caching_basic

    it "keys each row to its record and this component's markup digest", :caching do
      keys = fragments_written { component }

      expect(keys.count).to eq 1
      expect(keys.first).to include(%(admin-organizations-#{described_class.cache_digest}), organization.cache_key_with_version)
    end
  end
end
