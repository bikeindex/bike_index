# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Bikebook", :js, type: :system do
  let(:fixtures) { Rails.root.join("spec/fixtures/bikebook_catalog") }

  # A fixture catalog in place of the published one, and no stock photos, which render
  # their placeholder
  def serve_catalog(manifest_status: 200)
    page.driver.with_playwright_page do |playwright_page|
      playwright_page.context.route(%r{^https://bikebook-catalog\.bikeindex\.org/catalog/}, ->(route, request) {
        path = request.url.delete_prefix("https://bikebook-catalog.bikeindex.org/catalog/")
        status = (path == "manifest.json") ? manifest_status : 200
        route.fulfill(status:, headers: {"access-control-allow-origin" => "*", "content-type" => "application/json"},
          body: (status == 200) ? fixtures.join(path).read : "")
      })
      playwright_page.context.route(%r{^https://bikebook\.bikeindex\.org/}, ->(route, _request) { route.abort })
    end
  end

  def vehicle_field = find_field("View a vehicle")

  # A component's markup from the server beside its template's from the browser, as canonical_html.js's
  # lines. `args` is the template's argument as JavaScript source, with lit-html's `html` in scope
  def expect_template(component, template, args)
    server = component.is_a?(String) ? component : ApplicationController.render(component, layout: false)
    page.execute_script(Rails.root.join("spec/support/canonical_html.js").read)
    server_lines, browser_lines = page.evaluate_script(<<~JS)
      (async (template, server) => {
        const [module, name] = template.split('#')
        const [{ html, render }, templates] = await Promise.all([import('lit-html'), import(module)])
        const container = document.createElement('div')
        render(templates[name](#{args}), container)
        return [window.canonicalHtml(server), window.canonicalHtml(container.innerHTML)]
      })(#{template.to_json}, #{server.to_json})
    JS
    expect(browser_lines).to eq(server_lines), "#{template} renders differently from its component with #{args}"
  end

  it "searches, compares and filters the catalog in the browser, a pick and each history step rendering without a request" do
    serve_catalog
    asked = []
    page.driver.with_playwright_page do |playwright_page|
      playwright_page.on("request", ->(request) { asked << request.url if request.navigation_request? })
    end
    visit bikebook_path
    # the search is an unusable placeholder until the catalog loads
    expect(page).to have_no_css("[inert]", wait: 10)
    asked.clear

    vehicle_field.click
    expect(page).to have_css(".hw-combobox__group__label", text: /\(29 matching models\)/i)

    type_into(vehicle_field, "level 4 rec")
    expect(page).to have_css(".hw-combobox__group__label", text: /\(2 matching models\)/i)
    retry_on_detach { find("[role='option']", text: "Aventón Level 4 REC Step-Through").click }
    expect(page).to have_css("article h1", text: "Level 4 REC Step-Through")
    expect(page).to have_title(/Aventón Level 4 REC Step-Through/)
    expect(page).to have_css(".hw-combobox__chip", text: "Aventón Level 4 REC Step-Through")
    expect(page).to have_current_path("/bikebook?vehicle_models=m/aventon/2026/level_4_rec_step_through")

    # A second pick, found by its id, compares the two. The comparison view tables them, each against
    # the first, and highlights where the second's card differs
    type_into(vehicle_field, "level_2_step")
    expect(page).to have_css(".hw-combobox__group__label", text: /\(1 matching model\)/i)
    retry_on_detach { find("[role='option']", text: "Aventón Level 2 Step-Through").click }
    expect(page).to have_css("article", count: 2)
    expect(page).to have_current_path("/bikebook?vehicle_models=m/aventon/2026/level_4_rec_step_through,m/aventon/2022/level_2_step_through")
    expect(page).to have_no_css("[data-comparison] .tw\\:spec-diff")

    click_on "Comparison view"
    expect(page).to have_css("#comparison-view[aria-pressed='true']")
    expect(page).to have_css("[data-comparison] article", count: 2)
    expect(page).to have_current_path(/view=comparison/)
    expect(all("article").last).to have_css(".tw\\:spec-diff")
    expect(all("article").first).to have_no_css(".tw\\:spec-diff")
    within("[aria-label='Comparison']") do
      expect(page).to have_css("thead th", text: "Level 2 Step-Through")
      expect(find("tr", text: "Price")).to have_css(".tw\\:text-green-700", text: "−$1,000")
      expect(find("tr", text: "Range")).to have_css(".tw\\:text-red-700", text: "−24")
      expect(find("tr", text: "Top speed")).to have_css("td span", exact_text: "-")
    end

    find("[aria-label='Remove Aventón Level 2 Step-Through']").click
    expect(page).to have_css("[data-comparison] article", count: 1)
    expect(page).to have_css(".hw-combobox__chip", count: 1)

    page.go_back
    expect(page).to have_css("article", count: 2)
    expect(page).to have_css(".hw-combobox__chip", count: 2)

    # The JSON panel opens beside its card
    first("[aria-label='Toggle JSON']").click
    expect(page).to have_css(".twjson-panel code", text: '"model": "Level 4 REC Step-Through"')

    # A filter's options count the catalog's models, and its chips come from them
    click_on "More filters"
    find_field("Manufacturer").click
    find("#manufacturer-hw-listbox [role='option']", text: "Kris Holm (5)").click
    expect(page).to have_css("[data-async-id='manufacturer'] .hw-combobox__chip", text: "Kris Holm")
    expect(page).to have_css("#vehicle-models-count", exact_text: "(5 matching models)")

    expect(asked).to be_empty

    # Five compare, wrapping onto rows unless the comparison view lines them up side by side
    page.current_window.resize_to(1440, 900)
    five = %w[m/aventon/2026/level_4_rec_step_through m/aventon/2022/level_2_step_through m/segway/2025/gt3_pro
      m/specialized/2025/haul_st m/sur_ron/2026/ultra_bee_hp_x_us].join(",")
    card_rows = -> { page.evaluate_script("new Set([...document.querySelectorAll('article')].map((card) => Math.round(card.getBoundingClientRect().top))).size") }
    visit bikebook_path(vehicle_models: five)
    expect(page).to have_css("article", count: 5, wait: 10)
    expect(card_rows.call).to be > 1

    click_on "Comparison view"
    # the label column's header and the five vehicles'
    expect(page).to have_css("[aria-label='Comparison'] thead th", count: 6)
    expect(page).to have_css("[data-comparison] article", count: 5)
    expect(card_rows.call).to eq 1
    expect(page.evaluate_script("document.querySelector('[data-comparison] > div').scrollWidth > window.innerWidth")).to be true
    page.current_window.resize_to(1920, 1080)
  end

  it "keeps each compared vehicle in a size, the others following the first's unless picked, and remembers them" do
    serve_catalog
    visit bikebook_path(vehicle_models: "m/aventon/2026/current_adv,m/aventon/2026/current_exp", view: "comparison")
    expect(page).to have_css("[aria-label='Comparison'] tbody tr:first-child th", text: "Size", wait: 10)

    # sizes no fixture has: medium by default, a name read the ways it's written, the first's size for the rest
    chosen = page.evaluate_script(<<~JS)
      (async () => {
        const { chosenSizes } = await import('bikebook/sizes')
        const vehicle = (value, ...names) => ({ value, data: { sizes: names.map((name) => ({ name })) } })
        const names = (vehicles, stored) => chosenSizes(vehicles, stored).map((size) => size?.name ?? 'none')
        return [
          names([vehicle('a', 'S', 'M', 'L'), vehicle('b', 'Regular', 'Large'), vehicle('c', 'S/M', 'M/L'), vehicle('d')]),
          names([vehicle('a', 'Small', 'Medium'), vehicle('b', 'XS', 'S', 'M'), vehicle('c', 'MD', 'LG')], { preferred: 'Small', picked: { c: 'LG' } }),
          names([vehicle('a', 'S', 'M', 'L'), vehicle('b', '52', '54', '56')], { preferred: 'L' })
        ]
      })()
    JS
    expect(chosen).to eq([["M", "Regular", "S/M", "none"], ["Small", "S", "LG"], ["L", "54"]])

    # a rendered size is its option's selected attribute, which a pick alone doesn't set, so it waits out the render
    size_select = ->(model) { find("select[aria-label='Size of #{model}']") }
    expect_size = ->(model, size) { expect(page).to have_css("select[aria-label='Size of #{model}'] option[selected]", exact_text: size) }
    expect_size.call("Current ADV", "Medium")
    expect_size.call("Current EXP", "Medium")

    size_select.call("Current ADV").select("Large")
    expect_size.call("Current EXP", "Large")

    size_select.call("Current EXP").select("Small")
    expect_size.call("Current EXP", "Small")
    size_select.call("Current ADV").select("Extra Large")
    expect_size.call("Current ADV", "Extra Large")
    expect_size.call("Current EXP", "Small")
    # the geometry is each one's size, under its own heading, its differences neither better nor worse
    expect(page).to have_css("[aria-label='Comparison'] tbody:last-child tr:first-child th[scope='rowgroup']", text: /\Ageometry\z/i)
    expect(find("[aria-label='Comparison'] tbody:last-child tr", text: "Reach")).to have_css("td", text: /\A425\.5.+−74\.7/m)
      .and have_css(".tw\\:text-gray-500", text: "−74.7")

    visit current_url
    expect(page).to have_css("[aria-label='Comparison']", wait: 10)
    expect_size.call("Current ADV", "Extra Large")
    expect_size.call("Current EXP", "Small")
    # each card's geometry rings its size
    current_size = ->(model) { find("article h1", exact_text: model).ancestor("article").all("[aria-current='true'] h3", visible: :all).map { it.text(:all) } }
    expect(current_size.call("Current ADV")).to eq(["Extra Large"])
    expect(current_size.call("Current EXP")).to eq(["Small"])

    type_into(vehicle_field, "soltera")
    retry_on_detach { find("[role='option']", text: "Aventón Soltera 3 ADV").click }
    expect_size.call("Soltera 3 ADV", "Extra Large")
    expect_size.call("Current EXP", "Small")
  end

  it "renders each UI template as the component it mirrors does" do
    serve_catalog
    visit bikebook_path

    aggregate_failures do
      expect_template(UI::Tooltip::Component.new(text: "622 mm BSD"), "bikebook/templates/ui/tooltip#tooltip", "{ text: '622 mm BSD' }")
      expect_template(UI::Tooltip::Component.new(text: "#ff0000").with_content("<span>red</span>".html_safe),
        "bikebook/templates/ui/tooltip#tooltip", "{ text: '#ff0000', content: html`<span>red</span>` }")
      expect_template(UI::Tooltip::Component.new.with_body_content("<em>Internal</em> routing".html_safe),
        "bikebook/templates/ui/tooltip#tooltip", "{ body: html`<em>Internal</em> routing` }")

      expect_template(UI::IconChevron::Component.new(size: :md), "bikebook/templates/ui/icon_chevron#iconChevron", "{ size: 'md' }")

      expect_template(UI::Collapse::Component.new(size: :sm, html_class: "tw:shrink-0", aria: {controls: "vehicle-model-json-1", label: "Toggle JSON"})
        .with_content("<code>{ }</code>".html_safe), "bikebook/templates/ui/collapse#collapse", <<~JS)
          { size: 'sm', htmlClass: 'tw:shrink-0', content: html`<code>{ }</code>`,
            attributes: { 'aria-controls': 'vehicle-model-json-1', 'aria-label': 'Toggle JSON' } }
        JS
      expect_template(UI::Collapse::Component.new(chevron: true, size: :sm, aria: {label: "Toggle sizes"}),
        "bikebook/templates/ui/collapse#collapse", "{ chevron: true, size: 'sm', attributes: { 'aria-label': 'Toggle sizes' } }")

      expect_template(UI::CopyableCode::Component.new(value: "m/trek/2025/fetch", label: "Copy ID"),
        "bikebook/templates/ui/copyable_code#copyableCode", "{ value: 'm/trek/2025/fetch', label: 'Copy ID' }")

      expect_template(UI::JsonDisplay::Component.new(data: {model: "Level 2", years: [2022]}, small: true, no_max_height: true),
        "bikebook/templates/ui/json_display#jsonDisplay", "{ data: { model: 'Level 2', years: [2022] }, small: true, noMaxHeight: true }")
      expect_template(UI::JsonDisplay::Component.new(data: {}), "bikebook/templates/ui/json_display#jsonDisplay", "{ data: {} }")

      expect_template(UI::DefinitionList::Container::Component.new.with_content("<div>row</div>".html_safe),
        "bikebook/templates/ui/definition_list/container#definitionListContainer", "{ content: html`<div>row</div>` }")
      expect_template(UI::DefinitionList::Container::Component.new(term: :right_align).with_content("<div>row</div>".html_safe),
        "bikebook/templates/ui/definition_list/container#definitionListContainer", "{ term: 'right_align', content: html`<div>row</div>` }")

      expect_template(UI::DefinitionList::Row::Component.new(label: "Frame material", value: "Aluminum"),
        "bikebook/templates/ui/definition_list/row#definitionListRow", "{ label: 'Frame material', value: 'Aluminum' }")
      expect_template(UI::DefinitionList::Row::Component.new(label: "Years").with_content("<b>2025</b>".html_safe),
        "bikebook/templates/ui/definition_list/row#definitionListRow", "{ label: 'Years', content: html`<b>2025</b>` }")
      expect_template(UI::DefinitionList::Row::Component.new(label: "Markets", value: ""),
        "bikebook/templates/ui/definition_list/row#definitionListRow", "{ label: 'Markets', value: '' }")

      table = ApplicationController.render(inline: <<~ERB, layout: false, locals: {rows: [{type: "Disc", position: "Front"}, {type: "Rim", position: "Rear"}]})
        <%= render(UI::Table::Component.new(records: rows, classes: "tw:table-fixed")) do |table|
          table.column(label: "Brakes", classes: "tw:w-[18%]", header_classes: "tw:spec-eyebrow") { |record| record[:type] }
          table.column(label: "Position", classes: "tw:w-[12%]") { |record| record[:position] }
        end %>
      ERB
      expect_template(table, "bikebook/templates/ui/table#table", <<~JS)
        { records: [{ type: 'Disc', position: 'Front' }, { type: 'Rim', position: 'Rear' }], classes: 'tw:table-fixed',
          columns: [{ label: 'Brakes', classes: 'tw:w-[18%]', headerClasses: 'tw:spec-eyebrow', cell: (record) => record.type },
                    { label: 'Position', classes: 'tw:w-[12%]', cell: (record) => record.position }] }
      JS

      grouped = ApplicationController.render(inline: <<~ERB, layout: false, locals: {groups: [[nil, [{label: "Year", value: 2026}]], ["Geometry", [{label: "Reach", value: 450}]]]})
        <%= render(UI::Table::Component.new(record_groups: groups)) do |table|
          table.column(label: "", row_header: true) { |record| record[:label] }
          table.column(label: "Level 2") { |record| record[:value].to_s }
        end %>
      ERB
      expect_template(grouped, "bikebook/templates/ui/table#table", <<~JS)
        { groups: [[null, [{ label: 'Year', value: 2026 }]], ['Geometry', [{ label: 'Reach', value: 450 }]]],
          columns: [{ label: '', rowHeader: true, cell: (record) => record.label }, { label: 'Level 2', cell: (record) => record.value }] }
      JS

      expect_template(UI::Card::Component.new(additional_classes: "tw:mt-6").with_content("<p>Compared</p>".html_safe),
        "bikebook/templates/ui/card#card", "{ additionalClasses: 'tw:mt-6', content: html`<p>Compared</p>` }")
    end
  end

  it "merges motors that match but for their drive wheel, and names the operating modes' e-vehicle classifications" do
    serve_catalog
    visit bikebook_path(vehicle_models: "m/segway/2025/gt3_pro")

    motor = find("section", text: /front and rear motor/i, wait: 10)
    expect(motor).to have_css("div", text: /Drive wheel\s*Front, Rear/)
    expect(page).to have_no_css("h2", text: /\A(Front|Rear) motor\z/i)

    # beside a vehicle that has none
    visit bikebook_path(vehicle_models: "m/sur_ron/2026/ultra_bee_hp_x_us,m/segway/2025/gt3_pro")
    classification = find("section div", text: /E-vehicle class\s*US-CA Off-highway electric motorcycle/, wait: 10)
    expect(classification).to have_xpath("ancestor::section[.//dt[text()='Propulsion']]")
    classification.find("button", text: "?").click
    tooltip = classification.find("[role='tooltip']", text: "An electric motorcycle built for riding off the highway", visible: true)
    expect(tooltip).to have_css("code", exact_text: "evc/us/ca/off_highway_electric_motorcycle")
      .and have_button("Copy ID")

    # its heading picks the classification, whose card sits beside the vehicles' with everything it has
    tooltip.click_link("US-CA Off-highway electric motorcycle")
    card = find("article h1", text: "US-CA Off-highway electric motorcycle").ancestor("article")
    expect(page).to have_css("article", count: 3)
    expect(page).to have_current_path("/bikebook?vehicle_models=m/sur_ron/2026/ultra_bee_hp_x_us,m/segway/2025/gt3_pro,evc/us/ca/off_highway_electric_motorcycle")
    expect(card).to have_css("li", text: "No driver's license needed off the highway")
      .and have_link(href: /ohv\.parks\.ca\.gov/)

    card.find("[aria-label='Remove US-CA Off-highway electric motorcycle']").click
    # the card closes ahead of the render that replaces the search, which the chips wait out
    expect(page).to have_css("article", count: 2)
    expect(page).to have_css(".hw-combobox__chip", count: 2)

    # and its id finds it in the search
    type_into(vehicle_field, "evc/us/ca/off_highway_e")
    retry_on_detach { find("[role='option']", text: "e-Vehicle Classification: US-CA Off-highway electric motorcycle").click }
    expect(page).to have_css(".hw-combobox__chip", text: "e-Vehicle Classification: US-CA Off-highway electric motorcycle")
    expect(page).to have_css("article h1", text: "US-CA Off-highway electric motorcycle")

    # a class that only comes with an optional mode goes on its own line, after the mode
    visit bikebook_path(vehicle_models: "m/specialized/2025/haul_st")
    expect(page).to have_css("section div", text: /\AE-vehicle class\s*US Class 3 \?\s*w\/ optional throttle US Class 2 \?\z/, wait: 10)
    expect(page).to have_css("dd > span.tw\\:block", text: /\Aw\/ optional throttle US Class 2/)
  end

  it "says so when the catalog doesn't load" do
    serve_catalog(manifest_status: 404)
    visit bikebook_path

    expect(page).to have_text("The catalog didn't load. Reload the page to try again.", wait: 10)
  end
end
