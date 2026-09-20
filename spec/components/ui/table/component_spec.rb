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
      table.column(label: "Name") { |r| r.name }
      table.column(label: "Email") { |r| r.email }
    end
  end

  it "renders a table with headers and rows" do
    expect(component).to have_css("table")
    expect(component).to have_css("th", text: "Name")
    expect(component).to have_css("th", text: "Email")
    expect(component).to have_css("td", text: "Alice")
    expect(component).to have_css("td", text: "bob@example.com")
    expect(component).to have_css("table.ui-table")
    expect(component).not_to have_css("tfoot")
  end

  context "with a footer" do
    let(:component) do
      render_inline(described_class.new(records:)) do |table|
        table.column(label: "Name", footer: "Total") { |r| r.name }
        table.column(label: "Email") { |r| r.email }
      end
    end

    it "renders one footer cell per column, after the rows" do
      expect(component).to have_css("tfoot tr td", count: 2)
      expect(component).to have_css("tfoot td:first-child", text: "Total")
      expect(component).not_to have_css("tbody td", text: "Total")
    end
  end

  context "with custom classes" do
    let(:component) do
      render_inline(described_class.new(records:, classes: "custom-class")) do |table|
        table.column(label: "Name") { |r| r.name }
      end
    end

    it "includes custom classes on the table" do
      html = component.to_html
      expect(html).to include("custom-class")
      expect(html).to include("min-w-full")
    end
  end

  it "renders components inside column blocks" do
    result = render_inline(described_class.new(records:)) do |table|
      table.column(label: "Name") { |r| r.name }
      table.column(label: "Role") { |r| render(UI::Badge::Component.new(text: "admin", color: :purple, size: :sm)) }
    end

    expect(result).to have_css("th", text: "Name")
    expect(result).to have_css("th", text: "Role")
    expect(result).to have_css("td", text: "Alice")
    expect(result).to have_css("td span", text: "admin")
  end

  context "with sortable columns" do
    before do
      allow_any_instance_of(described_class).to receive(:sortable_url).and_return("/")
    end

    it "renders sortable headers with link class and active state" do
      result = render_inline(described_class.new(records:, render_sortable: true, sort_state: ComponentStructs::SortState.new(sort: "name", direction: "desc"))) do |table|
        table.column(sortable: "name") { |r| r.name }
        table.column(sortable: "email") { |r| r.email }
      end

      expect(result).to have_css("th a.twlink[data-active='true']", text: /Name/)
      expect(result).to have_css("th a.twlink", text: /Email/)
      expect(result).not_to have_css("th a[data-active]", text: /Email/)
    end

    context "with custom label" do
      it "uses label instead of derived title" do
        result = render_inline(described_class.new(records:, render_sortable: true, sort_state: ComponentStructs::SortState.new(sort: "bike_sticker_batch_id"))) do |table|
          table.column(sortable: "bike_sticker_batch_id", label: "Batch") { |r| r.name }
          table.column(sortable: "code_integer", label: "Code #") { |r| r.email }
        end

        expect(result).to have_css("th a.twlink[data-active='true']", text: /Batch/)
        expect(result).not_to have_css("th a", text: /Bike Sticker Batch/)
        expect(result).to have_css("th a.twlink", text: /Code #/)
        expect(result).not_to have_css("th a", text: /Code Integer/)
      end
    end

    context "with sort_indicator on a non-sortable column" do
      it "renders the sort arrow without a link when matching current sort" do
        result = render_inline(described_class.new(records:, render_sortable: true, sort_state: ComponentStructs::SortState.new(sort: "created_at", direction: "desc"))) do |table|
          table.column(sortable: "created_at") { |r| r.name }
          table.column(label: "Date", sort_indicator: "created_at") { |r| r.email }
        end

        # The sort_indicator column shows the arrow but no link
        headers = result.css("th")
        indicator_th = headers[1]
        expect(indicator_th.text).to include("Date")
        expect(indicator_th.text).to include("↓") # down arrow for desc
        expect(indicator_th.css("a")).to be_empty
      end

      it "does not render an arrow when sort_indicator does not match current sort" do
        result = render_inline(described_class.new(records:, render_sortable: true, sort_state: ComponentStructs::SortState.new(sort: "email"))) do |table|
          table.column(sortable: "email") { |r| r.email }
          table.column(label: "Date", sort_indicator: "created_at") { |r| r.name }
        end

        headers = result.css("th")
        indicator_th = headers[1]
        expect(indicator_th.text.strip).to eq("Date")
      end
    end

    context "with render_sortable false" do
      it "renders column labels without sort links" do
        result = render_inline(described_class.new(records:)) do |table|
          table.column(sortable: "created_at") { |r| r.name }
          table.column(sortable: "email") { |r| r.email }
        end

        expect(result).to have_css("th", text: "Created")
        expect(result).not_to have_css("th a")
      end
    end

    context "without explicit sort" do
      it "defaults to first sortable column as active" do
        result = render_inline(described_class.new(records:, render_sortable: true)) do |table|
          table.column(sortable: "created_at") { |r| r.name }
          table.column(sortable: "email") { |r| r.email }
        end

        expect(result).to have_css("th a.twlink[data-active='true']", text: /Created/)
        expect(result).not_to have_css("th a[data-active]", text: /Email/)
      end
    end
  end

  context "with lower_right" do
    it "renders lower_right content in the cell" do
      result = render_inline(described_class.new(records:)) do |table|
        table.column(label: "Email", lower_right: ->(r) { r.name }) { |r| r.email }
      end

      expect(result).to have_css("td div", text: /alice@example.com/)
      expect(result).to have_css("td div small", text: "Alice")
    end
  end

  context "with unbordered" do
    it "removes border-r and border-t classes from th and td" do
      result = render_inline(described_class.new(records:, unbordered: true)) do |table|
        table.column(label: "Name") { |r| r.name }
      end

      expect(result).not_to have_css("th.tw:border-r.tw:border-t")
      expect(result).not_to have_css("td.tw:border-r")
    end
  end

  # Every part of a row's key serves a stale row if it drops out, and nothing about the
  # rendered markup shows which parts are there — so these assert on the keys written
  context "with cache_key", :caching do
    include_context :caching_basic

    let(:users) { FactoryBot.create_list(:user, 2) }

    def render_table(cache_key: "test")
      with_controller_class(ApplicationController) do
        render_inline(described_class.new(records: users, cache_key:)) do |table|
          table.column(label: "Name") { |u| u.name }
          table.column(label: "Email", lower_right: ->(u) { u.id }) { |u| u.email }
        end
      end
    end

    it "writes a fragment per row, scoped to the record, the cache_key and the locale" do
      result = nil
      keys = fragments_written { result = render_table }

      expect(result).to have_css("td", text: users.first.name)
      expect(result).to have_css("td div small", text: users.first.id.to_s)
      expect(keys.count).to eq 2
      expect(keys.first).to include("test", users.first.cache_key_with_version, "locale/en")
      expect(keys.second).to include(users.second.cache_key_with_version)

      expect(fragments_written { render_table }).to eq([])

      # cache_key namespaces the rows, so another table rendering the same records
      # doesn't serve this one's cells
      expect(fragments_written { render_table(cache_key: "other") }.count).to eq 2

      # The version in each record's key is what busts that row when the record changes
      users.first.update(name: "Changed name")
      rewritten = fragments_written { render_table }
      expect(rewritten.count).to eq 1
      expect(rewritten.first).to include(users.first.cache_key_with_version)
    end

    context "in another locale" do
      it "keys the rows to that locale" do
        keys = I18n.with_locale(:nl) { fragments_written { render_table } }

        expect(keys.first).to include("locale/nl")
      end
    end

    context "without a cache_key" do
      it "renders every row uncached" do
        result = nil
        keys = fragments_written { result = render_table(cache_key: nil) }

        expect(keys).to eq([])
        expect(result).to have_css("td", text: users.first.name)
      end
    end
  end

  context "with empty header" do
    it "renders an empty th when label is empty string" do
      result = render_inline(described_class.new(records:)) do |table|
        table.column(label: "Name") { |r| r.name }
        table.column(label: "") { |r| r.email }
      end

      headers = result.css("th")
      expect(headers[0].text.strip).to eq("Name")
      expect(headers[1].text.strip).to eq("")
    end

    it "renders an empty th when no label or sortable provided" do
      result = render_inline(described_class.new(records:)) do |table|
        table.column(label: "Name") { |r| r.name }
        table.column { |r| r.email }
      end

      headers = result.css("th")
      expect(headers[1].text.strip).to eq("")
    end

    it "renders an empty th with sortable column when label is empty string" do
      allow_any_instance_of(described_class).to receive(:sortable_url).and_return("/")

      result = render_inline(described_class.new(records:, render_sortable: true, sort_state: ComponentStructs::SortState.new(sort: "email"))) do |table|
        table.column(sortable: "email", label: "") { |r| r.email }
      end

      # Still renders the sort link, just with no text label
      expect(result).to have_css("th a.twlink")
    end
  end

  context "with a sortable column" do
    it "sets only the plain headers to normal weight" do
      result = render_inline(described_class.new(records:)) do |table|
        table.column(sortable: "name") { |r| r.name }
        table.column(label: "Email") { |r| r.email }
      end

      headers = result.css("th")
      expect(headers[0]["class"]).not_to include("font-normal")
      expect(headers[1]["class"]).to include("font-normal")
    end
  end

  context "with data and row_data" do
    it "writes the table's attributes once, and the row's on every tr" do
      result = render_inline(described_class.new(records:, data: {controller: "roster"},
        row_data: ->(r) { {"roster-target": "row", email: r.email} })) do |table|
        table.column(label: "Name") { |r| r.name }
      end

      expect(result).to have_css("table[data-controller='roster']")
      expect(result).to have_css("tbody tr[data-roster-target='row']", count: 2)
      expect(result).to have_css("tr[data-email='alice@example.com']")
      expect(result).not_to have_css("thead tr[data-roster-target]")
    end
  end

  context "with empty records" do
    let(:records) { [] }

    let(:component) do
      render_inline(described_class.new(records:)) do |table|
        table.column(label: "Name") { |r| r.name }
      end
    end

    it "renders headers but no rows" do
      expect(component).to have_css("th", text: "Name")
      expect(component).not_to have_css("td")
    end
  end
end
