# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::Bikes::Index::SearchStatuses::Component, type: :component do
  let(:search_params) { {} }
  let(:index) do
    ComponentStates::IndexState.new(params: search_params,
      sort_state: ComponentStates::SortState.new(search_params:))
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

  context "with spam on by su_option" do
    let(:options) { {display_dev_info: true, spam_by_su_option: true, default_statuses: %w[spam]} }

    it "says why it is on" do
      expect(component).to have_content("on by default because")
    end
  end
end
