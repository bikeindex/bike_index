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

    # A second pick, found by its id, compares the two: a table of each against the first, and the
    # second's card highlighting where it differs
    type_into(vehicle_field, "level_2_step")
    expect(page).to have_css(".hw-combobox__group__label", text: /\(1 matching model\)/i)
    retry_on_detach { find("[role='option']", text: "Aventón Level 2 Step-Through").click }
    expect(page).to have_css("[data-comparison] article", count: 2)
    expect(page).to have_current_path("/bikebook?vehicle_models=m/aventon/2026/level_4_rec_step_through,m/aventon/2022/level_2_step_through")
    # what differs is marked, not what it's called, and of a list just the items that differ
    expect(all("article").last).to have_css("dd .tw\\:spec-diff").and have_no_css("dt .tw\\:spec-diff")
    front_wheel = all("article").last.find("section", text: /\AWheels/i).find("dd", match: :first)
    # the tire's narrower, and the axle's tooltip has less in it; the wheel size is the same
    expect(front_wheel.all(".tw\\:spec-diff").map(&:text)).to match([/\A2\.1\W+in tire/, /\Athru axle/])
    expect(all("article").first).to have_no_css(".tw\\:spec-diff")
    within("[aria-label='Comparison']") do
      expect(page).to have_css("thead th", text: "Level 2 Step-Through")
      expect(find("tr", text: "Price")).to have_css(".tw\\:text-green-700", text: "−$1,000")
      # only the number is colored: the currency symbol and unit keep their gray
      colors = page.evaluate_script(<<~JS)
        [...document.querySelectorAll("[aria-label='Comparison'] .tw\\\\:text-green-700")].slice(0, 2).map((difference) =>
          [difference.querySelector('span:not([title])'), difference.querySelector('span[title]')].map((part) => getComputedStyle(part).color))
      JS
      expect(colors).to have_attributes(size: 2).and all(satisfy { |number, unit| number != unit })
      expect(find("tr", text: "Range")).to have_css(".tw\\:text-red-700", text: "−24")
      expect(find("tr", text: "Top speed")).to have_css("td span", exact_text: "-")
      # no fixture is carbon, which the catalog names "Carbon or Composite"
      material = page.evaluate_script(<<~JS)
        (async () => {
          const catalog = (file) => fetch(`https://bikebook-catalog.bikeindex.org/catalog/${file}`).then((response) => response.json())
          const [{ VehiclePresenter }, { kit }, vocabulary] = await Promise.all([import('bikebook/vehicle_presenter'), catalog('kit.json'), catalog('vocabulary.json')])
          return new VehiclePresenter(kit, vocabulary).named(kit.schemas.vehicle, { frame: { material: 'carbon' } }).frame.material
        })()
      JS
      expect(material).to eq "Carbon/Composite"
      # each position's wheel in the size compared, its sizes, cassette, dropout, axle and widest tire out of the summary, and
      # the widest tire a position takes, a wheel the build doesn't come with included
      wheels = page.evaluate_script(<<~JS)
        (async () => {
          const catalog = (file) => fetch(`https://bikebook-catalog.bikeindex.org/catalog/${file}`).then((response) => response.json())
          const [{ VehiclePresenter }, { brakesAt, wheelsAt }, { fragmentOf }, { kit }, vocabulary] = await Promise.all([import('bikebook/vehicle_presenter'),
            import('bikebook/templates/vehicles/model_viewer'), import('bikebook/render'), catalog('kit.json'), catalog('vocabulary.json')])
          const data = { wheels: [
            { position: ['front', 'rear'], sizes: ['S'], bsd: 584, tire_width: 28 },
            { position: ['front'], sizes: ['M', 'L'], bsd: 622, tire_width: 28, max_tire_width: 32, cassette_interface: 'Shimano HG', dropout: 'vertical', axle: 'thru_axle', axle_diameter: 12 },
            { position: ['rear'], sizes: ['M', 'L'], bsd: 622, tire_width: 28 },
            { position: ['front', 'rear'], configured: false, bsd: 584, max_tire_width: 50 }
          ] }
          const text = (content) => fragmentOf(content).textContent.replace(/\\s+/g, ' ').trim()
          const presenter = new VehiclePresenter(kit, vocabulary)
          const [medium, small] = [{ name: 'M' }, { name: 'S' }].map((size) => wheelsAt(presenter, data, size))
          const brakes = (list, size) => {
            const { types, rotors } = brakesAt(presenter, { brakes: list }, size)
            return [types, rotors ? text(rotors) : 'none']
          }
          const summary = (wheel) => wheel.parts.map(([, , content]) => text(content)).join(', ')
          return [summary(medium.front), medium.front.maxTire, medium.rear.maxTire, summary(small.front),
            // front then rear where they differ, and a size's own brake
            brakes([{ type: 'disc_hydraulic', position: ['front'], rotor_diameter: 160 }, { type: 'disc_hydraulic', position: ['rear'], rotor_diameter: 140 }], { name: 'M' }),
            brakes([{ type: 'disc_hydraulic', position: ['front'], rotor_diameter: 160 }, { type: 'caliper', position: ['rear'] }], { name: 'M' }),
            brakes([{ type: 'disc_hydraulic', position: ['front', 'rear'], sizes: ['M', 'L'], rotor_diameter: 180 }, { type: 'caliper', position: ['front', 'rear'], sizes: ['S'] }], { name: 'S' }),
            brakes([{ type: 'disc_hydraulic', position: ['front', 'rear'], rotor_diameter: 160 }], { name: 'M' })]
        })()
      JS
      expect(wheels).to match([/\A700 C, 28\W*mm tire\z/, 50, 50, /\A650 B, 28\W*mm tire\z/,
        ["Hydraulic disc", /\A160\W*mm front \| 140\W*mm rear\z/], ["Hydraulic disc / Caliper", /\A160\W*mm front\z/], ["Caliper", "none"],
        ["Hydraulic disc", /\A160\W*mm\z/]])
      expect(find("tr", text: "Brakes").all("td").map(&:text)).to eq(["Hydraulic disc", "Hydraulic disc"])
      expect(find("tr", text: "Brake rotors").all("td").map(&:text)).to match([/\A180\W*mm\z/, "—"])
      # the tire's difference in the unit it reads in, and neither better nor worse
      front_tires = find("tr", text: "Front wheel")
      expect(front_tires.all("td").map(&:text)).to match([/\A650 B,\s*2\.2\W+in tire\W*\z/, /\A650 B,\s*2\.1\W+in tire\W*−0\.1\W*in\z/])
      # under the tire, rather than the wheel's size
      expect(front_tires).to have_css("td > span > span", text: /\A2\.1\W+in tire\W*−0\.1\W*in\z/)
        .and have_css(".tw\\:text-gray-500", text: "−0.1")
      # gearing counts its drivetrain's speeds, and compares the cogs' count and each number of teeth on its own
      chainrings = find("tr", text: "Chainrings")
      expect(chainrings.all("td").map(&:text)).to match([/\A1:\s*48\W*t\z/, /\A1:\s*46\W*t\s*−2\z/])
      expect(chainrings).to have_css(".tw\\:text-red-700", exact_text: "−2")
      # a single chainring against the first's largest
      single = page.evaluate_script(<<~JS)
        (async () => {
          const catalog = (file) => fetch(`https://bikebook-catalog.bikeindex.org/catalog/${file}`).then((response) => response.json())
          const [{ VehiclePresenter }, { comparisonTable }, { fragmentOf }, { kit }, vocabulary] = await Promise.all([import('bikebook/vehicle_presenter'),
            import('bikebook/templates/vehicles/comparison_table'), import('bikebook/render'), catalog('kit.json'), catalog('vocabulary.json')])
          const vehicles = [[36, 52], [50]].map((front, index) => ({ value: String(index), data: { model: String(index), gearing: { front }, drivetrain: [`${front.length}_front`] } }))
          const row = [...fragmentOf(comparisonTable({ presenter: new VehiclePresenter(kit, vocabulary), vehicles, sizes: [] })).querySelectorAll('tr')]
            .find((each) => each.textContent.includes('Chainrings'))
          return [...row.querySelectorAll('td')].map((cell) => cell.textContent.replace(/\\s+/g, ' ').trim())
        })()
      JS
      expect(single).to match([/\A2:\s*36,\s*52\W*t\z/, /\A1:\s*50\W*t\s*−2\z/])
      expect(find("tr", text: "Cogs").all("td").map(&:text)).to match([/\A8:\s*12–\s*32\W*t\z/, /\A8:\s*-\s*12–\s*-\s*32\W*t\s*-\z/])
    end

    find("[aria-label='Remove Aventón Level 2 Step-Through']").click
    expect(page).to have_css("article", count: 1)
    expect(page).to have_no_css("[data-comparison]")
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

    # Five compare side by side, rather than wrapping onto rows
    page.current_window.resize_to(1440, 900)
    five = %w[m/aventon/2026/level_4_rec_step_through m/aventon/2022/level_2_step_through m/segway/2025/gt3_pro
      m/specialized/2025/haul_st m/sur_ron/2026/ultra_bee_hp_x_us].join(",")
    card_rows = -> { page.evaluate_script("new Set([...document.querySelectorAll('article')].map((card) => Math.round(card.getBoundingClientRect().top))).size") }
    scrolls_sideways = -> { page.evaluate_script("document.querySelector('[data-comparison] > div').scrollWidth > window.innerWidth") }
    visit bikebook_path(vehicle_models: five)
    # the label column's header and the five vehicles'
    expect(page).to have_css("[aria-label='Comparison'] thead th", count: 6, wait: 10)
    expect(page).to have_css("[data-comparison] article", count: 5)
    expect(card_rows.call).to eq 1
    expect(scrolls_sideways.call).to be true
    # of a year the first lacks just the year, and of a drivetrain just the chip it lacks
    haul = find("article h1", text: "Haul ST").ancestor("article")
    marked = ->(heading, selector) { haul.find("h2", text: heading).ancestor("section").all(selector).map { it.text.strip } }
    expect(marked.call(/\Amodel years\z/i, "tr:last-child td.tw\\:spec-diff")).to eq(["2025"])
    expect(marked.call(/\Adrivetrain\z/i, "span.tw\\:rounded-sm.tw\\:spec-diff")).to eq(["9 Rear"])
    # the table at least the page's column, scrolling only past the window's width
    table_fit = page.evaluate_script(<<~JS)
      (() => {
        const table = document.querySelector("[aria-label='Comparison'] table")
        const scroller = table.closest("[data-controller~='ui--table']")
        return [table.getBoundingClientRect().width, scroller.scrollWidth > scroller.clientWidth]
      })()
    JS
    expect(table_fit).to match([be >= 1248, false])

    # and on a phone too, rather than stacking
    page.current_window.resize_to(390, 844)
    expect(card_rows.call).to eq 1
    expect(scrolls_sideways.call).to be true
    page.current_window.resize_to(1920, 1080)
  end

  it "keeps each compared vehicle's size in the URL, the others nearest the first's by top tube unless picked" do
    serve_catalog
    visit bikebook_path(vehicle_models: "m/aventon/2026/current_adv,m/aventon/2026/current_exp")
    expect(page).to have_css("[aria-label='Comparison'] tbody tr:first-child th", text: "Size", wait: 10)

    # sizes no fixture has: the nearest top tube, reach breaking a tie, then a name read the ways it's written, then medium
    chosen = page.evaluate_script(<<~JS)
      (async () => {
        const { chosenSizes } = await import('bikebook/sizes')
        const size = (name, topTube, reach) => ({ name, geometry: { top_tube_effective: topTube, reach } })
        const vehicle = (value, ...sizes) => ({ value, data: { sizes: sizes.map((each) => typeof each === 'string' ? { name: each } : each) } })
        const names = (vehicles, options) => chosenSizes(vehicles, options).map((each) => each?.name ?? 'none')
        const canyon = vehicle('canyon', size('S', 546, 390), size('M', 555, 393), size('L', 569, 401))
        const bianchi = vehicle('bianchi', size('53', 536, 393), size('55', 550, 397), size('57', 560, 402))
        return [
          names([canyon, bianchi]),
          names([bianchi, canyon], { preferred: size('XL', 559, 400) }),
          names([vehicle('a', 'S', 'M', 'L'), vehicle('b', 'Regular', 'Large'), vehicle('c', 'S/M', 'M/L'), vehicle('d')]),
          names([vehicle('a', 'Small', 'Medium'), vehicle('b', 'XS', 'S', 'M'), vehicle('c', 'MD', 'LG')], { preferred: { name: 'Small' }, picked: { c: 'LG' } })
        ]
      })()
    JS
    expect(chosen).to eq([["M", "55"], ["57", "M"], ["M", "Regular", "S/M", "none"], ["Small", "S", "LG"]])

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
    expect(page).to have_current_path(/[?&]vehicle_sizes=Extra\+Large,Small(&|\z)/)
    # the geometry is each one's size, under its own heading, and less of it is red
    expect(page).to have_css("[aria-label='Comparison'] th[scope='row']", text: /\Ageometry\z/i)
    expect(find("[aria-label='Comparison'] tr", text: "Reach")).to have_css("td", text: /\A425\.5.+−74\.7/m)
      .and have_css(".tw\\:text-red-700", text: "−74.7")
    # in centimeters alone, without an imperial viewer's feet and inches
    expect(find("[aria-label='Comparison'] tr", text: "Wheelbase").all("td").map(&:text)).to all(match(/\A[\d.]+\W*cm(\s*[−+][\d.]+\W*cm|\s*-)?\z/))

    visit current_url
    expect(page).to have_css("[aria-label='Comparison']", wait: 10)
    expect_size.call("Current ADV", "Extra Large")
    expect_size.call("Current EXP", "Small")
    # each card's geometry rings its size
    current_size = ->(model) { find("article h1", exact_text: model).ancestor("article").all("[aria-current='true'] h3", visible: :all).map { it.text(:all) } }
    expect(current_size.call("Current ADV")).to eq(["Extra Large"])
    expect(current_size.call("Current EXP")).to eq(["Small"])
    # and scrolls it to the middle, as far as the sizes scroll: [how far it's scrolled, how far off center it can't get]
    wait_for_stimulus("bikebook--center-current")
    centering = ->(model) {
      page.evaluate_script(<<~JS)
        (() => {
          const article = [...document.querySelectorAll('article')].find((each) => each.querySelector('h1')?.textContent.trim() === #{model.to_json})
          const scroller = article.querySelector('[data-controller~="bikebook--center-current"]')
          const [outer, inner] = [scroller, scroller.querySelector('[aria-current="true"]')].map((element) => element.getBoundingClientRect())
          const centered = scroller.scrollLeft + inner.left + inner.width / 2 - (outer.left + outer.width / 2)
          const reachable = Math.min(Math.max(centered, 0), scroller.scrollWidth - scroller.clientWidth)
          return [scroller.scrollLeft, Math.abs(reachable - scroller.scrollLeft)]
        })()
      JS
    }
    expect(centering.call("Current ADV")).to match([be > 0, be < 2])
    expect(centering.call("Current EXP")).to match([0, be < 2])

    # a size stays with its vehicle as the vehicles change, through one alone, which nothing compares
    find("[aria-label='Remove Aventón Current ADV']").click
    expect(page).to have_css(".hw-combobox__chip", count: 1)
    expect(page).to have_no_css("[aria-label='Comparison']")
    expect(page).to have_current_path(/[?&]vehicle_sizes=Small(&|\z)/)

    # Small's top tube is nearer Soltera's Medium than its Small
    type_into(vehicle_field, "soltera")
    retry_on_detach { find("[role='option']", text: "Aventón Soltera 3 ADV").click }
    expect_size.call("Soltera 3 ADV", "Medium")
    expect_size.call("Current EXP", "Small")
    # a belt drive's drivetrain counts nothing, so its one cog counts itself, and is its largest
    cogs = find("[aria-label='Comparison'] tr", text: "Cogs")
    expect(cogs.all("td").map(&:text)).to match([/\A12:\s*10–\s*52\W*t\z/, /\A1:\s*−11\s*22\W*t\s*−30\z/])
    expect(cogs).to have_css(".tw\\:text-red-700", exact_text: "−11").and have_css(".tw\\:text-red-700", exact_text: "−30")
    expect(page).to have_current_path(/[?&]vehicle_sizes=Small(&|\z)/)

    # the first vehicle's last pick is what a comparison with none picked starts nearest
    visit bikebook_path(vehicle_models: "m/aventon/2026/level_4_adv,m/aventon/2026/current_exp")
    expect(page).to have_css("[aria-label='Comparison']", wait: 10)
    expect_size.call("Level 4 ADV", "Extra Large")
    expect_size.call("Current EXP", "Extra Large")
  end

  it "shows every weight in pounds to a viewer who prefers imperial units" do
    serve_catalog
    sign_in(FactoryBot.create(:user_confirmed, preferred_unit_system: "imperial"))
    visit bikebook_path(vehicle_models: "m/aventon/2026/current_adv,m/aventon/2026/level_4_adv")
    expect(page).to have_css("[aria-label='Comparison']", wait: 10)

    # the comparison's weight and difference, and each size's weight and payload
    expect(find("[aria-label='Comparison'] tr", text: "Weight")).to have_text(/56\W*lb.*61\.1\W*lb\W*\+5\.1\W*lb/m)
    expect(page).to have_css("dd", text: /\A[\d.,]+\W*lb\z/, minimum: 2)
    expect(page).to have_no_text(/\d\W*kg\b/)
    # wheelbase in centimeters, with feet and inches after, which its difference leaves off
    expect(find("[aria-label='Comparison'] tr", text: "Wheelbase").all("td").map(&:text)).to all(match(/\A[\d.]+\W*cm\s*\(\d'\s*\d+"\)(\s*[−+][\d.]+\W*cm|\s*-)?\z/))
    # whose feet and inches are themselves the tooltip's trigger, which spells them out
    wheelbase = find("[aria-label='Comparison'] tr", text: "Wheelbase").first("td")
    expect(wheelbase).to have_no_button("?")
    wheelbase.find("button", text: /\A\d'\s*\d+"\z/).click
    expect(wheelbase).to have_css("[role='tooltip']", text: /\A\d+ feet, [\d.]+ inch(es)?\z/, visible: true)
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
      expect_template(UI::IconChevron::Component.new, "bikebook/templates/ui/icon_chevron#iconChevron", "undefined")

      expect_template(UI::CopyButton::Component.new(value: "m/trek/2025/fetch", label: "Copy ID"),
        "bikebook/templates/ui/copy_button#copyButton", "{ value: 'm/trek/2025/fetch', label: 'Copy ID' }")

      # a class list rather than markup, so its classes against build_classes'
      [[:sm, "tw:shrink-0"], [:md, nil]].each do |size, html_class|
        browser = page.evaluate_script(<<~JS)
          import('bikebook/templates/ui/button').then(({ buttonClasses }) => buttonClasses(#{{size:, htmlClass: html_class}.to_json}))
        JS
        expect(browser.split.sort).to eq(UI::Button::Component.build_classes(color: :secondary, size:, html_class:).split.sort),
          "buttonClasses differs from build_classes at size #{size}"
      end

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

      row_headed = ApplicationController.render(inline: <<~ERB, layout: false, locals: {rows: [{label: "Year", value: 2026}, {label: "Reach", value: 450}]})
        <%= render(UI::Table::Component.new(records: rows)) do |table|
          table.column(label: "", row_header: true) { |record| record[:label] }
          table.column(label: "Level 2") { |record| record[:value].to_s }
        end %>
      ERB
      expect_template(row_headed, "bikebook/templates/ui/table#table", <<~JS)
        { records: [{ label: 'Year', value: 2026 }, { label: 'Reach', value: 450 }],
          columns: [{ label: '', rowHeader: true, cell: (record) => record.label }, { label: 'Level 2', cell: (record) => record.value }] }
      JS
    end
  end

  it "merges motors that match but for their drive wheel, and names the operating modes' e-vehicle classifications" do
    serve_catalog
    visit bikebook_path(vehicle_models: "m/segway/2025/gt3_pro")

    motor = find("section", text: /front and rear motor/i, wait: 10)
    expect(motor).to have_css("div", text: /Drive wheel\s*Front, Rear/)
    expect(motor).to have_css("div", text: /Certification\s*Unknown/)
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

    # beside its classification, side by side with nothing to table
    visit bikebook_path(vehicle_models: "m/segway/2025/gt3_pro,evc/us/ca/off_highway_electric_motorcycle")
    expect(page).to have_css("[data-comparison] article", count: 2, wait: 10)
    expect(page).to have_no_css("[aria-label='Comparison']")
  end

  it "says so when the catalog doesn't load" do
    serve_catalog(manifest_status: 404)
    visit bikebook_path

    expect(page).to have_text("The catalog didn't load. Reload the page to try again.", wait: 10)
  end
end
