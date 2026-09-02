# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Admin::Bikes::Index::SearchStatuses::Component, type: :component do
  let(:search_params) { {} }
  let(:index) do
    ComponentStructs::IndexState.new(params: search_params,
      sort_state: ComponentStructs::SortState.new(search_params:))
  end
  let(:searched_statuses) { %w[with_owner abandoned impounded] }
  let(:options) { {} }
  let(:component) do
    with_request_url("/admin/bikes") do
      render_inline(described_class.new(index:, searched_statuses:, **options))
    end
  end

  it "renders every status, checking the searched ones, and starts hidden" do
    expect(component.at_css("div")["class"]).to include "tw:hidden"
    expect(component.css("input[type=checkbox]").map { |i| i["name"] })
      .to eq %w[search_status_stolen search_status_with_owner search_status_abandoned
        search_status_impounded search_status_unregistered_parking_notification
        search_status_deleted search_status_spam search_status_example]
    expect(component.css("input[checked]").map { |i| i["name"] })
      .to eq %w[search_status_with_owner search_status_abandoned search_status_impounded]
  end

  it "offers an only link for each status that has one" do
    expect(component.css("a").map { |a| a.text.strip }).to eq %w[only only only]
  end

  context "with non-default statuses" do
    let(:options) { {not_default_statuses: true} }

    # It can't start collapsed when the results aren't the default set - that would hide
    # which statuses they're for
    it "renders open, with a reset link" do
      expect(component.at_css("div")["class"]).to_not include "tw:hidden"
      expect(component).to have_link("reset to default statuses")
    end
  end

  context "on a deleted_only search" do
    let(:searched_statuses) { %w[deleted_only] }

    it "renders the only checkbox instead of the pair" do
      expect(component.css("input[type=checkbox]").map { |i| i["name"] }).to include "search_status_deleted_only"
      expect(component.css("input[type=checkbox]").map { |i| i["name"] }).to_not include "search_status_deleted"
    end
  end

  # Spam is only in the defaults for a superuser with the no_hide_spam option
  context "with spam among the defaults" do
    let(:options) { {default_statuses: %w[spam]} }

    it "marks it on by default, and says why in a tooltip" do
      expect(component).to have_content("on by default")
      expect(component.at_css("[data-controller='ui--tooltip'] [role='tooltip']").text.squish)
        .to eq "enabled because of your superuser settings"
    end
  end

  it "marks nothing on by default when the defaults don't include it" do
    expect(component).to_not have_content("on by default")
  end
end
