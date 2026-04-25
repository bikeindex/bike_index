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
      result = render_inline(described_class.new(records:, render_sortable: true, sort: "name", sort_direction: "desc")) do |table|
        table.column(sortable: "name") { |r| r.name }
        table.column(sortable: "email") { |r| r.email }
      end

      expect(result).to have_css("th a.twlink.active", text: /Name/)
      expect(result).to have_css("th a.twlink", text: /Email/)
      expect(result).not_to have_css("th a.active", text: /Email/)
    end

    context "with custom label" do
      it "uses label instead of derived title" do
        result = render_inline(described_class.new(records:, render_sortable: true, sort: "bike_sticker_batch_id")) do |table|
          table.column(sortable: "bike_sticker_batch_id", label: "Batch") { |r| r.name }
          table.column(sortable: "code_integer", label: "Code #") { |r| r.email }
        end

        expect(result).to have_css("th a.twlink.active", text: /Batch/)
        expect(result).not_to have_css("th a", text: /Bike Sticker Batch/)
        expect(result).to have_css("th a.twlink", text: /Code #/)
        expect(result).not_to have_css("th a", text: /Code Integer/)
      end
    end

    context "with sort_indicator on a non-sortable column" do
      it "renders the sort arrow without a link when matching current sort" do
        result = render_inline(described_class.new(records:, render_sortable: true, sort: "created_at", sort_direction: "desc")) do |table|
          table.column(sortable: "created_at") { |r| r.name }
          table.column(label: "Date", sort_indicator: "created_at") { |r| r.email }
        end

        # The sort_indicator column shows the arrow but no link
        headers = result.css("th")
        indicator_th = headers[1]
        expect(indicator_th.text).to include("Date")
        expect(indicator_th.text).to include("\u2193") # down arrow for desc
        expect(indicator_th.css("a")).to be_empty
      end

      it "does not render an arrow when sort_indicator does not match current sort" do
        result = render_inline(described_class.new(records:, render_sortable: true, sort: "email")) do |table|
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

        expect(result).to have_css("th a.twlink.active", text: /Created/)
        expect(result).not_to have_css("th a.active", text: /Email/)
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

  context "with cache_key", :caching do
    include_context :caching_basic

    it "caches each row" do
      users = FactoryBot.create_list(:user, 2)

      with_controller_class(ApplicationController) do
        result = render_inline(described_class.new(records: users, cache_key: "test")) do |table|
          table.column(label: "Name") { |u| u.name }
          table.column(label: "Email") { |u| u.email }
        end

        expect(result).to have_css("td", text: users.first.name)
        expect(result).to have_css("td", text: users.second.email)
      end
    end

    it "caches rows with lower_right content" do
      users = FactoryBot.create_list(:user, 2)

      with_controller_class(ApplicationController) do
        result = render_inline(described_class.new(records: users, cache_key: "lr-test")) do |table|
          table.column(label: "Email", lower_right: ->(u) { u.id }) { |u| u.email }
        end

        expect(result).to have_css("td div", text: /#{users.first.email}/)
        expect(result).to have_css("td div small", text: users.first.id.to_s)
      end
    end

    it "namespaces cache keys with a string" do
      users = FactoryBot.create_list(:user, 1)

      with_controller_class(ApplicationController) do
        render_inline(described_class.new(records: users, cache_key: "view-a")) do |table|
          table.column(label: "Name") { |u| u.name }
        end

        render_inline(described_class.new(records: users, cache_key: "view-b")) do |table|
          table.column(label: "Name") { |u| u.name }
        end
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

      result = render_inline(described_class.new(records:, render_sortable: true, sort: "email")) do |table|
        table.column(sortable: "email", label: "") { |r| r.email }
      end

      # Still renders the sort link, just with no text label
      expect(result).to have_css("th a.twlink")
    end
  end

  context "with header_classes font-normal" do
    it "adds font-normal class to th" do
      result = render_inline(described_class.new(records:)) do |table|
        table.column(label: "Name") { |r| r.name }
        table.column(label: "Email", header_classes: "tw:font-normal") { |r| r.email }
      end

      headers = result.css("th")
      expect(headers[0]["class"]).not_to include("font-normal")
      expect(headers[1]["class"]).to include("font-normal")
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
