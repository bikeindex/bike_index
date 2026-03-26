# frozen_string_literal: true

require "rails_helper"
require "ostruct"

RSpec.describe UI::Table::Component, type: :component do
  let(:records) do
    [
      OpenStruct.new(name: "Alice", email: "alice@example.com"),
      OpenStruct.new(name: "Bob", email: "bob@example.com")
    ]
  end

  let(:component) do
    render_inline(described_class.new(records:)) do |table|
      table.with_column(label: "Name") { |r| r.name }
      table.with_column(label: "Email") { |r| r.email }
    end
  end

  it "renders a table with headers and rows" do
    expect(component).to have_css("table")
    expect(component).to have_css("th", text: "Name")
    expect(component).to have_css("th", text: "Email")
    expect(component).to have_css("td", text: "Alice")
    expect(component).to have_css("td", text: "bob@example.com")
  end

  it "renders with table-overflow controller" do
    expect(component).to have_css("[data-controller='table-overflow']")
  end

  context "with custom classes" do
    let(:component) do
      render_inline(described_class.new(records:, classes: "custom-class")) do |table|
        table.with_column(label: "Name") { |r| r.name }
      end
    end

    it "includes custom classes on the table" do
      html = component.to_html
      expect(html).to include("custom-class")
      expect(html).to include("min-w-full")
    end
  end

  it "renders components inside column blocks" do
    time = Time.zone.parse("2025-06-15 12:00:00")
    records = [OpenStruct.new(name: "Alice", created_at: time)]

    result = render_inline(described_class.new(records:)) do |table|
      table.with_column(label: "Name") { |r| r.name }
      table.with_column(label: "Role") { |r| render(UI::Badge::Component.new(text: "admin", color: :purple, size: :sm)) }
      table.with_column(label: "Created") { |r| render(UI::Time::Component.new(time: r.created_at)) }
    end

    expect(result).to have_css("th", text: "Name")
    expect(result).to have_css("th", text: "Role")
    expect(result).to have_css("th", text: "Created")
    expect(result).to have_css("td", text: "Alice")
    expect(result).to have_css("td span.inline-flex", text: "admin")
    expect(result).to have_css("td span.localizeTime", text: "2025-06-15T12:00:00-0700")
  end

  context "with sortable columns" do
    before { allow_any_instance_of(SortableHelper).to receive(:sortable_url).and_return("/") }

    it "renders sortable headers with link class and active state" do
      result = render_inline(described_class.new(records:, sort: "name", sort_direction: "desc")) do |table|
        table.with_column(sortable: "name") { |r| r.name }
        table.with_column(sortable: "email") { |r| r.email }
      end

      expect(result).to have_css("th a.link.sortable-link.link-active", text: /Name/)
      expect(result).to have_css("th a.link.sortable-link", text: /Email/)
      expect(result).not_to have_css("th a.link-active", text: /Email/)
    end
  end

  context "with cache_key", :caching do
    it "caches each row" do
      users = create_list(:user, 2)
      cache_store = ApplicationController.cache_store

      with_controller_class(ApplicationController) do
        result = render_inline(described_class.new(records: users, cache_key: "test")) do |table|
          table.with_column(label: "Name") { |u| u.name }
          table.with_column(label: "Email") { |u| u.email }
        end

        expect(result).to have_css("td", text: users.first.name)
        expect(result).to have_css("td", text: users.second.email)
        expect(cache_store.instance_variable_get(:@data).size).to eq(2)
      end
    end

    it "namespaces cache keys with a string" do
      users = create_list(:user, 1)
      cache_store = ApplicationController.cache_store

      with_controller_class(ApplicationController) do
        render_inline(described_class.new(records: users, cache_key: "view-a")) do |table|
          table.with_column(label: "Name") { |u| u.name }
        end

        render_inline(described_class.new(records: users, cache_key: "view-b")) do |table|
          table.with_column(label: "Name") { |u| u.name }
        end

        # Same record, different namespace — should produce 2 separate cache entries
        expect(cache_store.instance_variable_get(:@data).size).to eq(2)
      end
    end
  end

  context "with empty records" do
    let(:records) { [] }

    let(:component) do
      render_inline(described_class.new(records:)) do |table|
        table.with_column(label: "Name") { |r| r.name }
      end
    end

    it "renders headers but no rows" do
      expect(component).to have_css("th", text: "Name")
      expect(component).not_to have_css("td")
    end
  end
end
