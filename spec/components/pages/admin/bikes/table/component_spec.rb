# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Admin::Bikes::Table::Component, type: :component do
  let(:bike) { FactoryBot.create(:bike, :with_ownership, manufacturer: Manufacturer.other, manufacturer_other: "Cool Bikes") }
  let(:component) do
    with_controller_class(Admin::BikesController) do
      with_request_url("/admin/bikes") { render_inline(described_class.new(bikes: [bike])) }
    end
  end

  it "renders a row for each bike" do
    expect(component).to have_css("td", text: "Cool Bikes")
    expect(component).to have_css("td", text: bike.owner_email)
  end

  describe "row cache key" do
    include_context :caching_basic

    # The cells UI::Table caches live in this component's template, where Action View's
    # own template digest can't reach them — so the key carries cache_digest, which
    # ViewComponent::ExperimentallyCacheable builds by putting each component this one
    # renders into Action View's digest tree. A version that stops doing that leaves the
    # digest still present and still stale, so assert on the tree rather than the digest.
    it "carries a digest of every component the rows render", :caching do
      keys = []
      subscriber = ActiveSupport::Notifications.subscribe("write_fragment.action_controller") do |_name, _start, _finish, _id, payload|
        keys << ActiveSupport::Cache.expand_cache_key(payload[:key])
      end
      component
      ActiveSupport::Notifications.unsubscribe(subscriber)

      expect(keys.count).to eq 1
      expect(keys.first).to include("admin-bikes-#{described_class.cache_digest}", bike.cache_key_with_version)

      expect(digest_dependencies).to include(
        "ui/table/component", "ui/time/component", "pages/admin/users/cell/component",
        "atoms/admin/badges/bike_hidden_explanation/component",
        "atoms/registration_status_badge/component", "atoms/org/origin_display/component",
        # No cell renders this one — it's reached through the two badges above, so it
        # only appears when the tree is followed transitively
        "ui/badge/component"
      )
    end

    private

    # Every component Action View's digest tree reaches from this one. Named through
    # ViewComponent's own seam rather than a literal path, so a release that moves the
    # seam fails here instead of silently digesting nothing.
    def digest_dependencies
      finder = ActionView::LookupContext.new(ActionController::Base.view_paths)
      tree = ActionView::Digestor.tree(ViewComponent::CacheDigest.virtual_path_for(described_class), finder)
      flattened_dependencies(tree.to_dep_map)
        .map { |name| name.delete_prefix("#{ViewComponent::CacheDigest::VIRTUAL_PATH_PREFIX}/") }
    end

    # to_dep_map nests a hash per node that has children, and a bare name per leaf
    def flattened_dependencies(dependencies)
      Array.wrap(dependencies).flat_map do |dependency|
        next dependency unless dependency.is_a?(Hash)

        dependency.flat_map { |name, children| [name, *flattened_dependencies(children)] }
      end
    end
  end
end
