# frozen_string_literal: true

require "rails_helper"

RSpec.describe "BikeBook", :js, type: :system do
  after { WebMock.reset! }

  def vehicle_field = find_field("Select a bike, choose multiple to compare them")

  # Page-wide, the filters' ~160 hidden options cost Capybara a round trip each, a pass outlasting its wait
  def vehicle_option = "#vehicle_models-hw-listbox [role='option']"

  # The overlay showing a combobox's selection with its code muted spans the input, though it rendered in the closed filters
  def expect_display_over(label)
    field = find_field(label)
    width = ->(element) { element.evaluate_script("this.getBoundingClientRect().width") }
    expect(field.ancestor("[data-controller~='ui--forms--combobox-display']"))
      .to have_css("[data-ui--forms--combobox-display-target='overlay']") { width.call(it) == width.call(field) }
  end

  def choose_option(label, option)
    field = type_into(find_field(label), option)
    find("##{field[:id]}-hw-listbox [role='option']", text: option).click
  end

  # A delete at a time, as Playwright's fill("") doesn't deselect, then a click away, which closes its listbox
  def clear_jurisdiction
    field = find_field("Jurisdiction")
    field.click
    field.send_keys(*Array.new(field.value.length, :backspace))
    find("legend", text: /e-bike classification/i).click
  end

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
    serve_bikebook_catalog
    # from a country the catalog has no models in, which searches them all
    page.driver.with_playwright_page { it.set_extra_http_headers("CF-IPCountry" => "JP") }
    asked = []
    logged = []
    page.driver.with_playwright_page do |playwright_page|
      playwright_page.on("request", ->(request) do
        asked << request.url if request.navigation_request?
        logged << request.url.split("?").last if request.url.include?(search_bikebook_path)
      end)
    end
    visit bikebook_path
    # the search is an unusable placeholder until the catalog loads
    expect(page).to have_no_css("[inert]", wait: 10)

    # Nothing picked shows how it works, until it's dismissed, which outlasts a reload
    tips = "[aria-label='How to use BikeBook']"
    expect(page).to have_css(tips).and have_link("Trek Marlin 5 vs Specialized Rockhopper Sport", href: %r{vehicle_models=m/trek/2026/marlin_5_gen_3,})
    # and, filtered or not, some of the catalog to start from, in its order: half e-bikes, each a class legal where the
    # visitor is (so no Segway GT3 Pro, Haul ST CA or Sur-Ron), at least three at $1,500 or less, and none over $10,000
    # but Reactive Adaptations' (so no Crux 5 S-Level)
    expect(page).to have_text("33 models to compare.")
    expect(find("[aria-label='Models to compare']").all("a").map { it[:href][/vehicle_models=(.+)/, 1] }).to eq %w[m/aventon/2026/current_exp
      m/aventon/2025/aventure_m m/aventon/2026/ramblas_adv m/aventon/2026/level_4_adv m/specialized/2025/haul_st m/aventon/2026/soltera_3_adv
      m/kris_holm/2023/kh36 m/kris_holm/2023/kh29 m/kris_holm/2023/kh27_5 m/kris_holm/2023/kh24 m/kris_holm/2023/kh20
      m/reactive_adaptations/2013/nuke]
    within(tips) { click_on "More filters" }
    expect(page).to have_css("#vehicle-filters", visible: true)
    # which a filter changes in place
    check "Human powered (Acoustic)"
    expect(page).to have_text("8 models match your filters.")
    expect(all("[aria-label='Models to compare'] a").map { it[:href][/vehicle_models=(.+)/, 1] }).to eq %w[m/kris_holm/2023/kh36
      m/kris_holm/2023/kh29 m/kris_holm/2023/kh27_5 m/kris_holm/2023/kh24 m/kris_holm/2023/kh24_us m/kris_holm/2023/kh20
      m/reactive_adaptations/2013/nuke]
    find("button[aria-label='Dismiss tips']").click
    expect(page).to have_no_css(tips).and have_text(/nothing selected yet/i)
    # focus moves to what replaced the button pressed
    expect(page).to have_css("button:focus", exact_text: "Show tips")
    visit bikebook_path
    expect(page).to have_text(/nothing selected yet/i, wait: 10)
    expect(page).to have_no_css(tips)
    click_on "Show tips"
    expect(page).to have_css("#{tips}:focus")
    visit bikebook_path
    expect(page).to have_css(tips, wait: 10)
    asked.clear

    vehicle_field.click
    expect(page).to have_css(".hw-combobox__group__label", text: /\(33 matching models\)/i)
    # a query matching nothing says so, and Enter keeps it open to edit
    type_into(vehicle_field, "zzqq")
    expect(page).to have_css(".hw-combobox__group__label", text: /\(0 matching models\)/i)
    vehicle_field.send_keys(:enter)
    expect(vehicle_field.value).to eq "zzqq"
    expect(vehicle_field["aria-expanded"]).to eq "true"

    type_into(vehicle_field, "level 4 rec")
    expect(page).to have_css(".hw-combobox__group__label", text: /\(2 matching models\)/i)
    retry_on_detach { find(vehicle_option, text: "Aventón Level 4 REC Step-Through").click }
    # its basics first, beside its photo
    expect(page).to have_css("[aria-label='Overview'] thead th", text: "Level 4 REC Step-Through")
    expect(page).to have_css("nav[aria-label='Views'] a[aria-current='page']", exact_text: "Overview")
    # its ID a copy away, beside its name, which its tooltip shows
    copy_id = find("[aria-label='Overview'] thead button[aria-label='Copy ID (m/aventon/2026/level_4_rec_step_through)']")
    copy_id.hover
    expect(page).to have_css("[role='tooltip']", exact_text: "Copy ID (m/aventon/2026/level_4_rec_step_through)", visible: true)
    # its certifications as /ebike-rules shows them, each a tooltip of what it means
    certifications = find("[aria-label='Overview'] tr", text: /\AElectric Certification/)
    expect(certifications).to have_text(/UL 2849 Certified\s*E-bike electrical system\s*UL 2271 Certified\s*Battery pack\z/)
    certifications.find("button", text: "UL 2271 Certified").hover
    expect(page).to have_css("[role='tooltip']", text: "The battery pack passed UL safety testing", visible: true)
    # under its class's name, the class's tile, a tooltip of its US class card, in place of the name's own
    badge = find("[aria-label='Overview'] td button[aria-label$=' e-bike']")
    expect(badge.ancestor("td")).to have_no_button("?")
    badge.click
    expect(page).to have_css("[role='tooltip'] h3", exact_text: "Class #{badge[:"aria-label"][/\d/]}", visible: true)
    expect(find("[aria-label='Overview']").all("tbody tr > th").map(&:text))
      .to eq(["Model group", "Years", "Primary activity", "Frame material", "Wheel & tire size", "Suspension front/rear", "Groupset", "Price", "E-vehicle class", "Electric Certification", "Description"])
    # a tire over 50 mm in inches, its mm in a tooltip
    expect(find("[aria-label='Overview'] tr", text: /\AWheel & tire size/).find("td").text(:all).squish).to eq "650 B × 2.2 in ? 56 mm"
    # no groupset listed, so its gear count alone, with the rest of its drivetrain in the tooltip
    expect(find("[aria-label='Overview'] tr", text: /\AGroupset/).find("td").text(:all).squish).to match(/\A1x8 \? Drivetrain: /)
    expect(find("[aria-label='Overview']")).to have_text("The Level 4 REC").and have_button("Read more")
    expect(page).to have_title(/Aventón Level 4 REC Step-Through/)
    expect(page).to have_css(".hw-combobox__chip", text: "Aventón Level 4 REC Step-Through")
    expect(page).to have_current_path("/bikebook?search=1&vehicle_models=m/aventon/2026/level_4_rec_step_through")
    # for the search logs, what the reader typed once they stopped, and then what they picked
    expect(logged).to eq ["count=2&q=level+4+rec", "vehicle_models=m/aventon/2026/level_4_rec_step_through"]
    # its model group's models under the overview, each under the newest year it's sold in - the current ones this year's
    within(find("[aria-label='Overview'] tr", text: /\AModel group/)) { click_link "View group" }
    group_cards = -> { all("[aria-labelledby='model-group-name'] li h3").map(&:text) }
    expect(page).to have_css("#model-group h2", exact_text: "Level")
    expect(all("#model-group > div > h3").map(&:text)).to eq([Time.current.year.to_s])
    expect(group_cards.call).to match_array(["Aventón Level 2", "Aventón Level 2 Step-Through", "Aventón Level 3", "Aventón Level 3 Step-Through",
      "Aventón Level 4 ADV", "Aventón Level 4 ADV Step-Through", "Aventón Level 4 REC", "Aventón Level 4 REC Step-Through"])
    # a longer one a page of years at a time, the next as the reader nears its end
    page.evaluate_script(<<~JS)
      (async () => {
        const [{ render }, { modelGroup }] = await Promise.all([import('lit-html'), import('bikebook/templates/vehicles/model_group')])
        const years = Array.from({ length: 10 }, (_, index) => ({ year: 2026 - index, models: Array.from({ length: 6 }, (_, each) =>
          ({ id: `m/test/${2026 - index}/model_${each}`, manufacturer_name: 'Test', model: `${2026 - index} Model ${each}`, first_year: 2026 - index, final_year: 2026 - index })) }))
        const container = document.createElement('div')
        render(modelGroup({ group: { name: 'Long', manufacturer: 'Test', years }, vehiclePath: (id) => id, placeholderUrl: '', currencies: {} }), container)
        document.getElementById('model-group').replaceWith(container)
      })()
    JS
    years_shown = -> { all("#model-group > div > h3").map(&:text) }
    expect(page).to have_css("#model-group h2", exact_text: "Long")
    expect(years_shown.call).to eq(%w[2026 2025 2024 2023])
    page.scroll_to(:bottom)
    expect(page).to have_css("#model-group > div > h3", count: 8)
    page.scroll_to(:bottom)
    expect(years_shown.call).to eq(%w[2026 2025 2024 2023 2022 2021 2020 2019 2018 2017])
    # and hidden again
    click_link "View group"
    expect(page).to have_no_css("#model-group")
    expect(page).to have_current_path("/bikebook?search=1&vehicle_models=m/aventon/2026/level_4_rec_step_through")

    # A second pick, found by its id, compares the two: a table of each against the first, and the
    # second's card highlighting where it differs
    type_into(vehicle_field, "level_2_step")
    expect(page).to have_css(".hw-combobox__group__label", text: /\(1 matching model\)/i)
    retry_on_detach { find(vehicle_option, text: "Aventón Level 2 Step-Through").click }
    expect(page).to have_css("[aria-label='Overview comparison'] thead th", count: 3)
    expect(page).to have_current_path("/bikebook?search=1&vehicle_models=m/aventon/2026/level_4_rec_step_through,m/aventon/2022/level_2_step_through")
    # the render re-runs the pick's search in its combobox, which settles unlogged
    page.evaluate_script("new Promise((resolve) => setTimeout(resolve, 1100))")
    expect(logged).to eq ["count=2&q=level+4+rec", "vehicle_models=m/aventon/2026/level_4_rec_step_through",
      "count=1&q=level_2_step&vehicle_models=m/aventon/2026/level_4_rec_step_through",
      "vehicle_models=m/aventon/2026/level_4_rec_step_through,m/aventon/2022/level_2_step_through"]
    expect(page).to have_no_css("article")
    # what differs is only marked further down
    expect(find("[aria-label='Overview comparison']")).to have_no_css(".tw\\:spec-diff")
    # beside an e-vehicle, one without a motor says it isn't one rather than missing its class, and an unlisted
    # certification is unknown, as the motor's section says. Wheel and tire sizes always show, vehicle types only where they
    # differ, each one's tire max on a line under it, and each end's travel once one is suspended, its specs under its heading in one tooltip
    classes = page.evaluate_script(<<~JS)
      (async () => {
        const catalog = (file) => fetch(`https://bikebook-catalog.bikeindex.org/catalog/${file}`).then((response) => response.json())
        const [{ VehiclePresenter }, { basics }, { fragmentOf }, { kit }, vocabulary] = await Promise.all([import('bikebook/vehicle_presenter'),
          import('bikebook/templates/vehicles/basics'), import('bikebook/render'), catalog('kit.json'), catalog('vocabulary.json')])
        const wheels = (front, rear, tire, [frontMax, rearMax] = []) =>
          [{ bsd: front, tire_width: tire, max_tire_width: frontMax, position: ['front'] }, { bsd: rear, tire_width: tire, max_tire_width: rearMax, position: ['rear'] }]
        const lines = (cell) => { cell.querySelectorAll('br').forEach((br) => br.replaceWith('|')); return cell.textContent.split('|').map((line) => line.replace(/\\s+/g, ' ').trim()) }
        const rowsOf = (datas) => [...fragmentOf(basics({ presenter: new VehiclePresenter(kit, vocabulary), vehicles: datas.map((data, index) => ({ value: String(index), data })), removePath: () => '/bikebook' }))
          .querySelectorAll('tbody tr')]
        const rows = rowsOf([{ model: 'Electric', type: 'cargo_bike', motors: [{ rated_power: 250 }], wheels: wheels(622, 584, undefined, [50, 60]), suspension: { front: { travel: 120 } } },
          { model: 'Acoustic', type: 'bike', wheels: wheels(622, 622, 40, [45, 45]) }])
        const cells = (label) => [...rows.find((each) => each.querySelector('th').textContent.trim() === label).querySelectorAll('td')]
        return [cells('E-vehicle class').map((cell) => [cell.textContent.trim(), cell.querySelector('.twless-strong') != null]),
          cells('Electric Certification').map((cell) => [...cell.querySelectorAll('button')].map((badge) => badge.textContent.replace(/\\s+/g, ' ').trim())),
          cells('Wheel & tire size').map(lines), cells('Vehicle type').map((cell) => cell.textContent.trim()),
          cells('Suspension front/rear').map((cell) => [cell.textContent.replace(/\\s+/g, ' ').trim(), [...cell.querySelectorAll('.twless-strong')].map((each) => each.textContent)]),
          rowsOf([{ model: 'One', type: 'bike', wheels: wheels(622, 622) }, { model: 'Two', type: 'bike', wheels: wheels(622, 622) }])
            .map((row) => row.querySelector('th').textContent.trim()).filter((label) => /Wheel|Vehicle type|Suspension/.test(label))]
      })()
    JS
    expect(classes).to eq([[["—", false], ["not e-vehicle", true]], [["? Certification unknown"], []], [["700 C front, 650 B rear", "50 mm front, 2.4 in ? 60 mm rear tire max"], ["700 C × 40 mm", "45 mm tire max"]], ["Cargo Bike", "Bike"], [["120 mm front (no rear suspension) ? Front suspensionTravel: 120 mm", []], ["Rigid", ["Rigid"]]], ["Wheel & tire size"]])
    # a description over 200 characters is cut at a word, its paragraphs kept, and one within them is whole
    excerpts = page.evaluate_script(<<~JS)
      (async () => {
        const catalog = (file) => fetch(`https://bikebook-catalog.bikeindex.org/catalog/${file}`).then((response) => response.json())
        const [{ VehiclePresenter }, { basics }, { fragmentOf }, { kit }, vocabulary] = await Promise.all([import('bikebook/vehicle_presenter'),
          import('bikebook/templates/vehicles/basics'), import('bikebook/render'), catalog('kit.json'), catalog('vocabulary.json')])
        const description = (text) => {
          const rendered = fragmentOf(basics({ presenter: new VehiclePresenter(kit, vocabulary), vehicles: [{ value: '0', data: { model: 'One', description: text } }], removePath: () => '/bikebook' }))
          const excerpt = rendered.querySelector('tbody [data-controller~="ui--collapse"] > div')
          return excerpt ? [...excerpt.querySelectorAll('p')].map((paragraph) => paragraph.textContent) : rendered.querySelector('tbody button') == null
        }
        return [description(`Its first paragraph.\\n\\n${'word '.repeat(60)}`), description('Short and whole.')]
      })()
    JS
    expect(excerpts.first.first).to eq "Its first paragraph."
    expect(excerpts.first.last).to match(/\Aword( word)+…\z/)
    expect(excerpts.first.join.length).to be <= 201
    expect(excerpts.last).to be true
    # each view a link to this page, rendered without a request and kept through a pick, in place of its history entry
    history_length = -> { page.evaluate_script("window.history.length") }
    entries = history_length.call
    click_link "Sizes & geometry"
    expect(page).to have_css("[aria-label='Sizes & geometry comparison'] tbody th", exact_text: "Size")
    expect(page).to have_css("section[aria-label$=' sizes'] header button[aria-label^='Copy ID (m/']", minimum: 1)
    # the tab stays focused, for the next one along
    expect(page).to have_css("nav[aria-label='Views'] a[aria-current='page']:focus", exact_text: "Sizes & geometry")
    expect(page).to have_no_css("[aria-label='Overview comparison']")
    expect(page).to have_current_path(/[?&]view=geometry\b/)
    # the overlay beside the table, to its left, once the window's wide, and above it until then
    corner = ->(label) { page.evaluate_script("(({ left, top }) => [left, top])(document.querySelector(#{"[aria-label='#{label}']".to_json}).getBoundingClientRect())") }
    window_size = page.current_window.size
    page.current_window.resize_to(1600, 1000)
    expect(corner.call("Geometry overlay").first).to be < corner.call("Sizes & geometry comparison").first
    expect(corner.call("Geometry overlay").last).to be_within(1).of(corner.call("Sizes & geometry comparison").last)
    page.current_window.resize_to(1400, 1000)
    expect(corner.call("Geometry overlay").last).to be < corner.call("Sizes & geometry comparison").last
    page.current_window.resize_to(*window_size)
    # the wheels compared under the size, rather than on each model's sizes card (these list no max tire), and no type,
    # as they're both bikes
    labels = all("[aria-label='Sizes & geometry comparison'] tbody th").map(&:text)
    expect(labels.first(4)).to eq(["Front wheel", "Rear wheel", "Size", "Reach"])
    sizes_card = find("section[aria-label='Aventón Level 2 Step-Through sizes']")
    # each model's card topped in its frame's color, as its table column is, which isn't footed in it
    expect(page).to have_no_css("[aria-label='Sizes & geometry comparison'] td.tw\\:border-b-4")
    expect(all("section[aria-label$=' sizes']").map { it[:class][/tw:border-t-\[#\w+\]!/] }).to eq(["tw:border-t-[#3498db]!", "tw:border-t-[#DC2626]!"])
    expect(sizes_card).to have_no_css("h2", text: /\Awheels\z/i)
    # its sizes scroll out to the card's edges, as a components table does
    edges = ->(element) { element.evaluate_script("[this.getBoundingClientRect().left, this.getBoundingClientRect().right].map(Math.round)") }
    card_left, card_right = edges.call(sizes_card)
    scroller_left, scroller_right = edges.call(sizes_card.find("[data-controller~='ui--tabs']"))
    expect([scroller_left - card_left, card_right - scroller_right]).to all(be <= 1)
    # the overlay draws a frame from the figures it lists and those they work out, and one it can't work out as its
    # wheels alone - its wheelbase apart - from the same rear wheel spot, saying which it's missing
    within("[aria-label='Geometry overlay']") do
      expect(first("ul").all("li").map(&:text)).to eq(["Aventón Level 4 REC Step-Through Regular", "Aventón Level 2 Step-Through S/M"])
      frames = all("svg[role='img'] > g", visible: :all)
      expect(frames.map { it.has_css?("path", visible: :all) }).to eq([true, false])
      wheels = frames.last.all("circle", visible: :all).map { it[:cx].to_f }
      expect(wheels.first).to eq 0
      # the drawn frame's rear wheel on the same spot
      expect(frames.first.all("circle", visible: :all).map { it[:cx].to_f }.min).to eq 0
      expect(wheels.last - wheels.first).to be_within(0.1).of(1095)
      expect(page).to have_text(/Aventón Level 2 Step-Through doesn't list its BB Drop, Head Angle, .* or the measures to calculate them, so only its wheels/)
        .and have_text("so only its wheels are drawn.")
      # the same wheel size, its tires too near each other's for the wheel note
      expect(page).to have_no_text("diameter")
      # its stem and bar left out, as it lists no stem length to draw them from, unsaid as no frame's is drawn
      expect(page).to have_no_text("Stem Length")
    end
    # the same of each type that guesses at its stem, but not one drawn at a listed handlebar height
    cockpits = page.evaluate_script(<<~JS)
      (async () => {
        const { sideView } = await import('bikebook/templates/vehicles/cycle_drawing')
        const geometry = { stack: 600, reach: 400, head_tube: 150, head_angle: 70, seat_angle: 74, chainstay: 430, bb_drop: 60, wheelbase: 1150, seat_tube_ct: 500 }
        const drawn = (type, data = {}, extra = {}) => [false, true].map((stem) => {
          const view = sideView({ type, data, size: { geometry: { ...geometry, ...extra, ...(stem ? { stem_length: 80 } : {}) } } })
          return [view.stemless, view.shapes.filter(({ cockpit }) => cockpit).length > 0]
        })
        return {
          bike: drawn('bike'), step_through: drawn('bike', { type_detail: 'step_through' }), bmx: drawn('bike', { primary_activity: 'bmx' }),
          longtail: drawn('cargo_bike_rear'), tandem: drawn('tandem'), tandem_step_through: drawn('tandem', { type_detail: 'step_through' }),
          tall_bike: drawn('tall_bike'), recumbent: drawn('recumbent'), e_scooter: drawn('e_scooter', {}, { handlebar_height: 1100 })
        }
      })()
    JS
    expect(cockpits.except("e_scooter").values.uniq).to eq [[[true, false], [false, true]]]
    expect(cockpits["e_scooter"]).to eq [[false, false], [false, false]]
    # matched for its riders, which picking the size up takes over from
    find("select[aria-label='Size of Level 2 Step-Through']").select("M/L")
    expect(page).to have_css("select[aria-label='Size of Level 2 Step-Through'] option[selected]", exact_text: "M/L")
    within("[aria-label='Sizes & geometry comparison']") do
      expect(page).to have_css("thead th", text: "Level 2 Step-Through")
      expect(page).to have_css("thead th button[aria-label='Copy ID (m/aventon/2022/level_2_step_through)']")
      # keyed to the overlay by its frame's color along its head, its wheels' where it's only them
      expect(all("thead th").map { it[:class].include?("tw:border-t-4") }).to eq([false, true, true])
      # in the frame's color in dark mode too, over the cells' own dark border
      key_colors = page.evaluate_script(<<~JS)
        (() => {
          const header = document.querySelector("[aria-label='Sizes & geometry comparison'] thead th:nth-child(2)")
          // dark last undone, so the page is left light
          return [true, false].map((dark) => {
            document.documentElement.classList.toggle('dark', dark)
            return getComputedStyle(header).borderTopColor
          })
        })()
      JS
      expect(key_colors).to eq(["rgb(52, 152, 219)"] * 2)
      expect(find("tr", text: "Top Tube (effective)")).to have_css(".tw\\:text-green-700", text: "+6")
      # only the number is colored: the unit keeps its gray
      colors = page.evaluate_script(<<~JS)
        [...document.querySelectorAll("[aria-label='Sizes & geometry comparison'] .tw\\\\:text-green-700")].slice(0, 2).map((difference) =>
          [difference.querySelector('span:not([title])'), difference.querySelector('span[title]')].map((part) => getComputedStyle(part).color))
      JS
      expect(colors).to have_attributes(size: 2).and all(satisfy { |number, unit| number != unit })
      expect(find("tr", text: "Reach")).to have_css(".tw\\:text-red-700", text: "−19")
      # the tire's difference in mm though it reads in inches, and neither better nor worse
      front_tires = find("tr", text: "Front wheel")
      expect(front_tires.all("td").map(&:text)).to match([/\A650 B,\s*2\.2\W+in tire\W*\z/, /\A650 B,\s*2\.1\W+in tire\W*−3\W*mm\z/])
      # under the tire, rather than the wheel's size
      expect(front_tires).to have_css("td > span > span", text: /\A2\.1\W+in tire\W*−3\W*mm\z/)
        .and have_css(".tw\\:text-gray-500", text: "−3")
    end
    # each model's components alone, by group on a card of its own beside the others', without the specs or the rest of its card
    click_link "Components"
    expect(page).to have_css("section[aria-label='Aventón Level 2 Step-Through components'] h3", exact_text: "Level 2 Step-Through")
    expect(page).to have_css("[data-comparison] section[aria-label$=' components']", count: 2)
    # topped in no frame's color, which is the geometry's
    expect(page).to have_no_css("section[aria-label$=' components'].tw\\:border-t-4")
    expect(page).to have_no_css("article").and have_no_css("[aria-label='Components comparison']")
    # each with the overview's × in its top right corner
    corners = page.evaluate_script(<<~JS)
      [...document.querySelectorAll("section[aria-label$=' components']")].map((card) => {
        const [box, remove] = [card, card.querySelector("a[aria-label^='Remove ']")].map((each) => each.getBoundingClientRect())
        return [card.querySelector("a[aria-label^='Remove ']").ariaLabel, Math.round(remove.top - box.top), Math.round(box.right - remove.right)]
      })
    JS
    expect(corners).to eq([["Remove Aventón Level 4 REC Step-Through", 1, 1], ["Remove Aventón Level 2 Step-Through", 1, 1]])
    # under its frame, wheels, brakes, suspension and drivetrain
    headings = find("section[aria-label='Aventón Level 2 Step-Through components']").all("h2").map { it.text.downcase }
    expect(headings.first(5)).to eq(["frame", "wheels", "brakes", "suspension", "drivetrain"])
    # each row level with the other card's, its blank standing in where only the other has the component. Read two
    # frames on, as bikebook--align-rows sizes them in the frame after the cards render
    tops = page.evaluate_script(<<~JS)
      new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(() => resolve(
        [...document.querySelectorAll("section[aria-label$=' components']")].map((card) => [...card.querySelectorAll('[data-align-row]')]
          .map((row) => [row.dataset.alignRow, Math.round(row.getBoundingClientRect().top)]))))))
    JS
    expect(tops.first.map(&:first)).to eq(tops.last.map(&:first))
    expect(page).to have_css("section[aria-label$=' components'] tbody tr", exact_text: "")
    expect(tops.first.zip(tops.last).map { |(_, first), (_, last)| (first - last).abs }).to all(be <= 1)
    # each group's components that match in both first, then those both have, then those one has, the second card
    # marking where they differ
    cells = page.evaluate_script(<<~JS)
      [...document.querySelectorAll("section[aria-label$=' components']")].map((card) => [...card.querySelectorAll('tbody')].map((group) =>
        [...group.querySelectorAll('tr')].map((row) => [row.textContent.trim() !== '', !row.querySelector('.tw\\\\:spec-diff')])))
    JS
    ranks = cells.first.zip(cells.last).map do |first, last|
      first.zip(last).map { |(had, _), (other_had, same)|
        if [had, other_had].count(true) == 2
          same ? 0 : 1
        else
          2
        end
      }
    end
    expect(ranks.flatten.tally).to include(0 => 4, 1 => be_positive, 2 => be_positive)
    expect(ranks).to all(satisfy { |rows| rows == rows.sort })
    # and their motors and batteries, a tab only an e-vehicle gets
    click_link "Motor & Battery"
    expect(page).to have_css("[data-comparison] section[aria-label$=' motors']", count: 2)
    expect(find("section[aria-label='Aventón Level 2 Step-Through motors']")).to have_css("h2", text: /\Amotor & battery\z/i)
      .and have_css("h3", text: /\Apedal assist\z/i)
    without_motor = page.evaluate_script(<<~JS)
      (async () => {
        const catalog = (file) => fetch(`https://bikebook-catalog.bikeindex.org/catalog/${file}`).then((response) => response.json())
        const [{ VehicleViewer }, { fragmentOf }, { kit }, vocabulary] = await Promise.all([import('bikebook/vehicle_viewer'),
          import('bikebook/render'), catalog('kit.json'), catalog('vocabulary.json')])
        const url = new URL('/bikebook?view=motors', window.location.href)
        const rendered = fragmentOf(new VehicleViewer(kit, vocabulary).render([{ value: 'm/surly/2018/0', data: { model: 'Acoustic' } }], url, null))
        return [...rendered.querySelectorAll('nav[aria-label="Views"] a')].map((tab) => [tab.textContent.trim(), tab.hasAttribute('aria-current')])
      })()
    JS
    expect(without_motor).to eq([["Overview", true], ["Sizes & geometry", false], ["Components", false], ["All", false]])
    click_link "All"
    expect(page).to have_css("[data-comparison] article", count: 2)
    # each card's ID a copy away beside its name, as on the Overview, rather than a row of its own
    expect(page).to have_css("[data-comparison] article header button[aria-label^='Copy ID (m/']", count: 2)
      .and have_no_css("[data-comparison] article dt", exact_text: "ID")
    # the full cards alone, without the other views' tables or the overlay
    expect(page).to have_no_css("table:not(article table)").and have_no_css("[aria-label='Geometry overlay']")
    expect(page).to have_current_path(/[?&]view=all\b/)
    # the size picked an entry of its own
    expect(history_length.call).to eq entries + 1
    # what differs is marked, not what it's called, and of a list just the items that differ
    expect(all("article").last).to have_css("dd .tw\\:spec-diff").and have_no_css("dt .tw\\:spec-diff")
    front_wheel = all("article").last.find("section", text: /\AWheels/i).find("dd", match: :first)
    # the tire's narrower, and the axle's tooltip has less in it; the wheel size is the same
    expect(front_wheel.all(".tw\\:spec-diff").map(&:text)).to match([/\A2\.1\W+in tire/, /\Athru axle/])
    expect(all("article").first).to have_no_css(".tw\\:spec-diff")
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
        const [{ VehiclePresenter }, { wheelsAt }, { fragmentOf }, { kit }, vocabulary] = await Promise.all([import('bikebook/vehicle_presenter'),
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
        const summary = (wheel) => wheel.parts.map(([, , content]) => text(content)).join(', ')
        return [summary(medium.front), medium.front.maxTire, medium.rear.maxTire, summary(small.front)]
      })()
    JS
    expect(wheels).to match([/\A700 C, 28\W*mm tire\z/, 50, 50, /\A650 B, 28\W*mm tire\z/])
    # a groupset is a line of the drivetrain's, its maker named once, and electronic shifting alone marked against the first's
    groupsets = page.evaluate_script(<<~JS)
      (async () => {
        const catalog = (file) => fetch(`https://bikebook-catalog.bikeindex.org/catalog/${file}`).then((response) => response.json())
        const [{ VehicleViewer }, { fragmentOf }, { kit }, vocabulary] = await Promise.all([import('bikebook/vehicle_viewer'),
          import('bikebook/render'), catalog('kit.json'), catalog('vocabulary.json')])
        const vehicles = [['GRX RX610 1X12S', false], ['Shimano GRX RX610 1X12S', true], ['SHIMANO GRX RX822 1X12S', false]].map(([description, electronic], index) =>
          ({ value: `m/shimano/2026/${index}`, display: String(index), data: { model: String(index), groupset: { manufacturer: 'Shimano', description, electronic } } }))
        const viewers = fragmentOf(new VehicleViewer(kit, vocabulary).render(vehicles, new URL(window.location.href), null))
        return [...viewers.querySelectorAll('article')].map((article) => {
          const row = [...article.querySelectorAll('section')].find((each) => /^drivetrain/i.test(each.textContent.trim())).querySelector('dd')
          return [row.textContent.replace(/\s+/g, ' ').trim(), [...row.querySelectorAll('[class~="tw:spec-diff"]')].map((each) => each.textContent.trim())]
        })
      })()
    JS
    expect(groupsets).to eq([["Shimano GRX RX610 1X12S", []], ["Shimano GRX RX610 1X12S · electronic", ["electronic"]],
      ["SHIMANO GRX RX822 1X12S", ["SHIMANO GRX RX822 1X12S"]]])
    # a motor linked by its market's unit names the market, and its assist speed is its market's, in mph for a US model
    motors = page.evaluate_script(<<~JS)
      (async () => {
        const catalog = (file) => fetch(`https://bikebook-catalog.bikeindex.org/catalog/${file}`).then((response) => response.json())
        const [{ VehicleViewer }, { fragmentOf }, { kit }, vocabulary] = await Promise.all([import('bikebook/vehicle_viewer'),
          import('bikebook/render'), catalog('kit.json'), catalog('vocabulary.json')])
        const bike = (markets, id, speed) => ({ model: 'E', markets, motors: [{ manufacturer: 'Bosch', model: 'Performance Line CX (BDU384Y)', id,
          operating_modes: [{ mode: 'assist', availability: 'stock', max_speed: speed }] }] })
        const rows = (data) => [...fragmentOf(new VehicleViewer(kit, vocabulary).render([{ value: 'm/x/2026/e', data }], new URL('/bikebook?view=motors', window.location.href), null))
          .querySelectorAll('section section dl > div')].map((row) => row.textContent.replace(/\\s+/g, ' ').trim()).filter((row) => /^(Motor|Max speed)/.test(row))
        return [rows(bike(['US'], 'c/bosch/2025/bdu384y_us', 32.2)), rows(bike(['EU'], 'c/bosch/2025/bdu384y_eu', 25)), rows(bike(['JP'], 'c/bosch/2025/bdu384y', 24))]
      })()
    JS
    # each speed in both systems, of which the viewer's shows
    expect(motors).to eq([["MotorBosch Performance Line CX (BDU384Y), US", "Max speed32.2 km/h20 mph"],
      ["MotorBosch Performance Line CX (BDU384Y), EU", "Max speed25 km/h15.5 mph"], ["MotorBosch Performance Line CX (BDU384Y)", "Max speed24 km/h14.9 mph"]])
    # a mode that lists nothing else, as a stock throttle can, keeps its heading, as stock, alone and beside a model whose
    # own lists more
    bare_mode = page.evaluate_script(<<~JS)
      (async () => {
        const catalog = (file) => fetch(`https://bikebook-catalog.bikeindex.org/catalog/${file}`).then((response) => response.json())
        const [{ VehicleViewer }, { fragmentOf }, { kit }, vocabulary] = await Promise.all([import('bikebook/vehicle_viewer'),
          import('bikebook/render'), catalog('kit.json'), catalog('vocabulary.json')])
        const bike = (throttle) => ({ model: 'E', motors: [{ rated_power: 250, operating_modes: [{ mode: 'throttle', e_vehicle_classifications: ['evc/us/class_2'], ...throttle }] }] })
        const throttles = (vehicles) => [...fragmentOf(new VehicleViewer(kit, vocabulary).render(vehicles, new URL('/bikebook?view=motors', window.location.href), null))
          .querySelectorAll('section[aria-label$=" motors"]')].map((card) => [...card.querySelectorAll('section section h3')]
          .map((heading) => heading.parentElement.textContent.replace(/\\s+/g, ' ').trim()))
        const bare = bike({ availability: 'stock' })
        return [throttles([{ value: 'm/x/2026/e', data: bare }]),
          throttles([{ value: 'm/x/2026/d', data: bike({ availability: 'upgrade', max_speed: 32 }) }, { value: 'm/x/2026/e', data: bare }])[1]]
      })()
    JS
    expect(bare_mode).to eq [[["ThrottleAvailabilityStock"]], ["ThrottleAvailabilityStock"]]

    # an end's spring and lockout, said where they're notable, and a coil-compatible frame
    specs = page.evaluate_script(<<~JS)
      (async () => {
        const catalog = (file) => fetch(`https://bikebook-catalog.bikeindex.org/catalog/${file}`).then((response) => response.json())
        const [{ VehicleViewer }, { fragmentOf }, { kit }, vocabulary] = await Promise.all([import('bikebook/vehicle_viewer'),
          import('bikebook/render'), catalog('kit.json'), catalog('vocabulary.json')])
        const data = { model: 'Enduro', frame: { material: 'aluminum', coil_compatible: true }, groupset: { manufacturer: 'SRAM', series: 'GX', description: 'GX Eagle AXS', electronic: true },
          drivetrain: ['1_front', '12_rear'], gearing: { front: [32], rear: [10, 52] },
          suspension: { front: { travel: 170, spring: 'air', lockout: true }, rear: { travel: 160, shock_length: 157.5, shock_stroke: 62.5, spring: 'coil' } } }
        const viewer = new VehicleViewer(kit, vocabulary)
        const render = (view) => fragmentOf(viewer.render([{ value: 'm/x/2026/enduro', data }], new URL(`/bikebook?view=${view}`, window.location.href), null))
        const text = (element) => element.textContent.replace(/\\s+/g, ' ').trim()
        const rows = (root, heading) => [...[...root.querySelectorAll('section')].find((each) => new RegExp(`^${heading}`, 'i').test(text(each.querySelector('h2') ?? each)))
          .querySelectorAll('dl > div')].map((row) => [text(row.querySelector('dt')), text(row.querySelector('dd'))])
        const all = render('all')
        const overview = [...render('basics').querySelectorAll("[aria-label='Overview'] tbody tr")].map((row) => [text(row.querySelector('th')), text(row.querySelector('td'))])
        return { overview: overview.map(([label]) => label), groupset: overview.find(([label]) => label === 'Groupset')[1], suspension: rows(all, 'suspension'), frame: rows(all, 'frame') }
      })()
    JS
    expect(specs["overview"]).to eq(["Frame material", "Suspension front/rear", "Groupset"])
    # its maker, series and gear count, its groupset's tooltip the whole of it and the rest of its drivetrain
    expect(specs["groupset"]).to match(/\ASRAM · GX · 1x12 \? Groupset manufacturer: SRAM Groupset series: GX Groupset description: GX Eagle AXS Electronic: Yes Drivetrain: 1 Front, 12 Rear Chainring: 32\W*t Cogs: 10–\W*52\W*t\z/)
    expect(specs["suspension"]).to eq([["Front", "170 mm, lockout ? Travel: 170 mm Spring: Air Lockout: Yes"], ["Rear", "160 mm, 157.5 × 62.5 mm shock, coil"]])
    expect(specs["frame"]).to include(["Coil compatible", "Yes"])

    find("[aria-label='Remove Aventón Level 2 Step-Through']").click
    expect(page).to have_css("article", count: 1)
    expect(page).to have_no_css("[data-comparison]")
    expect(page).to have_css(".hw-combobox__chip", count: 1)
    # one model still gets the table and the overlay, its frame alone
    click_link "Sizes & geometry"
    expect(page).to have_css("[aria-label='Sizes & geometry comparison'] thead th", count: 2).and have_css("[aria-label='Geometry overlay'] svg[role='img'] > g", count: 1)

    logged_count = logged.count
    page.go_back
    expect(page).to have_css("article", count: 2)
    expect(page).to have_css(".hw-combobox__chip", count: 2)
    # a history step is no new search, though its render re-runs its combobox's
    page.evaluate_script("new Promise((resolve) => setTimeout(resolve, 1100))")
    expect(logged.count).to eq logged_count

    # The JSON panel opens beside its card
    first("[aria-label='Toggle JSON']").click
    expect(page).to have_css(".twjson-panel code", text: '"model": "Level 4 REC Step-Through"')

    # By keyboard, the panel's own More filters takes the focus that opening it hides, and closing hands it back
    trigger = "[role='button'][aria-controls='vehicle-filters']"
    find(trigger).send_keys(:enter)
    expect(page).to have_css("#vehicle-filters #{trigger}:focus")
    find("#{trigger}:focus").send_keys(:enter)
    expect(page).to have_no_css("#vehicle-filters")
    expect(page).to have_css("#{trigger}:focus", text: "More filters")

    # A filter's options count the catalog's models, and its chips come from them
    find("#{trigger}:focus").send_keys(:enter)
    # the classes are the US market's, which the visitor's country isn't
    expect(page).to have_no_field("US Class 2")
    # its own models, and none of a maker's sold elsewhere, as it sells a Kris Holm
    choose_option("Market", "United States")
    expect(page).to have_css("#vehicle-models-count", exact_text: "(26 matching models)")
    # a class matches the models carrying it, and out of class the catalog's own marker
    check "US Class 2"
    expect(page).to have_css("#vehicle-models-count", exact_text: "(18 matching models)")
    # a class is an e-vehicle's, which it checks, ruling out human powered without widening to every e-vehicle
    expect(page).to have_checked_field("e-Vehicle (motorized)").and have_field("Human powered (Acoustic)", checked: false, disabled: true)
    check "Out of Class"
    expect(page).to have_css("#vehicle-models-count", exact_text: "(19 matching models)")
    expect(page).to have_no_link("Clear filters")
    uncheck "US Class 2"
    uncheck "Out of Class"
    expect(page).to have_css("#vehicle-models-count", exact_text: "(23 matching models)")
    expect(page).to have_field("Human powered (Acoustic)", checked: false, disabled: false).and have_checked_field("e-Vehicle (motorized)")
    # as on /ebike-rules, a state on the three US classes keeps them and one with its own shows those,
    # each matching the models in its groups, leaving the other jurisdiction's unchecked
    check "US Class 2"
    choose_option("Jurisdiction", "California")
    expect(page).to have_checked_field("US Class 2")
    # but where a Class 3 can't have a throttle, the catalog marks one that does out of class in California alone
    expect(page).to have_css("#vehicle-models-count", exact_text: "(14 matching models)")
    uncheck "US Class 2"
    check "Out of Class"
    expect(page).to have_css("#vehicle-models-count", exact_text: "(5 matching models)")
    choose_option("Jurisdiction", "New Jersey")
    expect(page).to have_no_field("US Class 2")
    expect(page).to have_unchecked_field("Low-Speed Electric Bicycle")
    check "Out of Class"
    expect(page).to have_css("#vehicle-models-count", exact_text: "(1 matching model)")
    # cleared, it's the placeholder's United States
    clear_jurisdiction
    expect(page).to have_no_field("Low-Speed Electric Bicycle")
    expect(page).to have_unchecked_field("US Class 2").and have_unchecked_field("Out of Class")
    expect(page).to have_css("#vehicle-models-count", exact_text: "(23 matching models)")
    # a US class's tooltip names it, its description citing no IDs beside the one it shows
    find("button[aria-label='US Class 1 e-bike']").click
    expect(page).to have_css("[role='tooltip'] h3", exact_text: "US Class 1 e-bike", visible: true)
    expect(find("[role='tooltip'] p", text: "Every class is also a federal low-speed electric bicycle", visible: true).text).to end_with("low-speed electric bicycle.")
    expect(page).to have_unchecked_field("US Class 1")
    uncheck "e-Vehicle (motorized)"
    choose "Any market", allow_label_click: true
    expect(page).to have_css("#vehicle-models-count", exact_text: "(33 matching models)")
    find_field("Manufacturers").click
    find("#manufacturer-hw-listbox [role='option']", text: "Kris Holm (6)").click
    # picked by a click, it closes the list but keeps the focus, for another pick
    expect(page).to have_css("#manufacturer:focus[aria-expanded='false']")
    expect(page).to have_css("[data-async-id='manufacturer'] .hw-combobox__chip", text: "Kris Holm")
    expect(page).to have_css("#vehicle-models-count", exact_text: "(6 matching models)")
    # checked propulsions match any of them
    check "e-Vehicle (motorized)"
    expect(page).to have_css("#vehicle-models-count", exact_text: "(0 matching models)")
    check "Human powered (Acoustic)"
    expect(page).to have_css("#vehicle-models-count", exact_text: "(6 matching models)")
    expect(page).to have_current_path(/electric=0,1/)
    # a view's tab, written before the filters changed, keeps them and the open panel
    click_link "Components"
    expect(page).to have_current_path(/[?&]view=components\b/).and have_current_path(/electric=0,1/)
    expect(page).to have_checked_field("Human powered (Acoustic)").and have_css("[data-async-id='manufacturer'] .hw-combobox__chip", text: "Kris Holm")
    click_link "All"
    expect(page).to have_css("[data-comparison] article", count: 2)

    # closed, the applied filters can be cleared all at once, keeping the picks and view
    click_on "More filters", match: :first
    within("[aria-label='Applied filters']") { expect(page).to have_text("Kris Holm") }
    click_link "Clear filters"
    expect(page).to have_css("#vehicle-models-count", exact_text: "(33 matching models)")
    expect(page).to have_no_link("Clear filters").and have_no_css("[aria-label='Applied filters'] li")
    expect(page).to have_css(".hw-combobox__chip", count: 2).and have_css("[data-comparison] article", count: 2)
    expect(page).to have_no_current_path(/manufacturer|electric/)
    # by frame material, which the comparison lists, and handlebar type
    click_on "More filters", match: :first
    choose_option("Frame material", "Carbon or Composite")
    expect(page).to have_css("#vehicle-models-count", exact_text: "(2 matching models)")
    choose_option("Handlebar type", "Drop Bars")
    expect(page).to have_css("#vehicle-models-count", exact_text: "(1 matching model)")
    expect(page).to have_current_path(/[?&]frame_material=carbon\b/).and have_current_path(/[?&]handlebar_type=drop_bar\b/)
    within("#vehicle-filters") { click_link "Clear filters" }
    expect(page).to have_css("#vehicle-models-count", exact_text: "(33 matching models)")
    # and from the open panel, where the market, how it narrows and e-bike classification are nothing to clear, and stay
    # through a clear
    find_field("Market").click
    find("#market-hw-listbox [role='option']", text: "United States (US)").click
    # any market's models, as the clears above kept it
    expect(page).to have_css("#vehicle-models-count", exact_text: "(33 matching models)")
    choose "Only United States", allow_label_click: true
    expect(page).to have_css("#vehicle-models-count", exact_text: "(26 matching models)")
    check "US Class 2"
    expect(page).to have_css("#vehicle-models-count", exact_text: "(18 matching models)")
    expect(page).to have_no_link("Clear filters")
    choose_option("Suspension", "Rigid")
    within("#vehicle-filters") { click_link "Clear filters" }
    expect(page).to have_css("#vehicle-models-count", exact_text: "(18 matching models)")
    expect(page).to have_no_current_path(/suspension/)
    expect(page).to have_checked_field("US Class 2").and have_checked_field("e-Vehicle (motorized)").and have_field("Market", with: "United States (US)")
      .and have_checked_field("Only United States", visible: :all)
    expect(page).to have_current_path(/[?&]market=US\b/).and have_current_path(/[?&]electric=1,class_2(&|\z)/)
      .and have_current_path(/[?&]market_scope=only\b/)

    expect(asked).to be_empty

    # Five compare side by side, rather than wrapping onto rows
    page.current_window.resize_to(1440, 900)
    five = %w[m/aventon/2026/level_4_rec_step_through m/aventon/2022/level_2_step_through m/segway/2025/gt3_pro
      m/specialized/2025/haul_st m/sur_ron/2026/ultra_bee_hp_x_us].join(",")
    card_rows = -> { page.evaluate_script("new Set([...document.querySelectorAll('article')].map((card) => Math.round(card.getBoundingClientRect().top))).size") }
    scrolls_sideways = -> { page.evaluate_script("document.querySelector('[data-comparison] > div').scrollWidth > window.innerWidth") }
    # past three, the overview reaches past the page's column, which the search spans
    visit bikebook_path(vehicle_models: five)
    expect(page).to have_css("[aria-label='Overview comparison'] thead th", count: 6, wait: 10)
    width = ->(selector) { page.evaluate_script("document.querySelector(#{selector.to_json}).getBoundingClientRect().width") }
    expect(width.call("[aria-label='Overview comparison'] table")).to be > width.call("[data-bikebook--catalog-filters-target='vehicleCombobox']") + 100
    # the e-motos as /ebike-rules has them, one classified a motor vehicle and one too fast for a class, each under
    # the e-moto's tile, a tooltip of its card
    all("[aria-label='Overview comparison'] button[aria-label='E-moto, not an e-bike']", count: 2).first.click
    expect(page).to have_css("[role='tooltip'] h3", exact_text: "Not an e-bike", visible: true)
    click_link "Sizes & geometry"
    # the label column's header and the five vehicles'
    expect(page).to have_css("[aria-label='Sizes & geometry comparison'] thead th", count: 6)
    # a vehicle whose type's drawing takes a figure at its typical is its wheels alone, under a note naming those figures
    expect(page).to have_css("[aria-label='Geometry overlay'] p + ul li", exact_text: "Segway GT3 Pro doesn't list its Deck height or the " \
      "measures to calculate them, so only its wheels are drawn.")
    expect(page).to have_css("[aria-label='Geometry overlay'] p", exact_text: "Note: missing geometry information:")
    # the table at least the page's column, scrolling only past the window's width
    table_fit = page.evaluate_script(<<~JS)
      (() => {
        const table = document.querySelector("[aria-label='Sizes & geometry comparison'] table")
        const scroller = table.closest("[data-controller~='ui--table']")
        return [table.getBoundingClientRect().width, scroller.scrollWidth > scroller.clientWidth]
      })()
    JS
    expect(table_fit).to match([be >= 1248, false])
    click_link "All"
    expect(page).to have_css("[data-comparison] article", count: 5)
    expect(card_rows.call).to eq 1
    expect(scrolls_sideways.call).to be true
    # of a year the first lacks just the year, and of a drivetrain just the chip it lacks
    haul = find("article h1", text: "Haul ST").ancestor("article")
    marked = ->(heading, selector) { haul.find("h2", text: heading).ancestor("section").all(selector).map { it.text.strip } }
    expect(marked.call(/\Amodel years\z/i, "tr:last-child td.tw\\:spec-diff")).to eq(["2025"])
    expect(marked.call(/\Adrivetrain\z/i, "span.tw\\:rounded-sm.tw\\:spec-diff")).to eq(["9 Rear"])
    # an extra measurement's BB as the catalog's own labels write it
    expect(haul).to have_css("dt", exact_text: "BB drop low").and have_css("dt", exact_text: "BB Height")

    # and on a phone too, rather than stacking
    page.current_window.resize_to(390, 844)
    expect(card_rows.call).to eq 1
    expect(scrolls_sideways.call).to be true
    page.current_window.resize_to(1920, 1080)

    # up to ten, in the search and compared, the picks past them left off
    eleven = %w[m/aventon/2026/current_adv m/aventon/2026/current_exp m/aventon/2026/level_4_adv m/aventon/2026/level_4_adv_step_through
      m/aventon/2026/level_4_rec m/aventon/2026/level_4_rec_step_through m/aventon/2026/pace_5_rec_step_through m/aventon/2026/ramblas_adv
      m/aventon/2026/soltera_3_adv m/aventon/2022/level_2 m/aventon/2022/level_2_step_through]
    visit bikebook_path(vehicle_models: eleven.join(","))
    expect(page).to have_css("[aria-label='Overview comparison'] thead th", count: 11, wait: 10)
    expect(page).to have_css(".hw-combobox__chip", count: 10).and have_no_css(".hw-combobox__chip", text: "Level 2 Step-Through")
  end

  it "searches the visitor's market and shows their state's classes until others are chosen, leaving them out of the URL" do
    serve_bikebook_catalog
    page.driver.with_playwright_page { it.set_extra_http_headers("CF-IPCountry" => "CA") }
    logged = []
    page.driver.with_playwright_page { it.on("request", ->(request) { logged << request.url.split("?").last if request.url.include?(search_bikebook_path) }) }
    visit bikebook_path
    # its own models and those of makers it sells none of, but for e-vehicles
    expect(page).to have_css("#vehicle-models-count", exact_text: "(7 matching models)", wait: 10)
    type_into(vehicle_field, "haul")
    expect(page).to have_css(vehicle_option, count: 1, text: "$3,599.99").and have_no_css(vehicle_option, text: "(Canada)")
    # nor a maker's sold elsewhere, where it sells its own
    type_into(vehicle_field, "kh24")
    expect(page).to have_css(vehicle_option, count: 1).and have_css("#{vehicle_option}[data-value='m/kris_holm/2023/kh24']")
    # the URL says the search shows, but not what's typed or the visitor's own market
    expect(page).to have_current_path("/bikebook?search=1")
    # but a model's exact id finds it, though the market leaves it out, saying so rather than counting it
    type_into(vehicle_field, "m/specialized/2025/haul_st")
    expect(page).to have_css(".hw-combobox__group__label", exact_text: "(model doesn't match filters)")
    # named for the market it's sold in, which the visitor's isn't
    expect(page).to have_css(vehicle_option, count: 1, text: "Specialized Haul ST (United States)").and have_no_css(vehicle_option, text: "$3,599.99")
    type_into(vehicle_field, "m/specialized/2025/haul_st_ca")
    expect(page).to have_css(".hw-combobox__group__label", exact_text: "(1 matching model)")

    # its listbox closed, which covers the filters
    vehicle_field.send_keys(:escape)
    click_on "More filters", match: :first
    expect(page).to have_field("Market", with: "Canada (CA)")
    find_field("Market").click
    # by name rather than the catalog's order, which is by code, and only those with models
    # each with its code, as a state's shown, rather than a count; any market is how it narrows rather than one of them
    markets = all("#market-hw-listbox [role='option']").map(&:text)
    expect(markets).to eq ["Canada (CA)", "China (CN)", "United Arab Emirates (AE)", "United States (US)"]
    find_field("Market").send_keys(:escape)
    # named for the visitor's market
    expect(page).to have_checked_field("Prefer vehicles Canada", visible: :all)
    choose "Any market", allow_label_click: true
    expect(page).to have_css("#vehicle-models-count", exact_text: "(33 matching models)")
    # a model sold outside the visitor's market names where it is
    expect(find("[aria-label='Models to compare']")).to have_link(exact_text: "Kris Holm KH24 (United States)")
      .and have_link(exact_text: "Kris Holm KH24")
    expect(page).to have_current_path(/[?&]market_scope=any\b/)
    # each re-runs the vehicle combobox's search, logged once it settles, though only the market's scope changed
    page.evaluate_script("new Promise((resolve) => setTimeout(resolve, 1100))")
    expect(logged.last).to end_with "&market_scope=any&q=Specialized+Haul+ST+%282025%29"
    # its own models alone
    choose "Only Canada", allow_label_click: true
    expect(page).to have_css("#vehicle-models-count", exact_text: "(6 matching models)")
    type_into(find_field("Market"), "united")
    find("#market-hw-listbox [role='option']", text: "United States (US)").click
    expect(page).to have_css("#vehicle-models-count", exact_text: "(26 matching models)")
    # and then for the one picked
    expect(page).to have_checked_field("Only United States", visible: :all).and have_field("Prefer vehicles United States", visible: :all)
    expect(page).to have_current_path(/[?&]market=US\b/)
    page.evaluate_script("new Promise((resolve) => setTimeout(resolve, 1100))")
    expect(logged.last).to eq "count=0&market=US&market_scope=only&q=Specialized+Haul+ST+%282025%29"
    # and stays out of the collapsed filters' summary
    expect(find("[aria-label='Applied filters']", visible: :all).text(:all)).to be_empty

    # a market the catalog has no models in searches them all, with nothing for it to narrow
    page.driver.with_playwright_page { it.set_extra_http_headers("CF-IPCountry" => "JP") }
    visit bikebook_path
    expect(page).to have_css("#vehicle-models-count", exact_text: "(33 matching models)", wait: 10)
    expect(page).to have_css("fieldset[hidden] input[name='market_scope']", count: 3, visible: :all)

    # and a visitor Cloudflare can't place searches the US
    page.driver.with_playwright_page { it.set_extra_http_headers("CF-IPCountry" => "XX") }
    visit bikebook_path
    expect(page).to have_css("#vehicle-models-count", exact_text: "(26 matching models)", wait: 10)

    # a checked class keeps its jurisdiction in the URL, as another's would uncheck it
    page.driver.with_playwright_page { it.set_extra_http_headers("CF-IPCountry" => "US", "CF-Region" => "New Jersey") }
    visit bikebook_path
    expect(page).to have_no_css("[inert]", wait: 10)
    # its state left out of the closed filters' summary, and as a clear returns to it, nothing to clear
    expect(page).to have_no_css("[aria-label='Applied filters'] li", visible: :all)
    expect(page).to have_no_link("Clear filters")
    click_on "More filters", match: :first
    expect(page).to have_field("Jurisdiction", with: "New Jersey (NJ)", placeholder: "United States")
    expect_display_over("Market")
    expect_display_over("Jurisdiction")
    expect(page).to have_current_path("/bikebook?search=1&filters=1")
    check "Low-Speed Electric Bicycle"
    expect(page).to have_current_path(/[?&]jurisdiction=NJ\b/)
    # a checked class summarized without it
    expect(page).to have_css("[aria-label='Applied filters'] li", exact_text: "e-bike classification: Low-Speed Electric Bicycle", visible: :all)
    clear_jurisdiction
    expect(page).to have_current_path(/[?&]jurisdiction=US\b/)
    # and outside the US market there are none
    choose_option("Market", "Canada")
    expect(page).to have_no_field("Jurisdiction").and have_no_field("US Class 1")
  end

  it "titles a model picked alone for it, and drops the canonical as the page changes" do
    serve_bikebook_catalog
    canonical = "link[rel='canonical']"
    visit bikebook_path(vehicle_models: "m/aventon/2026/level_4_rec_step_through", view: "all")
    expect(page).to have_css("article h1", text: "Level 4 REC Step-Through", wait: 10)
    # its block leaves out its maker's primary market, which the index has
    expect(page).to have_css("div", text: /\AMarkets\s*United States\z/)
    expect(page).to have_title(/\AAventón Level 4 REC Step-Through/)
    expect(page).to have_css(canonical, visible: :all)
    # opened alone, its search hidden behind a tab of its type's, which shows it in place
    expect(page).to have_no_field("Select a bike, choose multiple to compare them")
    expect(all("nav[aria-label='Views'] a").map(&:text).last(2)).to eq(["All", "Search other bikes"])
    entries = page.evaluate_script("history.length")
    click_link "Search other bikes"
    expect(vehicle_field).to be_visible
    expect(vehicle_field).to match_css(":focus")
    expect(page).to have_no_link("Search other bikes")
    expect(page).to have_current_path("/bikebook?vehicle_models=m/aventon/2026/level_4_rec_step_through&view=all&search=1&vehicle_type=bike")
    expect(page).to have_css("[aria-label='Applied filters'] li", exact_text: "Vehicle types: Bike", visible: :all)
    # a step of its own, which back undoes, unlike a view's tab
    expect(page.evaluate_script("history.length")).to eq entries + 1

    type_into(vehicle_field, "level_2_step")
    retry_on_detach { find(vehicle_option, text: "Aventón Level 2 Step-Through").click }
    expect(page).to have_css("[data-comparison] article", count: 2)
    expect(page).to have_no_css(canonical, visible: :all)

    page.go_back
    expect(page).to have_css("article", count: 1)
    find("[aria-label='Remove Aventón Level 4 REC Step-Through']").click
    expect(page).to have_no_css("article")
    expect(page).to have_title("BikeBook", exact: true)

    # pasted and entered at once, an id is picked, though its search answers after the Enter
    vehicle_field.set("m/aventon/2026/level_4_rec_step_through")
    vehicle_field.send_keys(:enter)
    expect(page).to have_css("article h1", text: "Level 4 REC Step-Through")
    expect(page).to have_current_path("/bikebook?view=all&search=1&vehicle_type=bike&vehicle_models=m/aventon/2026/level_4_rec_step_through")

    # the BikeBook mark goes back to the empty search
    find("a[aria-label='BikeBook']").click
    expect(page).to have_no_css("article")
    expect(page).to have_current_path("/bikebook?search=1")

    # Filters with nothing picked say what they leave, and lead into the list or back to the filters
    visit bikebook_path(price_max: 3000)
    expect(page).to have_text("21 models match your filters.", wait: 10)
    # under the tips' card, over some of what they leave: a manufacturer not yet listed first, then an activity, then a
    # model group, and the one unicycle sold here, as its maker's Canadian ones are left out
    expect(page).to have_css("[data-bikebook--tips-target='prompt'] + p", text: "21 models match your filters.")
    featured = find("[aria-label='Models to compare']")
    expect(featured.all("a").map { it[:href][/vehicle_models=(.+)/, 1] }).to eq %w[m/aventon/2025/aventure_m m/aventon/2026/ramblas_adv
      m/aventon/2026/level_4_adv m/aventon/2026/level_4_adv_step_through m/specialized/2025/haul_st m/aventon/2025/abound_lr
      m/aventon/2025/aventure_3 m/aventon/2024/sinch_2_5 m/aventon/2025/pace_4_step_through m/aventon/2026/soltera_3_adv
      m/aventon/2024/soltera_2_5 m/kris_holm/2023/kh24_us]
    click_on "Search them"
    expect(page).to have_css(vehicle_option, minimum: 1)
    vehicle_field.send_keys(:escape)
    # titled without a year, over the years it's been sold
    haul_st = featured.find("li", text: "Specialized Haul ST")
    expect(haul_st).to have_link(exact_text: "Specialized Haul ST").and have_css("strong", exact_text: "2025–current")
    # each is picked as the search's option is
    haul_st.find("a").click
    expect(page).to have_css("[aria-label='Overview'] thead th", text: "Haul ST")
    expect(page).to have_current_path("/bikebook?price_max=3000&search=1&vehicle_models=m/specialized/2025/haul_st")
    # its classes' tiles as /ebike-rules has them, in order, the optional throttle's captioned
    overview = find("[aria-label='Overview']")
    expect(overview.all("td button[aria-label$=' e-bike']").map { it[:"aria-label"] }).to eq ["Class 2 e-bike", "Class 3 e-bike"]
    expect(overview).to have_css("td", text: "w/ optional throttle")
    expect(overview).to have_link("View on e-bike rules", href: "/ebike-rules?vehicle_models=m/specialized/2025/haul_st")
    # beside its years, its page on the manufacturer's site, the newest year's still up rather than one archived since
    expect(overview.find("tr", text: /\AYears/)).to have_link("manufacturer's page", href: "https://www.specialized.com/us/en/haul-st/p/277759")
    expect(page).to have_css(".hw-combobox__chip", text: "Specialized Haul ST")
    # filters leaving no legal e-bike feature what they do leave
    visit bikebook_path(vehicle_type: "e_motorcycle")
    expect(page).to have_css("[aria-label='Models to compare'] a", text: "Sur-Ron", wait: 10)
    # a price filter lifts the cap on what's featured
    # one given backwards, the way round it was meant
    visit bikebook_path(price_min: 20000, price_max: 10000, year_min: 2024)
    expect(page).to have_css("[aria-label='Models to compare'] a", text: "Crux 5 S-Level", wait: 10)
    # its amounts summarized with their thousands separated, unlike a year
    expect(all("[aria-label='Applied filters'] li", visible: :all).map { it.text(:all).strip }).to eq ["Year: from 2024", "Price: $10,000–$20,000"]
    expect(page).to have_current_path(/price_max=20000&price_min=10000/)
    # some around $6,000, even with the cheapest first
    visit bikebook_path(electric: 1, sort: "price", price_dir: "asc")
    expect(page).to have_css("[aria-label='Models to compare'] a[href$='vehicle_models=m/aventon/2026/current_exp']", wait: 10)
    # outside the US, an e-bike is legal by the market's own e-bike law, which the Canadian model is under with no US class
    visit bikebook_path(market: "CA")
    expect(page).to have_css("[aria-label='Models to compare'] a", text: "Specialized Haul ST", wait: 10)
    visit bikebook_path(primary_activity: "atb_gravel", price_max: 1500)
    expect(page).to have_text("No models match your filters.", wait: 10)
    # the example whose filters these are, active
    expect(page).to have_css("a[data-active='true']", count: 1, exact_text: "Gravel bikes under $1,500")
    click_on "Change filters"
    expect(page).to have_css("#vehicle-filters", visible: true)
    # and typed backwards
    fill_in "filter-year-min", with: "2026"
    find_field("filter-year-max").send_keys("2020", :tab)
    expect(page).to have_field("filter-year-min", with: "2020").and have_field("filter-year-max", with: "2026")
    expect(page).to have_css("[aria-label='Applied filters'] li", exact_text: "Year: 2020–2026", visible: :all)
    expect(page).to have_current_path(/[?&]year_min=2020\b/).and have_current_path(/[?&]year_max=2026\b/)
    # as the steps' More filters does, through the panel's own collapse, focusing its first field
    visit bikebook_path
    within("[aria-label='How to use BikeBook']", wait: 10) { click_on "More filters" }
    expect(page).to have_css("#vehicle-filters", visible: true).and have_css("#primary_activity:focus")
    expect(page).to have_css("[aria-controls='vehicle-filters'][aria-expanded='true']", minimum: 1)
    expect(page).to have_current_path("/bikebook?search=1&filters=1")

    # one the catalog has out of class in California is the e-moto's tile there, one whose optional throttle would put it
    # there its Class 3 then the e-moto's outlined, each e-moto's with California's ID, and their classes' again in another state
    visit bikebook_path(vehicle_models: "m/aventon/2026/level_4_adv,m/specialized/2025/haul_st", jurisdiction: "CA", filters: 1)
    tiles = -> { all("[aria-label='Overview comparison'] td:has(button[aria-label$='e-bike'])").map { |cell| cell.all("button[aria-label$='e-bike']").map { it[:"aria-label"] } } }
    expect(page).to have_css("[aria-label='Overview comparison'] td button[aria-label='E-moto, not an e-bike']", count: 2, wait: 10)
    expect(tiles.call).to eq [["E-moto, not an e-bike"], ["Class 3 e-bike", "E-moto, not an e-bike"]]
    expect(all("[aria-label='Overview comparison'] td button[aria-label$='e-bike'] + [role='tooltip'] code", visible: :all).map { it.text(:all).strip })
      .to eq ["evc/out_of_class/us/ca", "evc/us/class_3", "evc/out_of_class/us/ca"]
    choose_option("Jurisdiction", "Colorado")
    expect(page).to have_no_css("[aria-label='Overview comparison'] td button[aria-label='E-moto, not an e-bike']")
    expect(tiles.call).to eq [["Class 2 e-bike", "Class 3 e-bike"], ["Class 2 e-bike", "Class 3 e-bike"]]

    # a California visitor's e-bikes are legal there, which a Class 3 with a stock throttle isn't
    page.driver.with_playwright_page { it.set_extra_http_headers("CF-IPCountry" => "US", "CF-Region" => "California") }
    visit bikebook_path(price_max: 3000)
    featured = find("[aria-label='Models to compare']", wait: 10)
    expect(featured).to have_css("a", count: 12)
    picks = featured.all("a").map { it[:href][/vehicle_models=(.+)/, 1] }
    expect(picks).to include("m/aventon/2025/aventure_m")
    expect(picks).not_to include("m/aventon/2026/level_4_adv", "m/aventon/2026/level_4_adv_step_through")

    # Price leads the order once clicked, and a second click turns it around
    prices = ->(list) { list.all("li").map { it.text[/\$([\d,]+)/, 1].to_s.delete(",").to_i } }
    click_on "More filters", match: :first
    within("#vehicle-filters") { click_on "Price" }
    expect(page).to have_current_path(/[?&]sort=price\b/).and have_css("#vehicle-filters button[aria-pressed='true']", text: "Price")
    expect(page).to have_css("[aria-label='Models to compare']") { (listed = prices.call(it)) == listed.sort.reverse }
    within("#vehicle-filters") { click_on "Price" }
    expect(page).to have_current_path(/[?&]price_dir=asc\b/)
    expect(page).to have_css("[aria-label='Models to compare']") { (listed = prices.call(it)) == listed.sort && listed.uniq.size > 1 }
  end

  it "keeps each compared vehicle's size in the URL, the others the first's by name, else nearest it for its riders or by top tube, unless picked" do
    serve_bikebook_catalog
    visit bikebook_path(vehicle_models: "m/aventon/2026/current_adv,m/aventon/2026/current_exp", view: "geometry")
    expect(page).to have_css("[aria-label='Sizes & geometry comparison'] tbody th", exact_text: "Size", wait: 10)

    # sizes no fixture has: a name read the ways it's written, else the nearest for their riders' heights where both list
    # them, else the nearest top tube, reach breaking a tie, then medium
    chosen = page.evaluate_script(<<~JS)
      (async () => {
        const { chosenSizes } = await import('bikebook/sizes')
        const size = (name, topTube, reach, riders = {}) => ({ name, geometry: { top_tube_effective: topTube, reach, ...riders } })
        const riders = (min, max) => ({ min_rider_height: min, max_rider_height: max })
        const vehicle = (key, ...sizes) => ({ key, data: { sizes: sizes.map((each) => typeof each === 'string' ? { name: each } : each) } })
        const names = (vehicles, options) => chosenSizes(vehicles, options).map((each) => each?.name ?? 'none')
        const canyon = vehicle('canyon', size('S', 546, 390), size('M', 555, 393), size('L', 569, 401))
        const bianchi = vehicle('bianchi', size('53', 536, 393), size('55', 550, 397), size('57', 560, 402))
        return [
          names([canyon, bianchi]),
          names([bianchi, canyon], { preferred: size('XL', 559, 400) }),
          names([vehicle('a', 'S', 'M', 'L'), vehicle('b', 'Regular', 'Large'), vehicle('c', 'S/M', 'M/L'), vehicle('d')]),
          names([vehicle('a', 'Small', 'Medium'), vehicle('b', 'XS', 'S', 'M'), vehicle('c', 'MD', 'LG')], { preferred: { name: 'Small' }, picked: { c: 'LG' } }),
          // a name over a size that fits nearer
          names([vehicle('yeti', size('MD', 594, 470, riders(1650, 1800))), vehicle('niner', size('S', 580, 455, riders(1600, 1750)), size('M', 600, 475, riders(1720, 1870)))]),
          // a top tube nearer the 55's than the M's riders are, which the riders' heights win over
          names([vehicle('trek', size('56', 560, 395, riders(1700, 1780))), vehicle('kona', size('55', 558, 396, riders(1550, 1650)), size('M', 575, 405, riders(1680, 1790)))]),
          // one with no tallest rider, which shares more of them with the size it overlaps further
          names([vehicle('current', size('XL', 650, 420, riders(1854, null))), vehicle('level', size('M/L', 632, 445, riders(1800, 1890)), size('L/XL', 649, 460, riders(1900, 1950)))])
        ]
      })()
    JS
    expect(chosen).to eq([["M", "55"], ["57", "M"], ["M", "Regular", "S/M", "none"], ["Small", "S", "LG"], ["MD", "M"], ["56", "M"], ["XL", "L/XL"]])

    # a rendered size is its option's selected attribute, which a pick alone doesn't set, so it waits out the render
    size_select = ->(model) { find("select[aria-label='Size of #{model}']") }
    expect_size = ->(model, size) { expect(page).to have_css("select[aria-label='Size of #{model}'] option[selected]", exact_text: size) }
    expect_size.call("Current ADV", "Medium")
    expect_size.call("Current EXP", "Medium")

    overlay = find("[aria-label='Geometry overlay'] svg[role='img']")
    medium = [overlay[:viewBox], overlay.find("g > path", match: :first, visible: :all)[:d]]
    size_select.call("Current ADV").select("Large")
    expect_size.call("Current EXP", "Large")
    # the overlay draws each in its size
    within("[aria-label='Geometry overlay']") do
      expect(first("ul").all("li").map(&:text)).to eq(["Aventón Current ADV Large", "Aventón Current EXP Large"])
      # to the same scale, so the larger frame draws larger
      expect(page).to have_css("svg[role='img'][viewBox='#{medium.first}']")
      expect(find("svg[role='img'] g > path", match: :first, visible: :all)[:d]).not_to eq medium.last
      # the leftmost column's frame lowest
      expect(all("svg[role='img'] > g > title", visible: :all).map { it.text(:all) }).to eq(["Aventón Current ADV, Large", "Aventón Current EXP, Large"])
      # the first's over the other, faded, until its legend button's pressed again, and another's or none goes on the URL
      faded = -> { all("svg[role='img'] > g", visible: :all).map { it[:opacity] } }
      expect(page).to have_css("button[aria-pressed='true']", count: 1, text: "Current ADV")
      expect(faded.call).to eq([nil, "0.2"])
      # each frame's tires, and no rims
      expect(all("svg[role='img'] > g", visible: :all).map { it.all("circle[fill='none']", visible: :all).count }).to eq([2, 2])
      expect(find("svg[role='img'] > use", visible: :all)[:href]).to eq "#geometry-frame-0"
      wait_for_stimulus("bikebook--geometry-overlay")
      click_on "Aventón Current ADV"
      expect(page).to have_no_css("button[aria-pressed='true']")
      expect(faded.call).to eq([nil, nil])
      expect(page).to have_current_path(/[?&]overlay_selected=none(&|\z)/)
      # a frame clicked as its button is, its copy drawn over the rest as well as the frame itself, here halfway along a
      # tube, once it's done moving to its new size
      tube = page.evaluate_script(<<~JS)
        (async (path) => {
          const point = () => {
            const { x, y } = path.getPointAtLength(path.getTotalLength() / 2)
            const { x: left, y: top } = new DOMPoint(x, y).matrixTransform(path.getScreenCTM())
            return [left, top]
          }
          for (let last = null; ; await new Promise((resolve) => setTimeout(resolve, 100))) {
            const now = point()
            if (last && now.every((value, index) => value === last[index])) return now
            last = now
          }
        })(document.querySelector("#geometry-frame-1 path"))
      JS
      page.driver.with_playwright_page { it.mouse.click(*tube) }
      expect(page).to have_css("button[aria-pressed='true']", count: 1, text: "Current EXP")
      expect(faded.call).to eq(["0.2", nil])
      expect(find("svg[role='img'] > use", visible: :all)[:href]).to eq "#geometry-frame-1"
      expect(page).to have_current_path(%r{[?&]overlay_selected=m/aventon/2026/current_exp(&|\z)})
      # where the copy draws that tube, over the frame's own
      page.driver.with_playwright_page { it.mouse.click(*tube) }
      expect(page).to have_no_css("button[aria-pressed='true']")
      click_on "Aventón Current EXP"
      expect(page).to have_css("button[aria-pressed='true']", count: 1, text: "Current EXP")
    end
    # which a render keeps
    size_select.call("Current ADV").select("Medium")
    expect_size.call("Current EXP", "Medium")
    expect(page).to have_css("[aria-label='Geometry overlay'] button[aria-pressed='true']", count: 1, text: "Current EXP")
    # a figure's letter lights it on each model's drawing, card and comparison row, until either's clicked again
    first("section[aria-label$=' sizes'] svg[role='img'] [data-figure='reach'] text").click
    expect(page).to have_current_path(/[?&]figure=reach(&|\z)/)
    expect(page).to have_css("section[aria-label$=' sizes'] svg [data-figure='reach'][stroke='#3397dc']", count: 2)
    expect(find("[aria-label='Sizes & geometry comparison'] tbody tr", text: /\AReach/)).to have_css("td[class*='3397dc']", count: 2)
    first("section[aria-label$=' sizes'] a[aria-label='Highlight Reach'][class*='3397dc']").click
    expect(page).to have_no_current_path(/[?&]figure=/)
    expect(page).to have_no_css("svg [stroke='#3397dc']")
    # one a size doesn't list stays its own color, its value as drawn above that size's geometry
    first("section[aria-label$=' sizes'] svg[role='img'] [data-figure='bb_height'] text").click
    expect(page).to have_css("section[aria-label$=' sizes'] svg [data-figure='bb_height'][stroke='#9a8fc4'][stroke-width='2.5']", minimum: 1)
    expect(page).to have_css("[data-bikebook--figure-note-target='note'][data-figure='bb_height']:not([class~='tw:hidden'])", text: /\A[A-Z]BB Height[[:space:]]+\d+[[:space:]]?mm\z/, minimum: 1)
    # a frame's points in mm from the bottom bracket, its height there from the wheels' radius where it lists no drop
    frames = page.evaluate_script(<<~JS)
      import('bikebook/frame_geometry').then(({ frameGeometry }) => {
        const data = { wheels: [{ bsd: 622, tire_width: 40, position: ['front', 'rear'] }] }
        const geometry = { reach: 400, stack: 600, head_angle: 72, head_tube: 150, chainstay: 420, wheelbase: 1020, seat_angle: 73, seat_tube_ct: 500, fork_rake: 45 }
        const frame = (extra, components, more = {}) => frameGeometry({ ...data, ...more, components }, { geometry: { ...geometry, ...extra } })
        const round = (point) => point.map(Math.round)
        const { rearAxle, frontAxle, headBottom, seatTop, seatBottom, bottomBracketHeight, calculated } = frame({ bb_drop: 70 })
        const wheelless = frame({ bb_drop: 70, bb_height: 290, trail: 70 }, [], { wheels: [] })
        const bmx = frame({ bb_drop: 70, reach: null, stack: null, head_tube: null, fork_rake: null, top_tube_effective: 540 }, [], { primary_activity: 'bmx' })
        const road = frame({ bb_drop: 70 }, [], { wheels: [{ bsd: 622, position: ['front', 'rear'] }], primary_activity: 'road_aero' })
        return [[rearAxle, frontAxle, headBottom, seatTop, seatBottom].map(round), bottomBracketHeight, calculated, round(frame({ bb_height: 281 }).rearAxle),
          frame({ bb_drop: 70, seat_tube_ct: null }).calculated, frame({ bb_drop: 70, fork_rake: null }).calculated,
          frame({ bb_drop: 70, fork_rake: null, wheelbase: null }).missing,
          (({ assumed, typicalKind }) => [assumed, typicalKind])(frame({ bb_drop: 70, fork_rake: null, wheelbase: null }, [], { primary_activity: 'road_biking' })),
          round(frame({ bb_drop: 70, fork_rake: null, wheelbase: null }, [{ type: 'fork', dimensions: { offset: 50 } }]).frontAxle),
          round(frame({ bb_drop: 70, fork_rake: null, wheelbase: null, trail: 70 }).frontAxle),
          round(frame({ bb_drop: 70, head_tube: null, fork_length_a2c: 400 }).headBottom), frame({ bb_drop: 70, head_tube: null }).missing,
          round(frame({ bb_drop: 70, extra_measurements: { seat_tube_angle_actual_degrees: 68 } }).seatBottom),
          ...[frame({ bb_drop: 70, reach: null, stack: null, top_tube_effective: 580, fork_length_a2c: 395 })].map((each) => [round(each.headTop), each.calculated]),
          frame({ bb_drop: 70 }, [], { wheels: [] }).missing, [wheelless.rearRadius, Math.round(wheelless.frontRadius), wheelless.calculated],
          frameGeometry({}, { geometry: { top_tube_effective: 560 } }).missing.length, [round(bmx.headTop), bmx.calculated, bmx.assumed],
          [road.rearRadius, road.typicalWheel],
          frame({ bb_drop: 70 }, [{ type: 'tire', dimensions: { width: 30 } }], { wheels: [{ bsd: 622, position: ['front', 'rear'] }] }).rearRadius, frameGeometry(data, { geometry: { wheelbase: 1020 } }),
          (({ missing, assumed }) => [missing, assumed])(frame({ bb_drop: 70, reach: null, stack: null, head_tube: null, fork_rake: null }, [], { primary_activity: 'bmx' }))]
      })
    JS
    # the front axle from the fork's rake, or its fork's or its trail's where the size lists none, a rake from where its
    # wheelbase puts the front axle, and without any, its kind's or no frame; a head tube from the fork's length, and without it none; a seat tube slacker than its effective angle ending
    # on the down tube; the head tube's top from the fork and top tube; wheels from the bottom bracket's height and drop,
    # and the trail; a BMX's fork and head tube a typical one's, and a road bike's tire; a tire its component's where its
    # wheel lists none; and without any figure that sizes a frame, only its wheels - but a BMX's, on its typical fork and
    # head tube from where its wheelbase and head angle put its front axle and steering axis
    expect(frames).to eq([[[-414, 70], [606, 70], [446, 457], [-146, 478], [0, 0]], 281, [], [-414, 70], ["seat_tube_ct"], ["fork_rake"], ["fork_rake"],
      [["fork_rake"], "road bike"],
      [625, 70], [616, 70], [453, 438], ["head_tube"], [33, 34], [[405, 572], %w[reach stack]], ["wheel_size"], [360, 361, ["wheel_size"]], 9,
      [[367, 567], %w[reach stack], %w[fork_rake fork_length_a2c head_tube]], [339, {"bsd" => 622, "tire" => 28, "rimListed" => true}], 341,
      {"missing" => %w[reach stack top_tube_effective front_center head_tube], "wheels" => {"rearRadius" => 351, "frontRadius" => 351, "wheelbase" => 1020}},
      [[], %w[fork_rake fork_length_a2c head_tube]]])
    # a BMX's unlisted seat tube runs its top tube over its standover above the bottom bracket, the same as over its
    # standover from the ground, else is its kind's typical
    seat_tubes = page.evaluate_script(<<~JS)
      import('bikebook/frame_geometry').then(({ frameGeometry }) => {
        const data = { wheels: [{ bsd: 622, tire_width: 40, position: ['front', 'rear'] }], primary_activity: 'bmx' }
        const geometry = { head_angle: 72, chainstay: 420, wheelbase: 1020, seat_angle: 73, fork_rake: 45, bb_drop: 70 }
        const seatTube = (extra) => Math.round(Math.hypot(...frameGeometry(data, { geometry: { ...geometry, ...extra } }).seatTop))
        return [seatTube({ standover_above_bb: 235 }), seatTube({ standover: 516 }), seatTube({})]
      })
    JS
    expect(seat_tubes).to eq([128, 128, 240])

    size_select.call("Current EXP").select("Small")
    expect_size.call("Current EXP", "Small")
    size_select.call("Current ADV").select("Extra Large")
    expect_size.call("Current ADV", "Extra Large")
    expect_size.call("Current EXP", "Small")
    expect(page).to have_current_path(/[?&]vehicle_sizes=Extra\+Large,Small(&|\z)/)
    # the geometry is each one's size, and less of it is red
    expect(find("[aria-label='Sizes & geometry comparison'] tr", text: "Reach")).to have_css("td", text: /\A425\.5.+−74\.7/m)
      .and have_css(".tw\\:text-red-700", text: "−74.7")
    # in centimeters alone, without an imperial viewer's feet and inches
    expect(find("[aria-label='Sizes & geometry comparison'] tr", text: "Wheelbase").all("td").map(&:text)).to all(match(/\A[\d.]+\W*cm(\s*[−+][\d.]+\W*cm|\s*-)?\z/))
    # the wheelbase out to each wheel's edge, below it and in its units, and as with it, less of it is red
    expect(all("[aria-label='Sizes & geometry comparison'] th[scope='row']").map(&:text).last(4)).to match(["Standover", "Wheelbase", /\AOverall length \(est\.\)/, "Weight"])
    overall_length = find("[aria-label='Sizes & geometry comparison'] tr", text: "Overall length")
    expect(overall_length.all("td").map(&:text)).to match([/\A203\.8\W*cm\z/, /\A194\.6\W*cm\s*−9\.2\W*cm\z/])
    expect(overall_length).to have_css(".tw\\:text-red-700", text: "−9.2")
    # each one's drawing at the same scale and on the same ground, so they line up across the cards
    view_boxes = all("section[aria-label$=' sizes'] figure svg").map { it["viewBox"].split.map(&:to_i) }
    expect(view_boxes.size).to eq 2
    expect(view_boxes.map { it.drop(1) }.uniq.size).to eq 1

    # narrow enough that each one's sizes scroll
    page.current_window.resize_to(900, 900)
    visit current_url
    expect(page).to have_css("[aria-label='Sizes & geometry comparison']", wait: 10)
    expect_size.call("Current ADV", "Extra Large")
    expect_size.call("Current EXP", "Small")
    click_link "All"
    expect(page).to have_css("[data-comparison] article", count: 2)
    # each one's sizes ring its size
    card = ->(model) { find("article h1", exact_text: model).ancestor("article") }
    current_size = ->(model) { card.call(model).all("[aria-current='true'] h3", visible: :all).map { it.text(:all) } }
    expect(current_size.call("Current ADV")).to eq(["Extra Large"])
    expect(current_size.call("Current EXP")).to eq(["Small"])
    # another size's name picks it for its vehicle in place, and the picked one is no link
    ringed = ->(model, size) { expect(card.call(model)).to have_css("[aria-current='true'] h3", exact_text: size, visible: :all) }
    expect(card.call("Current EXP")).to have_no_link("Small")
    card.call("Current EXP").click_link("Medium")
    ringed.call("Current EXP", "Medium")
    card.call("Current EXP").click_link("Small")
    ringed.call("Current EXP", "Small")
    # and scrolls it to the middle, as far as the sizes scroll: [how far it's scrolled, how far off center it can't get]
    wait_for_stimulus("ui--tabs")
    centering = ->(model) {
      page.evaluate_script(<<~JS)
        (() => {
          const article = [...document.querySelectorAll('article')].find((each) => each.querySelector('h1')?.textContent.trim() === #{model.to_json})
          const scroller = article.querySelector('[data-controller~="ui--tabs"]')
          const [outer, inner] = [scroller, scroller.querySelector('[aria-current="true"]')].map((element) => element.getBoundingClientRect())
          const centered = scroller.scrollLeft + inner.left + inner.width / 2 - (outer.left + outer.width / 2)
          const reachable = Math.min(Math.max(centered, 0), scroller.scrollWidth - scroller.clientWidth)
          return [scroller.scrollLeft, Math.abs(reachable - scroller.scrollLeft)]
        })()
      JS
    }
    expect(centering.call("Current ADV")).to match([be > 0, be < 2])
    expect(centering.call("Current EXP")).to match([0, be < 2])
    page.current_window.resize_to(1920, 1080)

    # a size stays with its vehicle as the vehicles change, through one alone, which nothing compares, and a card's
    # removal leaves the reader where they were, as far as the shorter page reaches
    remove = find("[aria-label='Remove Aventón Current ADV']")
    scroll_to(remove, align: :top)
    scrolled = page.evaluate_script("window.scrollY")
    remove.click
    expect(page).to have_css(".hw-combobox__chip", count: 1)
    expect(page).to have_no_css("[aria-label$='comparison']")
    expect(page.evaluate_script("window.scrollY")).to be > 0
    reachable = page.evaluate_script("Math.min(#{scrolled}, document.documentElement.scrollHeight - window.innerHeight)")
    expect(page.evaluate_script("window.scrollY")).to be_within(2).of(reachable)
    expect(vehicle_field).not_to match_css(":focus")
    expect(page).to have_current_path(/[?&]vehicle_sizes=Small(&|\z)/)

    # Small's riders are Soltera's Small's, though its top tube is nearer Soltera's Medium
    type_into(vehicle_field, "soltera")
    retry_on_detach { find(vehicle_option, text: "Aventón Soltera 3 ADV").click }
    expect(page).to have_css("[data-comparison] article", count: 2)
    click_link "Sizes & geometry"
    expect_size.call("Soltera 3 ADV", "Small")
    expect_size.call("Current EXP", "Small")
    # the same wheel size on tires far enough apart, each with its estimated diameter after its model's name
    diameters = -> { all("[aria-label='Geometry overlay'] li", text: "diameter").map { it.text.gsub(/[[:space:]]+/, " ") } }
    expect(page).to have_css("[aria-label='Geometry overlay'] p", exact_text: "Note: you're comparing different diameter wheels and tires:")
    expect(diameters.call).to eq(["Aventón Current EXP's 700 C wheels with 64 mm tires are approximately 750 mm diameter",
      "Aventón Soltera 3 ADV's 700 C wheels with 38 mm tires are approximately 698 mm diameter"])
    expect(page).to have_css("[aria-label='Geometry overlay'] li em", exact_text: "Aventón Current EXP")
    # every model's wheels in its size, front and rear in one sentence where they differ, the rear on S though only its front
    # differs enough
    sized = page.evaluate_script(<<~JS)
      (async () => {
        const catalog = (file) => fetch(`https://bikebook-catalog.bikeindex.org/catalog/${file}`).then((response) => response.json())
        const [{ VehiclePresenter }, { geometryOverlay, overlayFrames }, { render }, { kit }, vocabulary] = await Promise.all([
          import('bikebook/vehicle_presenter'), import('bikebook/templates/vehicles/geometry_overlay'), import('lit-html'),
          catalog('kit.json'), catalog('vocabulary.json')])
        const presenter = new VehiclePresenter(kit, vocabulary)
        const geometry = { reach: 450, stack: 620, head_angle: 64, chainstay: 445, bb_drop: 20, seat_angle: 77, head_tube: 120, fork_rake: 44 }
        const road = { model: 'Road', sizes: [{ name: 'M', geometry }], wheels: [{ bsd: 622, tire_width: 25, position: ['front', 'rear'] }] }
        const mullet = { model: 'Mullet', sizes: ['S', 'L', 'XL'].map((name) => ({ name, geometry })), wheels: [
          { bsd: 622, tire_width: 64, position: ['front'] }, { bsd: 622, tire_width: 64, position: ['rear'], sizes: ['XL'] },
          { bsd: 584, tire_width: 64, position: ['rear'], sizes: ['L'] },
          { bsd: 559, tire_width: 64, position: ['rear'], sizes: ['S'] }] }
        return mullet.sizes.map((size) => {
          const vehicles = [{ data: road }, { data: mullet }]
          const sizes = [road.sizes[0], size]
          const container = document.createElement('div')
          render(geometryOverlay({ presenter, vehicles, sizes, frames: overlayFrames(vehicles, sizes) }), container)
          return [...container.querySelectorAll('li')].map((item) => item.textContent.replace(/\\s+/g, ' ').trim()).filter((text) => text.includes('diameter'))
        })
      })()
    JS
    road = "Road's 700 C wheels with 25 mm tires are approximately 672 mm diameter"
    front = "Mullet's front 700 C wheel with a 64 mm tire is approximately 750 mm diameter"
    expect(sized).to eq([[road, "#{front}, its rear 26in wheel with a 64 mm tire is approximately 687 mm diameter"],
      [road, "#{front}, its rear 650 B wheel with a 64 mm tire is approximately 712 mm diameter"],
      [road, "Mullet's 700 C wheels with 64 mm tires are approximately 750 mm diameter"]])
    expect(page).to have_current_path(/[?&]vehicle_sizes=Small(&|\z)/)

    # one frame to draw is drawn alone, and the overlay says what the other is missing, as it does with none to draw
    lone = page.evaluate_script(<<~JS)
      (async () => {
        const catalog = (file) => fetch(`https://bikebook-catalog.bikeindex.org/catalog/${file}`).then((response) => response.json())
        const [{ VehiclePresenter }, { geometryOverlay, overlayFrames }, { render }, { kit }, vocabulary] = await Promise.all([
          import('bikebook/vehicle_presenter'), import('bikebook/templates/vehicles/geometry_overlay'), import('lit-html'),
          catalog('kit.json'), catalog('vocabulary.json')])
        const presenter = new VehiclePresenter(kit, vocabulary)
        const geometry = { reach: 450, stack: 620, head_angle: 64, chainstay: 445, bb_drop: 20, seat_angle: 77, head_tube: 120, fork_rake: 44 }
        const road = { model: 'Road', sizes: [{ name: 'M', geometry }], wheels: [{ bsd: 622, tire_width: 25, position: ['front', 'rear'] }] }
        const bare = { model: 'Bare', sizes: [{ name: 'M' }] }
        const vehicles = [{ data: road }, { data: bare }]
        const sizes = [road.sizes[0], bare.sizes[0]]
        const container = document.createElement('div')
        render(geometryOverlay({ presenter, vehicles, sizes, frames: overlayFrames(vehicles, sizes) }), container)
        const undrawn = document.createElement('div')
        render(geometryOverlay({ presenter, vehicles: [vehicles[1]], sizes: [sizes[1]], frames: overlayFrames([vehicles[1]], [sizes[1]]) }), undrawn)
        return [container, undrawn].map((each) => [each.querySelectorAll("svg[role='img'] > g").length, [...each.querySelectorAll('li')].at(-1).textContent.replace(/\\s+/g, ' ').trim()])
      })()
    JS
    bare = "Bare doesn't list its Reach, Stack, Top Tube (effective), Front Centre and Head Tube or the measures to calculate them, so it can't be drawn."
    expect(lone).to eq([[1, bare], [0, bare]])
    # a frame's stem left out is said only beside another's that's drawn
    stems = page.evaluate_script(<<~JS)
      (async () => {
        const catalog = (file) => fetch(`https://bikebook-catalog.bikeindex.org/catalog/${file}`).then((response) => response.json())
        const [{ VehiclePresenter }, { geometryOverlay, overlayFrames }, { render }, { kit }, vocabulary] = await Promise.all([
          import('bikebook/vehicle_presenter'), import('bikebook/templates/vehicles/geometry_overlay'), import('lit-html'),
          catalog('kit.json'), catalog('vocabulary.json')])
        const presenter = new VehiclePresenter(kit, vocabulary)
        const geometry = { reach: 450, stack: 620, head_angle: 64, chainstay: 445, bb_drop: 20, seat_angle: 77, head_tube: 120, fork_rake: 44 }
        const road = (model, extra = {}) => ({ model, sizes: [{ name: 'M', geometry: { ...geometry, ...extra } }], wheels: [{ bsd: 622, tire_width: 25, position: ['front', 'rear'] }] })
        return [[road('Stemmed', { stem_length: 80 }), road('Stemless')], [road('Stemless'), road('Also stemless')]].map((datas) => {
          const vehicles = datas.map((data) => ({ data }))
          const sizes = datas.map(({ sizes }) => sizes[0])
          const container = document.createElement('div')
          render(geometryOverlay({ presenter, vehicles, sizes, frames: overlayFrames(vehicles, sizes) }), container)
          return [...container.querySelectorAll('li')].map((item) => item.textContent.replace(/\\s+/g, ' ').trim()).filter((text) => text.includes('Stem Length'))
        })
      })()
    JS
    expect(stems).to eq([["Stemless doesn't list its Stem Length, so its stem and handlebar aren't drawn."], []])

    # a cargo bike's cargo area on its size's card, its length lettered as its drawing measures it along the deck
    cargo = page.evaluate_script(<<~JS)
      (async () => {
        const catalog = (file) => fetch(`https://bikebook-catalog.bikeindex.org/catalog/${file}`).then((response) => response.json())
        const [{ VehiclePresenter }, { geometryCard }, { cycleDrawing }, { render }, { kit }, vocabulary] = await Promise.all([
          import('bikebook/vehicle_presenter'), import('bikebook/templates/vehicles/geometry_card'), import('bikebook/templates/vehicles/cycle_drawing'),
          import('lit-html'), catalog('kit.json'), catalog('vocabulary.json')])
        const data = { type: 'cargo_bike', cargo: { length: 600, width: 500, volume: 120 }, sizes: [{ name: 'One Size', geometry: { wheelbase: 1800 } }] }
        const { legend } = cycleDrawing({ type: data.type, data, size: data.sizes[0], kit })
        const letters = new Map(legend.filter(({ letter }) => letter).map(({ key, letter }) => [key, letter]))
        const container = document.createElement('div')
        render(geometryCard({ presenter: new VehiclePresenter(kit, vocabulary), size: data.sizes[0], others: [], letters, cargo: data.cargo }), container)
        const heading = [...container.querySelectorAll('h4')].find((each) => each.textContent === 'Cargo')
        return [legend.find(({ key }) => key === 'cargo.length'), heading.nextElementSibling.textContent]
      })()
    JS
    expect(cargo.first).to include("label" => "Cargo length", "value" => 600, "listed" => true)
    expect(cargo.last.gsub(/[[:space:]]/, " ")).to eq "#{cargo.first["letter"]}Length600 mmWidth500 mmVolume120 L"
    # a bottom bracket above the axles, as a BMX's is, drops a negative amount
    bb_drop = page.evaluate_script(<<~JS)
      import('bikebook/templates/vehicles/cycle_drawing').then(({ cycleDrawing }) => {
        const data = { primary_activity: 'bmx', wheels: [{ bsd: 406, tire_width: 61, position: ['front', 'rear'] }] }
        const size = { geometry: { top_tube_effective: 540, head_angle: 75.25, seat_angle: 71, chainstay: 337, bb_height: 298 } }
        return cycleDrawing({ type: 'bike', data, size }).legend.find(({ key }) => key === 'bb_drop').value
      })
    JS
    expect(bb_drop).to eq(-34)
    # its effective top tube measured from where its seat tube, stopping short of the stack, meets its top tube, as a
    # BMX's does, and from the seat tube itself where it reaches the stack
    top_tube_guides = page.evaluate_script(<<~JS)
      import('bikebook/cycle_drawings').then(({ drawingViews }) => {
        const guides = (data, geometry) => drawingViews({ type: 'bike', data: { wheels: [{ bsd: 406, tire_width: 61, position: ['front', 'rear'] }], ...data }, size: { geometry } })
          .views[0].dims.find(({ key }) => key === 'top_tube_effective').guides?.length ?? 0
        return [guides({ primary_activity: 'bmx' }, { top_tube_effective: 540, head_angle: 75.25, seat_angle: 71, chainstay: 337, bb_height: 298 }),
          guides({}, { top_tube_effective: 560, stack: 570, reach: 390, head_angle: 72, seat_angle: 73.5, chainstay: 420, bb_drop: 70, seat_tube_ct: 620 })]
      })
    JS
    expect(top_tube_guides).to eq([1, 0])
    # its listed handlebar type's bar, a road bike's drop bar only where it lists none: flat bars drawn end on, each a dot
    flat_bars = page.evaluate_script(<<~JS)
      import('bikebook/cycle_drawings').then(({ drawingViews }) => {
        const size = { geometry: { stack: 600, reach: 390, head_angle: 70, seat_angle: 73, chainstay: 440, wheelbase: 1100, bb_drop: 70 } }
        const bars = (type, data) => drawingViews({ type, data: { wheels: [{ bsd: 622, tire_width: 40, position: ['front', 'rear'] }], ...data }, size })
          .views[0].shapes.filter(({ kind, radius, fill }) => kind === 'circle' && radius === 14 && fill).length
        return [bars('bike', { primary_activity: 'road_bike_touring' }), bars('bike', { primary_activity: 'road_bike_touring', handlebar_type: 'horizontal' }),
          bars('bike', { handlebar_type: 'drop_bar' }), bars('tandem', { handlebar_type: 'horizontal' }), bars('tandem', { handlebar_type: 'drop_bar' })]
      })
    JS
    expect(flat_bars).to eq([0, 1, 0, 2, 1])
    # a step-through frame drawn as one, but where its type detail is drawn its own way, as a bench seat is
    details = page.evaluate_script(<<~JS)
      import('bikebook/cycle_drawings').then(({ drawingViews }) => [{ frame: { top_tube: 'step_through' } }, { frame: { top_tube: 'sloping' } },
        { type_detail: 'bench_seat', frame: { top_tube: 'step_through' } }, { type_detail: 'step_through' }, { type: 'tandem', frame: { top_tube: 'step_through' } }]
        .map((data) => drawingViews({ type: data.type ?? 'bike', data, typeDetail: data.type_detail, size: { geometry: { reach: 390, stack: 600 } } }).detail ?? 'none'))
    JS
    expect(details).to eq(%w[step_through none bench_seat step_through step_through])
    # standover above the bottom bracket, short, with a tooltip saying what it's above
    standover = page.evaluate_script(<<~JS)
      (async () => {
        const catalog = (file) => fetch(`https://bikebook-catalog.bikeindex.org/catalog/${file}`).then((response) => response.json())
        const [{ VehiclePresenter }, { geometryCard }, { render }, { kit }, vocabulary] = await Promise.all([import('bikebook/vehicle_presenter'),
          import('bikebook/templates/vehicles/geometry_card'), import('lit-html'), catalog('kit.json'), catalog('vocabulary.json')])
        const container = document.createElement('div')
        render(geometryCard({ presenter: new VehiclePresenter(kit, vocabulary), size: { name: 'M', geometry: { standover_above_bb: 235 } }, others: [] }), container)
        const label = [...container.querySelectorAll('dt')].find((each) => each.textContent.includes('Standover'))
        return [label.querySelector('button').innerText, label.textContent.replace(/\\s+/g, ' ').trim(),
          [...label.nextElementSibling.children].map((each) => each.textContent.replace(/\\s+/g, ' ').trim())]
      })()
    JS
    # in centimeters, an imperial viewer's feet and inches after, as a wheelbase is, but no feet under a foot, spelled out
    # in their tooltip
    expect(standover).to match(["?", "Standover above BB ? Some bikes (typically BMX and dirt jumpers) list standover from the bottom bracket, instead of the ground",
      [/\A23\.5\W*cm\z/, /\A23\.5\W*cm \(9" 9\.3 inches\)\z/]])
    # a tandem's captain's figures under a bike's keys and its stoker's prefixed, and its front end as a bike's: its head
    # tube's bottom up its fork's length from the front axle, square to the steering axis by its rake, its fork's length
    # typical where it lists none. A step-through's riders' standovers over its step tubes, and its boom tube, where it
    # lists none, calculated from the stoker's top tube
    tandem = page.evaluate_script(<<~JS)
      Promise.all([import('bikebook/templates/vehicles/cycle_drawing'), import('bikebook/cycle_drawings')]).then(([{ cycleDrawing, sideView }, { drawingViews }]) => {
        const data = { type: 'tandem', wheels: [{ bsd: 559, tire_width: 50, position: ['front', 'rear'] }], frame: { top_tube: 'step_through' } }
        const geometry = { bb_drop: 46, chainstay: 495, fork_rake: 46, head_tube: 198, wheelbase: 1880, head_angle: 70, seat_angle: 66, seat_tube_ct: 406, standover: 508,
          top_tube_effective: 737, stem_length: 90, extra_measurements: { stoker_seat_tube_ct: 356, stoker_seat_angle_degrees: 66, stoker_standover: 445 } }
        const size = { geometry: { ...geometry, fork_length_a2c: 406 } }
        const listed = cycleDrawing({ type: 'tandem', data, size }).legend.filter(({ listed }) => listed).map(({ key, value }) => [key, value])
        const [view] = drawingViews({ type: 'tandem', data, size }).views
        const headBottom = view.dims.find(({ key }) => key === 'head_tube').b
        const boomed = { geometry: { ...size.geometry, extra_measurements: { ...geometry.extra_measurements, stoker_top_tube_effective: 696 } } }
        const boom = cycleDrawing({ type: 'tandem', data, size: boomed }).legend.find(({ key }) => key === 'boom_tube')
        return [listed, Math.round(headBottom[1]), sideView({ type: 'tandem', data, size }).typical, sideView({ type: 'tandem', data, size: { geometry } }).typical,
          [Math.round(boom.value), boom.calculated, sideView({ type: 'tandem', data, size: boomed }).typical],
          view.shapes.filter(({ seat, fill }) => fill && !seat).length]
      })
    JS
    expect(tandem.first).to include(["seat_tube_ct", 406], ["top_tube_effective", 737], ["stoker_seat_tube_ct", 356], ["seat_angle", 66],
      ["head_tube", 198], ["stem_length", 90], ["bb_drop", 46], ["fork_rake", 46], ["standover", 508], ["stoker_standover", 445])
    # 329.5 up to the front axle, less 46 × cos 70° across the rake, plus √(406² − 46²) × sin 70° up the fork
    # 696 + (406 − 356) × cos 66°
    # and the stoker's bar, clamped to the captain's seat post, left out of the overlay with it
    expect(tandem.drop(1)).to eq([693, ["boom_tube"], %w[boom_tube fork_length_a2c], [716, true, []], 1])
    # a longtail's overall length runs tire to tire, worked out from its wheelbase and wheels, and without them unlettered; a
    # size's own length is what the comparison lists, noted as specified. Its drawing names its size where it has others,
    # and letters only the typical figures it's drawn from, not its standover, trail or BB height measured off them. The
    # comparison opens with each one's type, target riders and type detail, where they differ. A BMX's typical figures are a BMX's
    longtail = page.evaluate_script(<<~JS)
      (async () => {
        const catalog = (file) => fetch(`https://bikebook-catalog.bikeindex.org/catalog/${file}`).then((response) => response.json())
        const [{ VehicleViewer }, { renderInto }, { cycleDrawing }, { kit }, vocabulary] = await Promise.all([import('bikebook/vehicle_viewer'),
          import('bikebook/render'), import('bikebook/templates/vehicles/cycle_drawing'), catalog('kit.json'), catalog('vocabulary.json')])
        const wheels = [{ bsd: 559, tire_width: 65, position: ['front', 'rear'] }]
        const geometry = { reach: 401, stack: 646, chainstay: 613, head_tube: 222, wheelbase: 1271, head_angle: 70, seat_angle: 73 }
        const length = (data, size) => {
          const found = cycleDrawing({ type: 'cargo_bike_rear', data, size, kit }).legend.find(({ key }) => key === 'dimensions.length')
          return found && [found.value, found.listed, found.calculated]
        }
        const data = { model: 'Curry', type: 'cargo_bike_rear', wheels, sizes: [{ name: 'One Size', geometry: { dimensions: { length: 2261 } } }] }
        const container = document.body.appendChild(document.createElement('div'))
        const render = (vehicle) => renderInto(container, new VehicleViewer(kit, vocabulary).render([{ value: 'm/x/2026/curry', data: vehicle }],
          new URL('/bikebook?view=geometry&vehicle_models=m/x/2026/curry', window.location.href), null))
        render(data)
        const alone = container.querySelector('tbody th').innerText
        const row = [...container.querySelectorAll('tbody tr')].find((each) => each.innerText.startsWith('Overall length'))
        const shown = [row.querySelector('td').innerText.replace(/\\s+/g, ' ').trim(), [...row.querySelector('td').querySelectorAll("[role='tooltip']")].at(-1).textContent.trim()]
        const caption = (sizes) => {
          render({ ...data, sizes })
          return container.querySelector('figcaption').textContent.split('.')[0]
        }
        const captions = [caption([{ name: 'One Size', geometry }]), caption([{ name: 'S', geometry }, { name: 'L', geometry }])]
        render({ model: 'Jumper', type: 'bike', primary_activity: 'bmx', wheels: [{ bsd: 406, tire_width: 61, position: ['front', 'rear'] }],
          sizes: [{ name: '21" TT', geometry: { bb_height: 292, chainstay: 335, fork_rake: 28, head_angle: 75, seat_angle: 71, stem_length: 48, top_tube_effective: 533 } }] })
        const bmx = container.querySelector('figcaption').textContent.split('. ').at(-1)
        renderInto(container, new VehicleViewer(kit, vocabulary).render([{ value: 'm/x/2026/curry', data }, { value: 'm/x/2026/step', data: { ...data, type: 'cargo_bike', type_detail: 'front_box', frame: { top_tube: 'step_through' }, target_riders: ['kid', 'woman'] } }],
          new URL('/bikebook?view=geometry&vehicle_models=m/x/2026/curry,m/x/2026/step', window.location.href), null))
        const type = [alone, container.querySelector('tbody tr').innerText.replace(/\\s+/g, ' ').trim()]
        renderInto(container, new VehicleViewer(kit, vocabulary).render([{ value: 'm/x/2026/curry', data }, { value: 'm/x/2026/step', data: { ...data, type: 'cargo_bike', primary_activity: 'cargo', target_riders: ['kid', 'woman'] } }],
          new URL('/bikebook?vehicle_models=m/x/2026/curry,m/x/2026/step', window.location.href), null))
        const overview = ['Vehicle type', 'Primary activity'].map((label) => [...container.querySelectorAll('tbody tr')].find((each) => each.innerText.startsWith(label)).innerText.replace(/\\s+/g, ' ').trim())
        container.remove()
        const typical = cycleDrawing({ type: 'cargo_bike_rear', data: { wheels }, size: { geometry }, kit }).legend
          .filter(({ listed, calculated }) => !listed && !calculated).map(({ key }) => key)
        return [length({ wheels }, { geometry }), length({}, { geometry }), length({ wheels }, data.sizes[0]), shown, [...captions, bmx], typical, type, overview]
      })()
    JS
    expect(longtail).to match([[1960, false, true], nil, [2261, true, false], [/\A226\.1\W*cm \?\z/, "This value is specified"],
      ["Light purple figures are calculated from the listed ones", "S drawn", "Gray figures aren't listed, so they're estimated from typical values on BMX bikes."], %w[stem_length bb_drop fork_rake],
      ["Front wheel", "Vehicle type Cargo Bike Rear Cargo Bike · Kids & Women's · Front box · Step-through"],
      ["Vehicle type Cargo Bike Rear Cargo Bike", "Primary activity — Kids & Women's Cargo"]])

    # the first vehicle's last pick is what a comparison with none picked starts nearest
    visit bikebook_path(vehicle_models: "m/aventon/2026/level_4_adv,m/aventon/2026/current_exp", view: "geometry")
    expect(page).to have_css("[aria-label='Sizes & geometry comparison']", wait: 10)
    expect_size.call("Level 4 ADV", "Extra Large")
    expect_size.call("Current EXP", "Extra Large")
    # 650b against 700c, whatever their tires
    expect(diameters.call).to eq(["Aventón Level 4 ADV's 650 B wheels with 56 mm tires are approximately 696 mm diameter",
      "Aventón Current EXP's 700 C wheels with 64 mm tires are approximately 750 mm diameter"])

    # a model picked again compares in a size of its own, which goes on the URL in its place
    visit bikebook_path(vehicle_models: "m/aventon/2026/current_adv", view: "geometry", search: 1)
    expect(page).to have_css("[aria-label='Sizes & geometry comparison']", wait: 10)
    type_into(vehicle_field, "current adv")
    retry_on_detach { find(vehicle_option, text: "Aventón Current ADV already selected").click }
    expect(page).to have_css(".hw-combobox__chip", text: "Aventón Current ADV", count: 2)
    all("select[aria-label='Size of Current ADV']", count: 2, wait: 10).last.select("Small")
    expect(page).to have_current_path(/[?&]vehicle_sizes=,Small(&|\z)/)
    expect(all("select[aria-label='Size of Current ADV'] option[selected]", count: 2).map(&:text)).to eq(["Extra Large", "Small"])
    expect(all("[aria-label='Geometry overlay'] li").map(&:text)).to eq(["Aventón Current ADV Extra Large", "Aventón Current ADV Small"])
  end

  it "shows every weight in pounds to a viewer who prefers imperial units" do
    serve_bikebook_catalog
    sign_in(FactoryBot.create(:user_confirmed, preferred_unit_system: "imperial"))
    visit bikebook_path(vehicle_models: "m/aventon/2026/current_adv,m/aventon/2026/level_4_adv", view: "geometry")
    expect(page).to have_css("[aria-label='Sizes & geometry comparison']", wait: 10)

    # the comparison's weight and difference, and each size's weight and payload
    expect(find("[aria-label='Sizes & geometry comparison'] tr", text: "Weight")).to have_text(/56\W*lb.*61\.1\W*lb\W*\+5\.1\W*lb/m)
    expect(page).to have_css("dd", text: /\A[\d.,]+\W*lb\z/, minimum: 2)
    expect(page).to have_no_text(/\d\W*kg\b/)
    # 650 B wheels smaller than the first's 700 C, and a tire's difference in mm all the same
    front_wheels = find("[aria-label='Sizes & geometry comparison'] tr", text: "Front wheel")
    expect(front_wheels).to have_css("td > span > span", text: /\A650 B,\s*− \?\z/)
      .and have_css(".tw\\:text-red-700.tw\\:font-bold", exact_text: "−")
      .and have_css("button[aria-label='650 B wheels are smaller diameter than 700 C']")
      .and have_css(".tw\\:text-gray-500", text: /\A−8\W*mm\z/)
    # wheelbase in centimeters, with feet and inches after, which its difference leaves off
    expect(find("[aria-label='Sizes & geometry comparison'] tr", text: "Wheelbase").all("td").map(&:text)).to all(match(/\A[\d.]+\W*cm\s*\(\d'\s*\d+"\)(\s*[−+][\d.]+\W*cm|\s*-)?\z/))
    # whose feet and inches are themselves the tooltip's trigger, which spells them out
    wheelbase = find("[aria-label='Sizes & geometry comparison'] tr", text: "Wheelbase").first("td")
    expect(wheelbase).to have_no_button("?")
    wheelbase.find("button", text: /\A\d'\s*\d+"\z/).click
    expect(wheelbase).to have_css("[role='tooltip']", text: /\A\d+ feet, [\d.]+ inch(es)?\z/, visible: true)
    # feet and inches marks aren't muted as other units are
    expect(wheelbase.find("button", text: /\A\d'\s*\d+"\z/)).to have_no_css(".tw\\:text-gray-400")
    # a dimension's tooltip spells out its feet and inches, its metric after
    dimension = page.evaluate_script(<<~JS)
      (async () => {
        const catalog = (file) => fetch(`https://bikebook-catalog.bikeindex.org/catalog/${file}`).then((response) => response.json())
        const [{ VehiclePresenter }, { fragmentOf }, { kit }, vocabulary] = await Promise.all([import('bikebook/vehicle_presenter'),
          import('bikebook/render'), catalog('kit.json'), catalog('vocabulary.json')])
        const imperial = fragmentOf(new VehiclePresenter(kit, vocabulary).dimensions({ length: 762 })).querySelector('.tw\\\\:imperial\\\\:inline [role="tooltip"]')
        return imperial.textContent.replace(/\\s+/g, ' ').trim()
      })()
    JS
    expect(dimension).to eq "Length: 2 feet, 6 inches (76.2 cm)"
  end

  it "renders each UI template as the component it mirrors does" do
    serve_bikebook_catalog
    visit bikebook_path

    aggregate_failures do
      expect_template(UI::Tooltip::Component.new(text: "622 mm BSD"), "bikebook/templates/ui/tooltip#tooltip", "{ text: '622 mm BSD' }")
      expect_template(UI::Tooltip::Component.new(text: "#ff0000").with_content("<span>red</span>".html_safe),
        "bikebook/templates/ui/tooltip#tooltip", "{ text: '#ff0000', content: html`<span>red</span>` }")
      expect_template(UI::Tooltip::Component.new.with_body_content("<em>Internal</em> routing".html_safe),
        "bikebook/templates/ui/tooltip#tooltip", "{ body: html`<em>Internal</em> routing` }")

      expect_template(UI::Badge::Component.new(text: "Bike"), "bikebook/templates/ui/badge#badge", "{ text: 'Bike' }")
      expect_template(UI::Card::Component.new(full_bleed: true, additional_classes: "tw:mt-3").with_content("Weightings"),
        "bikebook/templates/ui/card#card", "{ content: 'Weightings', fullBleed: true, additionalClasses: 'tw:mt-3' }")

      expect_template(UI::Forms::Checkbox::Component.new(name: "same_manufacturer", label: "Include", checked: true, class_name: "tw:mb-0",
        html_options: {id: "similar-same_manufacturer", data: {action: "x"}}), "bikebook/templates/ui/forms/checkbox#checkbox",
        "{ name: 'same_manufacturer', label: 'Include', checked: true, className: 'tw:mb-0', attributes: { id: 'similar-same_manufacturer', 'data-action': 'x' } }")
      expect_template(UI::Forms::Checkbox::Component.new(name: "same_manufacturer", label: "Include"), "bikebook/templates/ui/forms/checkbox#checkbox",
        "{ name: 'same_manufacturer', label: 'Include' }")

      expect_template(UI::Forms::RadioButtonGroup::Component.new(name: "strategy", kind: :toggle, selected: "general",
        entries: [{value: "general", label: "General"}, {value: "custom", label: "Custom", disabled: true}], html_options: {data: {action: "x#y"}}),
        "bikebook/templates/ui/forms/radio_button_group#radioButtonGroup", <<~JS)
          { name: 'strategy', selected: 'general', entries: [{ value: 'general', label: 'General' }, { value: 'custom', label: 'Custom', disabled: true }],
            attributes: { 'data-action': 'x#y' } }
        JS

      expect_template(UI::Forms::Range::Component.new(name: "geometry", label: "Geometry", value: 4, max: 5), "bikebook/templates/ui/forms/range#range",
        "{ name: 'geometry', label: 'Geometry', value: 4, max: 5 }")
      expect_template(UI::Forms::Range::Component.new(name: "year", label: "Year", value: 2, max: 5, min_label: "Ignore year", max_label: "Only same year"),
        "bikebook/templates/ui/forms/range#range", "{ name: 'year', label: 'Year', value: 2, max: 5, minLabel: 'Ignore year', maxLabel: 'Only same year' }")
      expect_template(UI::Forms::Range::Component.new(name: "geometry", label: "Geometry", value: 1.5, min: 1, max: 2, step: 0.5,
        html_options: {id: "similar-geometry", data: {action: "input->x#y", "x-target": "weight"}}), "bikebook/templates/ui/forms/range#range",
        "{ name: 'geometry', label: 'Geometry', value: 1.5, min: 1, max: 2, step: 0.5, attributes: { id: 'similar-geometry', 'data-action': 'input->x#y', 'data-x-target': 'weight' } }")
      expect_template(UI::Badge::Component.new(text: "⚡", title: "E-vehicle", color: :purple), "bikebook/templates/ui/badge#badge",
        "{ text: '⚡', title: 'E-vehicle', color: 'purple' }")

      expect_template(UI::IconChevron::Component.new(size: :md), "bikebook/templates/ui/icon_chevron#iconChevron", "{ size: 'md' }")
      expect_template(UI::IconChevron::Component.new, "bikebook/templates/ui/icon_chevron#iconChevron", "undefined")

      expect_template(UI::DragHandle::Component.new(controller: "bikebook--chip-reorder", html_class: "tw:mr-1"),
        "bikebook/templates/ui/drag_handle#dragHandle", "{ controller: 'bikebook--chip-reorder', htmlClass: 'tw:mr-1' }")

      expect_template(UI::Tabs::Component.new(nav_label: "Views", turbo: true, margin_classes: "tw:mt-2", tabs: [
        ComponentStructs::Shapes.tab("Overview", "/bikebook", active: true), ComponentStructs::Shapes.tab("All", "/bikebook?view=all", count: 1200)
      ]), "bikebook/templates/ui/tabs#tabs", <<~JS)
        { navLabel: 'Views', turbo: true, marginClasses: 'tw:mt-2',
          tabs: [{ label: 'Overview', href: '/bikebook', active: true }, { label: 'All', href: '/bikebook?view=all', count: 1200 }] }
      JS

      expect_template(UI::CopyButton::Component.new(value: "m/trek/2025/fetch", label: "Copy ID"),
        "bikebook/templates/ui/copy_button#copyButton", "{ value: 'm/trek/2025/fetch', label: 'Copy ID' }")
      expect_template(UI::CopyButton::Component.new(value: "m/trek/2025/fetch", label: "Copy ID", tooltip: true),
        "bikebook/templates/ui/copy_button#copyButton", "{ value: 'm/trek/2025/fetch', label: 'Copy ID', tooltip: true }")

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
      expect_template(UI::Collapse::Component.new(text: "Read more", color: :link, chevron: :trailing, html_class: "tw:mt-1 tw:text-sm"),
        "bikebook/templates/ui/collapse#collapse", "{ content: 'Read more', color: 'link', chevron: 'trailing', htmlClass: 'tw:mt-1 tw:text-sm' }")

      # the overlay's frames and the comparison columns keyed to them, in the charts' colors
      series = page.evaluate_script("import('bikebook/templates/vehicles/geometry_overlay').then(({ SERIES }) => SERIES)")
      expect(series.map { it["color"] }).to eq(UI::Chart::Component::COLORS)
      expect(series).to all(satisfy { |each| [each["variable"], each["top"]] == ["tw:[--series:#{each["color"]}]", "tw:border-t-[#{each["color"]}]!"] })

      expect_template(Atoms::CopyableCode::Component.new(value: "m/trek/2025/fetch", label: "Copy ID"),
        "bikebook/templates/atoms/copyable_code#copyableCode", "{ value: 'm/trek/2025/fetch', label: 'Copy ID' }")

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
      expect_template(UI::DefinitionList::Container::Component.new(term: :below).with_content("<div>row</div>".html_safe),
        "bikebook/templates/ui/definition_list/container#definitionListContainer", "{ term: 'below', content: html`<div>row</div>` }")
      expect_template(UI::DefinitionList::Row::Component.new(label: "Motor", render_with_no_value: true, no_value_text: "Not provided"),
        "bikebook/templates/ui/definition_list/row#definitionListRow", "{ label: 'Motor', noValueText: 'Not provided' }")

      # a cycle of any kind's an e-bike classification, another e-vehicle's its own
      %w[cargo_bike e_scooter].each do |vehicle_type|
        expect_template(Pages::EbikeRules::BikeSummary::Component.new(vehicle_type:, specs: [["Motor", "700 W"], ["Top speed", nil], ["Throttle", "Optional"]],
          ul2849: :certified, ul2271: :unknown, others: "EN 15194").tap { it.with_tiles { "<span>tiles</span>".html_safe } }, "bikebook/templates/vehicles/bike_summary#bikeSummary", <<~JS)
            { vehicleType: '#{vehicle_type}', tiles: html`<span>tiles</span>`, specs: [['Motor', '700 W'], ['Top speed', null], ['Throttle', 'Optional']],
              ul2849: 'certified', ul2271: 'unknown', others: 'EN 15194' }
          JS
      end
      # the certifications it carries alone, else the one saying neither is known
      [%w[unknown certified], %w[unknown unknown]].each do |ul2849, ul2271|
        expect_template(Pages::EbikeRules::BikeSummary::Component.new(vehicle_type: "bike", specs: [["Motor", "250 W"]], ul2849: ul2849.to_sym, ul2271: ul2271.to_sym),
          "bikebook/templates/vehicles/bike_summary#bikeSummary", "{ vehicleType: 'bike', specs: [['Motor', '250 W']], ul2849: '#{ul2849}', ul2271: '#{ul2271}' }")
      end

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
    serve_bikebook_catalog
    visit bikebook_path(vehicle_models: "m/segway/2025/gt3_pro", view: "all")

    motor = find("section", text: /front and rear motor/i, wait: 10)
    expect(motor).to have_css("div", text: /Drive wheel\s*Front, Rear/)
    expect(motor.ancestor("article")).to have_css("div", text: /\AElectric Certification\W*Certification unknown\z/)
    expect(page).to have_no_css("h2", text: /\A(Front|Rear) motor\z/i)
    expect(page).to have_css("section div", text: /\AFolding\s*Stem fold\z/)
    expect(page).to have_css("[role='button']", text: "Compare similar e-scooters to GT3 Pro")
    click_link "Overview"
    # with nothing to lay it over, no overlay
    expect(page).to have_no_css("[aria-label='Geometry overlay']")

    # beside a vehicle that has none, a mode's classification
    visit bikebook_path(vehicle_models: "m/sur_ron/2026/ultra_bee_hp_x_us,m/segway/2025/gt3_pro", view: "all")
    classification = find("section div", text: /\AE-vehicle class\s*Off-Highway Motorcycle \?\z/, wait: 10)
    expect(classification).to have_xpath("ancestor::section[.//dt[text()='Propulsion']]")
    expect(page).to have_no_css("dt", exact_text: "Classifications")
    expect(page).to have_css("div", text: /\AMin rider age\s*18\W*yr\z/, visible: :all)
    # each suspended end, including one that states nothing
    suspension = ->(title) { find("article h1", text: title).ancestor("article").find("h2", text: /\Asuspension\z/i).ancestor("section") }
    expect(suspension.call("Ultra Bee")).to have_css("div", text: /\AFront\s*241\W*mm\z/).and have_css("div", text: /\ARear\s*320\W*×\W*85\W*mm 3\.35in\z/)
    expect(suspension.call("GT3 Pro")).to have_css("div", text: /\AFront\s*Front: Double Wishbone Hydraulic Shock Absorber/)
    classification.find("button", text: "?").click
    tooltip = classification.find("[role='tooltip']", text: "An electric motorcycle built for off-highway use", visible: true)
    expect(tooltip).to have_css("code", exact_text: "evc/off_highway_motorcycle")
      .and have_button("Copy ID").and have_no_link

    # a classification's exact id is an option, whose pick shows its /ebike-rules card above the vehicles, a US class's
    # its state jurisdiction's own with its rules
    type_into(vehicle_field, "evc/us/class_3")
    retry_on_detach { find("[role='option'][data-value='evc/us/class_3']", text: "US Class 3").click }
    expect(page).to have_css("#classification-cards h3", exact_text: "Class 3")
    expect(page).to have_css(".hw-combobox__chip", text: "US Class 3")
    expect(page).to have_current_path(%r{[?&]classifications=evc/us/class_3\b}).and have_current_path(%r{vehicle_models=m/sur_ron/2026/ultra_bee_hp_x_us,m/segway/2025/gt3_pro&})
    cards_asked = []
    page.driver.with_playwright_page { it.on("request", ->(request) { cards_asked << request.url if request.url.include?(ebike_rules_path) }) }
    # a model with classifications isn't alone, so its search, which holds their chips, shows
    visit bikebook_path(vehicle_models: "m/sur_ron/2026/ultra_bee_hp_x_us", classifications: "evc/us/class_3,evc/off_highway_motorcycle", jurisdiction: "CA")
    expect(page).to have_css("#classification-cards [role=button]", text: "California specifics", wait: 10)
    expect(page).to have_css(".hw-combobox__chip", text: "Off-Highway Motorcycle")
    expect(page).to have_css("#classification-cards h3", exact_text: "Off-Highway Motorcycle")
    find("#classification-cards [role=button]", text: "California specifics").click
    expect(page).to have_css("#classification-cards li", text: "Riders must be 16 or older to ride a Class 3")
    # a view's tab keeps them as they were, open and unrequested, and the field's chips without a bare frame between
    page.evaluate_script(<<~JS)
      (() => {
        window.fewestChips = Infinity
        new MutationObserver(() => { window.fewestChips = Math.min(window.fewestChips, document.querySelectorAll('[data-hw-combobox-chip]').length) })
          .observe(document.body, { childList: true, subtree: true })
      })()
    JS
    click_link "Sizes & geometry"
    expect(page).to have_current_path(/[?&]view=geometry\b/)
    expect(page).to have_css("#classification-cards li", text: "Riders must be 16 or older to ride a Class 3")
      .and have_css("#classification-cards h3", exact_text: "Off-Highway Motorcycle")
    expect(cards_asked.count).to eq 2
    expect(page.evaluate_script("window.fewestChips")).to eq 3
    # another's pick leaves the open one as it is, unrequested
    type_into(vehicle_field, "evc/moped")
    retry_on_detach { find("[role='option'][data-value='evc/moped']").click }
    expect(page).to have_css("#classification-cards h3", exact_text: "Moped, up to 2 hp and 30 mph", wait: 10)
    expect(page).to have_css("#classification-cards li", text: "Riders must be 16 or older to ride a Class 3")
    expect(cards_asked.count).to eq 3
    # as is an out of class marker, which the vocabulary has no record of, its card the e-moto's
    type_into(vehicle_field, "evc/out_of_class/us/ca")
    retry_on_detach { find("[role='option'][data-value='evc/out_of_class/us/ca']", text: "Out of class in California").click }
    expect(page).to have_css("#classification-cards h3", exact_text: "Not an e-bike", wait: 10)
    expect(page).to have_css(".hw-combobox__chip", text: "Out of class in California")

    # a class that only comes with an optional mode goes on its own line, after the mode
    visit bikebook_path(vehicle_models: "m/specialized/2025/haul_st")
    # its long description cut to its first 200 characters at a word, until it's opened
    description = find("[aria-label='Overview'] td", text: /\AWhatever you’re into/, wait: 10)
    excerpt = description.find("p", text: /…\z/).text
    expect(excerpt.length).to be <= 201
    expect(excerpt).to end_with("dawn patrol…").or match(/\w…\z/)
    expect(description).to have_no_text("MIK-compatible rear rack")
    description.click_on "Read more"
    expect(description).to have_css("[role='button'][aria-expanded='true']", exact_text: "Show less")
      .and have_css("[role='button'] [data-ui--collapse-target='chevron'].tw\\:rotate-90")
    expect(description).to have_text("MIK-compatible rear rack").and have_no_css("p", text: /…\z/)
    # a cargo bike's max load and cargo area, on the Overview under its total length and above the size in its geometry
    expect(page).to have_css("[aria-label='Overview'] tr", text: /\ACargo\s*Total length 167\.3\W*cm \?\s*Max load 190\W*kg \?\z/)
    find("[aria-label='Overview'] button[aria-label='Max load (rider + cargo)']").click
    # its rider limit the same, which leaves it out, and its cargo's
    expect(page).to have_css("[role='tooltip']", text: /\AMax load \(rider \+ cargo\)\s*Max cargo weight 60\W*kg\z/, visible: true)
    click_link "Sizes & geometry"
    expect(page).to have_css("[aria-label='Sizes & geometry comparison'] tr", text: /\ACargo\s*Max load 190\W*kg \?\z/)
    expect(all("[aria-label='Sizes & geometry comparison'] tbody th").map(&:text).each_cons(2)).to include(%w[Cargo Size])
    # without a max load, its gross weight rating, and without either its rider limit; a rider limit apart from either,
    # and a gross rating beside a max load, in its tooltip: its sizes' range, or the compared size's. Its Frame lists both
    payloads = page.evaluate_script(<<~JS)
      (async () => {
        const catalog = (file) => fetch(`https://bikebook-catalog.bikeindex.org/catalog/${file}`).then((response) => response.json())
        const [{ VehicleViewer }, { renderInto }, { kit }, vocabulary] = await Promise.all([import('bikebook/vehicle_viewer'),
          import('bikebook/render'), catalog('kit.json'), catalog('vocabulary.json')])
        const data = { model: 'Hauler', type: 'cargo_bike', sizes: [{ name: 'S', geometry: { max_weight_rider: 150 } }, { name: 'L', geometry: { max_weight_rider: 180 } }] }
        const viewer = new VehicleViewer(kit, vocabulary)
        const container = document.body.appendChild(document.createElement('div'))
        const text = (element) => element.innerText.replace(/\\s+/g, ' ').trim()
        const cargo = (view, vehicle) => {
          renderInto(container, viewer.render([{ value: 'm/x/2026/hauler', data: vehicle }], new URL(`/bikebook?view=${view}&vehicle_models=m/x/2026/hauler&vehicle_sizes=L`, window.location.href), null))
          return [...container.querySelectorAll('tbody tr')].find((row) => row.innerText.startsWith('Cargo'))
        }
        const frame = (vehicle) => {
          renderInto(container, viewer.render([{ value: 'm/x/2026/hauler', data: vehicle }], new URL('/bikebook?view=all&vehicle_models=m/x/2026/hauler', window.location.href), null))
          return [...[...container.querySelectorAll('section')].find((section) => /^frame$/i.test(section.querySelector('h2')?.innerText)).querySelectorAll('dl > div')].map(text)
        }
        const tooltip = (row) => {
          const shown = row.querySelector("[role='tooltip']")
          shown.classList.remove('tw:hidden')
          return text(shown)
        }
        const weighed = { ...data, frame: { max_weight_total: 200 } }
        const rated = { ...data, frame: { max_weight_total: 160, gross_weight_rating: 200 } }
        const shown = [text(cargo('basics', data)), text(cargo('geometry', data)), tooltip(cargo('basics', weighed)), tooltip(cargo('geometry', weighed)),
          tooltip(cargo('basics', rated)), ...((row) => [text(row), tooltip(row)])(cargo('basics', { ...data, frame: { gross_weight_rating: 200 } })),
          text(cargo('basics', { ...data, cargo: { max_weight_cargo: 80 } })),
          ...((row) => [text(row), tooltip(row)])(cargo('basics', { model: 'Long', type: 'cargo_bike', cargo: { length: 787 }, sizes: [{ name: 'L', geometry: { wheelbase: 1356 } }],
            wheels: [{ bsd: 406, tire_width: 89, position: ['front'] }, { bsd: 406, tire_width: 89, position: ['rear'] }] })), ...frame(rated)]
        container.remove()
        return shown
      })()
    JS
    expect(payloads).to match([/\ACargo Max rider weight 150\W*kg–180\W*kg\z/, /\ACargo Max rider weight 180\W*kg\z/,
      /\AMax load \(rider \+ cargo\) Max rider weight 150\W*kg–180\W*kg\z/, /\AMax load \(rider \+ cargo\) Max rider weight 180\W*kg\z/,
      /\AMax load \(rider \+ cargo\) Gross weight rating \(bike \+ rider \+ cargo\) 200\W*kg Max rider weight 150\W*kg–180\W*kg\z/,
      /\ACargo Gross weight rating 200\W*kg \?\z/, /\AGross weight rating \(bike \+ rider \+ cargo\) Max rider weight 150\W*kg–180\W*kg\z/,
      # a cargo limit alone, with no limit's tooltip to go in, isn't shown
      /\ACargo Max rider weight 150\W*kg–180\W*kg\z/,
      # its wheelbase and wheels' total length beside its cargo area's, each spelled out in their tooltip
      /\ACargo Total length 194\W*cm, Cargo 78\.7\W*cm \?\z/,
      /\ATotal length: 194\W*cm \(6 feet, 4\.4 inches\) \(total length is the wheelbase plus each wheel’s radius, calculating the tire height from its width\) Cargo length: 78\.7\W*cm \(2 feet, 7 inches\)\z/,
      /\AMax load \(rider \+ cargo\) 160\W*kg\z/, /\AGross weight rating \(bike \+ rider \+ cargo\) 200\W*kg\z/])
    click_link "All"
    expect(page).to have_css("section div", text: /\AE-vehicle class\s*US Class 3 \?\s*w\/ optional throttle US Class 2 \?\z/, wait: 10)
    expect(page).to have_css("dd > span.tw\\:block", text: /\Aw\/ optional throttle US Class 2/)
    # years keyed by year, read newest first, each with its colorways, and the max load with the frame
    years = find("article h1", text: "Haul ST").ancestor("article").find("h2", text: /\Amodel years\z/i).ancestor("section")
    expect(years.all("tr").map { it.first("td").text }).to eq %w[2026 2025]
    expect(years).to have_text("Satin Obsidian").and have_text("Gloss White Mountains")
    expect(find("h2", text: /\Aframe\z/i).ancestor("section")).to have_text(/Max load \(rider \+ cargo\)\W*190\W*kg/)

    # beside its Canadian model, sold outside the visitor's market, the Overview leads with each one's, and names it after
    # whichever of them the market picked doesn't sell
    visit bikebook_path(vehicle_models: "m/specialized/2025/haul_st,m/specialized/2025/haul_st_ca", filters: 1)
    expect(page).to have_css("[aria-label='Overview comparison'] tbody tr:first-child", text: /\AMarkets\s*United States\s*Canada\z/, wait: 10)
    expect(page).to have_css("[aria-label='Overview comparison'] thead th", text: /Haul ST\s+\(Canada\)/)
      .and have_no_css("[aria-label='Overview comparison'] thead th", text: "(United States)")
    choose_option("Market", "Canada")
    expect(page).to have_css("[aria-label='Overview comparison'] thead th", text: /Haul ST\s+\(United States\)/)
      .and have_no_css("[aria-label='Overview comparison'] thead th", text: "(Canada)")

    # its Canadian model, published resolved from it: its own market, price and motor, and no US class
    visit bikebook_path(vehicle_models: "m/specialized/2025/haul_st,m/specialized/2025/haul_st_ca", view: "all")
    expect(page).to have_css("[data-comparison] article", count: 2, wait: 10)
    canadian = all("article").last
    expect(canadian).to have_css("div", text: /\AMarkets\s*Canada\z/).and have_css("span[title='Canadian Dollar']")
      .and have_css("div", text: /\ARated power\s*500\W*W\z/).and have_no_text("US Class")
    expect(canadian.find("h2", text: /\Amodel years\z/i).ancestor("section").all("tr").map { it.first("td").text }).to eq %w[2025]

    # a classification's card alone keeps the search, its chip in it, and the models to compare, without the page's tips
    visit bikebook_path(classifications: "evc/us/class_3")
    expect(page).to have_css("#classification-cards h3", exact_text: "Class 3", wait: 10)
    expect(page).to have_css(".hw-combobox__chip", text: "US Class 3").and have_css("[aria-label='Models to compare'] a", minimum: 1)
      .and have_text(/models to compare\. Search them/).and have_no_css("[aria-label='How to use BikeBook']").and have_no_text("Nothing selected yet")
    expect(page).to have_current_path("/bikebook?classifications=evc/us/class_3&search=1")
  end

  it "puts the first model's most alike above its views, by a strategy or adjusted weights, each added to the comparison and taken out" do
    serve_bikebook_catalog
    compared = -> { all("[aria-label='Overview comparison'] thead [data-ui--copy-button-text-value]", visible: :all).map { it["data-ui--copy-button-text-value"] } }
    cards = -> { all("[aria-label='Similar models to compare'] a").map { it[:id] } }
    visit bikebook_path(vehicle_models: "m/aventon/2026/level_4_rec,m/aventon/2022/level_2")
    # opened from the search's More filters line, its section above the views collapsed until then
    compare = find_button("Compare similar bikes to Level 4 REC", wait: 10)
    expect(compare).to have_xpath("../following-sibling::*[@aria-controls='vehicle-filters']")
    # beneath the line once it's carded around applied filters
    visit bikebook_path(vehicle_models: "m/aventon/2026/level_4_rec,m/aventon/2022/level_2", manufacturer: "aventon")
    expect(find_button("Compare similar bikes to Level 4 REC", wait: 10)).to have_no_xpath("ancestor::*[ul[@aria-label='Applied filters']]")
    visit bikebook_path(vehicle_models: "m/aventon/2026/level_4_rec,m/aventon/2022/level_2")
    compare = find_button("Compare similar bikes to Level 4 REC", wait: 10)
    expect(page).to have_css("[aria-label='Similar models'] + #vehicle-views")
    expect(page).to have_no_css("[aria-label='Similar models to compare']").and have_no_css("[aria-label='Geometry overlay']")
      .and have_no_css("#similar-toggle")
    compare.click
    # its own toggle taking over, on a line of its own
    expect(page).to have_css("#similar-toggle:focus", exact_text: "Hide similar bikes")
    expect(page).to have_no_css("button", text: "Compare similar bikes to Level 4 REC")
    # and the comparison's frames overlaid beneath its overview, each column's foot in its frame's color
    expect(page).to have_css("[aria-label='Overview comparison'] + div > [aria-label='Geometry overlay']")
    feet = -> { page.evaluate_script("[...document.querySelectorAll(\"[aria-label='Overview comparison'] tbody tr:last-child td\")].map((cell) => getComputedStyle(cell).borderBottomColor)") }
    expect(feet.call).to eq ["rgb(52, 152, 219)", "rgb(220, 38, 38)"]
    # left of the table once the window is wide, as Sizes & geometry's is
    size = page.current_window.size
    page.current_window.resize_to(1600, 1000)
    sides = -> { page.evaluate_script("['Geometry overlay', 'Overview comparison'].map((label) => document.querySelector(`[aria-label='${label}']`).getBoundingClientRect()).map(({ left, right }) => [left, right])") }
    expect(sides.call.then { |(overlay, overview)| overlay.last < overview.first }).to be true
    page.current_window.resize_to(*size)
    expect(page).to have_current_path(/[?&]similar=1\b/)
    # its maker's others in, unless they're skipped
    expect(page).to have_css("#similar-m-aventon-2026-pace_5_rec_step_through", wait: 10)
    find("[role='button']", text: "Adjust comparison algorithm").click
    # its toggle moved into the card it opens, a slider for each group, those the model lists nothing of disabled
    expect(page).to have_field("Frame material", with: "2")
    # a bare track, showing no weight, though the default is 2
    groupset = find_field("Groupset", disabled: true).ancestor("[data-controller='ui--forms--range']")
    expect(groupset).to have_text("Not listed for this bike").and have_css("output", visible: :hidden)
    expect(page.evaluate_script("getComputedStyle(document.querySelector('#similar-groupset'), '::-webkit-slider-thumb').appearance")).to eq "none"
    # level with a listed one's
    boxes = page.evaluate_script(<<~JS)
      ['#similar-groupset', '#similar-geometry'].map((id) => {
        const input = document.querySelector(id)
        const [box, wrapper] = [input, input.closest("[data-controller='ui--forms--range']")].map((each) => each.getBoundingClientRect())
        return [box.top - wrapper.top, box.height]
      })
    JS
    expect(boxes.uniq.count).to eq 1
    expect(page).to have_css("div:has(> div > fieldset) > div > [role='button']:focus", text: "Adjust comparison algorithm")
    # out to the page's gutter on a phone, as More filters' card is
    size = page.current_window.size
    page.current_window.resize_to(390, 844)
    adjust_card = "getComputedStyle(document.querySelector(\"[aria-label='Similar models'] div:has(> div > fieldset)\"))"
    expect(page.evaluate_script("[#{adjust_card}.borderLeftWidth, #{adjust_card}.paddingLeft]")).to eq %w[0px 0px]
    page.current_window.resize_to(*size)
    # every e-bike in the fixture is an Aventón
    check "Skip bikes from the same manufacturer"
    expect(page).to have_current_path(/[?&]skip_manufacturer=1\b/).and have_text("No similar models are in the catalog.")
    uncheck "Skip bikes from the same manufacturer"
    expect(page).to have_no_current_path(/skip_manufacturer/).and have_css("#similar-m-aventon-2026-pace_5_rec_step_through")
    # and the other propulsion's, an e-bike's human powered ones, and other vehicle types
    expect(page).to have_css("legend", exact_text: "Other settings")
    {"Show matching human powered bikes" => "other_propulsion", "Only complete bikes" => "same_configuration",
     "Only match bikes with the same wheel size" => "same_wheels"}.each do |label, param|
      check label
      expect(page).to have_current_path(/[?&]#{param}=1\b/)
      uncheck label
      expect(page).to have_no_current_path(/#{param}/)
    end
    check "Include different vehicle types"
    expect(page).to have_current_path(/[?&]different_types=1\b/).and have_css("#similar-m-aventon-2025-abound_lr")
    uncheck "Include different vehicle types"
    expect(page).to have_no_current_path(/different_types/).and have_no_css("#similar-m-aventon-2025-abound_lr")
    # the closest of each model group, its own, other propulsions and other vehicle types left out, other activities in
    expect(cards.call).to eq %w[similar-m-aventon-2026-pace_5_rec_step_through similar-m-aventon-2025-aventure_3_step_through
      similar-m-aventon-2024-soltera_2_5 similar-m-aventon-2026-ramblas_adv similar-m-aventon-2024-sinch_2_5]
    expect(page).to have_checked_field("Default weights", visible: :all).and have_field("Custom", disabled: true, visible: :all)
    # Custom says it's chosen by a slider, on hovering it though it's disabled
    find("button[aria-describedby]", exact_text: "Custom").hover
    expect(page).to have_css("[role='tooltip']", text: "If you change a weight, this will be selected")
    # its toggle with nothing beneath it but the card's own spacing
    toggle_gap = "(() => { const toggle = document.querySelector(\"[aria-label='Similar models'] [data-ui--collapse-param-value='adjust'] .tw\\\\:text-right\"); " \
      "return toggle.nextElementSibling.getBoundingClientRect().top - toggle.getBoundingClientRect().bottom })()"
    expect(page.evaluate_script(toggle_gap)).to eq 0

    # a card adds its model to the comparison, in place and focused again, and takes it out
    click_link "Soltera 2.5"
    expect(page).to have_css("[aria-label='Overview comparison'] thead th", count: 4, wait: 10)
    expect(page).to have_css("#similar-m-aventon-2024-soltera_2_5:focus")
    expect(compared.call).to eq %w[m/aventon/2026/level_4_rec m/aventon/2022/level_2 m/aventon/2024/soltera_2_5]
    expect(find("#similar-m-aventon-2024-soltera_2_5").ancestor("li")).to have_text("Comparing")
    expect(page).to have_text("Hide similar bikes").and have_unchecked_field("Skip bikes from the same manufacturer")
    click_link "Soltera 2.5"
    expect(page).to have_css("[aria-label='Overview comparison'] thead th", count: 3, wait: 10)
    expect(find("#similar-m-aventon-2024-soltera_2_5").ancestor("li")).to have_no_text("Comparing")

    # a slider moved off the default weights chooses Custom, rescoring the cards
    find_field("E-vehicle motor and battery").send_keys(:home)
    find_field("Tire clearance").send_keys(:home)
    expect(page).to have_css("output[for='similar-tires']", exact_text: "0")
    expect(page).to have_checked_field("Custom", visible: :all).and have_no_checked_field("Default weights", visible: :all)
    expect(page).to have_css("#similar-m-aventon-2026-soltera_3_adv").and have_no_css("#similar-m-aventon-2024-soltera_2_5")
    expect(page).to have_current_path(/[?&]weights=tires\.0,ebike\.0(&|\z)/)

    # kept in the URL, open
    refresh
    expect(page).to have_field("Tire clearance", with: "0", wait: 10)
    expect(page).to have_checked_field("Custom", visible: :all).and have_unchecked_field("Skip bikes from the same manufacturer")
    expect(page).to have_css("#similar-m-aventon-2026-soltera_3_adv").and have_no_css("#similar-m-aventon-2024-soltera_2_5")
    # and Default weights puts them back
    choose "Default weights", allow_label_click: true
    expect(page).to have_field("Tire clearance", with: "4").and have_field("E-vehicle motor and battery", with: "3")
    expect(page).to have_field("Custom", disabled: true, visible: :all)
    expect(page).to have_css("#similar-m-aventon-2024-soltera_2_5").and have_no_css("#similar-m-aventon-2026-soltera_3_adv")
    expect(page).to have_no_current_path(/weights=/)

    # once ten are compared, only theirs link
    nine = %w[2026/level_4_rec 2022/level_2 2026/current_adv 2026/current_exp 2025/level_3 2025/aventure_m 2024/abound_sr
      2026/level_4_adv 2025/pace_4_step_through].map { "m/aventon/#{it}" }
    visit bikebook_path(vehicle_models: nine.join(","), similar: 1)
    click_link "Soltera 2.5", wait: 10
    expect(page).to have_css("[aria-label='Overview comparison'] thead th", count: 11, wait: 10)
    expect(page).to have_text("Compare up to 10 at once. Remove one to add another.")
    expect(page).to have_css("#similar-m-aventon-2026-pace_5_rec_step_through[aria-disabled='true']:not([href])")
    # an overview photo's × takes its model out of the comparison and the combobox
    within("[aria-label='Overview comparison']") { find("[aria-label='Remove Aventón Soltera 2.5']").click }
    expect(page).to have_css("#similar-m-aventon-2026-pace_5_rec_step_through[href]", wait: 10)
    expect(page).to have_css(".hw-combobox__chip", count: 9).and have_no_css(".hw-combobox__chip", text: "Soltera 2.5")

    # a human powered model's matching e-vehicles, and neither for a type that's always electric
    visit bikebook_path(vehicle_models: "m/specialized/2027/crux_5_s_level_sram_red_xplr", similar: 1, adjust: 1)
    expect(page).to have_field("Show matching e-bikes", wait: 10)
    visit bikebook_path(vehicle_models: "m/segway/2025/gt3_pro", similar: 1, adjust: 1)
    expect(page).to have_css("legend", exact_text: "Other settings", wait: 10)
    expect(page).to have_no_text("Show matching")
    # the other propulsion's instead with other_propulsion, without its e-bike fields counting against them, other vehicle
    # types with different_types, a frame only without same_configuration, other wheel sizes only without same_wheels,
    # more tire clearance nearer than as much less but not than less that's nearer, a frame's weight not held against it,
    # and a frame of the same material and bars of the same type closer, and only the same type with its slider at the top. None
    # nearly as far as one it knows nothing about, a groupset's tier however its series is written, and a slider's whole
    # weight on the fields the model lists, a rigid frame's suspension outweighing its material, and its own activity
    # closer than another of its family
    matched = page.evaluate_script(<<~JS)
      (async () => {
        const { GROUPS, scorer, settingsFrom } = await import('bikebook/similarity')
        const names = [...Object.values(GROUPS).flatMap(({ fields }) => Object.keys(fields)), 'groupset_series']
        // each alike in its geometry, wheels and weight, as a catalog model lists most of them
        const alike = { head_angle: 70, seat_angle: 74, stack_reach: 1.5, bb_drop: 70, chainstay_gap: 80, front_bsd: 622, rear_bsd: 622, tire_clearance: 45, total_weight: 10 }
        const fields = { ...Object.fromEntries(names.map((name) => [name, [null, null, null]])), ...Object.fromEntries(Object.entries(alike).map(([name, value]) => [name, [value, value, value]])) }
        const model = (id, electric, handlebar_type, suspension, activity = 'commuting') => ({ id, electric, handlebar_type, suspension, vehicle_type: 'bike', model_configuration: 'complete', manufacturer: id, group_key: id, primary_activity: activity, markets: ['US'] })
        const urban = [{ slug: 'commuting', family: 'urban' }]
        const scoring = (models, extra = {}, activities = urban) => scorer(models, { format: 2, fields: { ...fields, ...extra } }, activities)
        const score = scoring([model('e', true), model('other_e', true), model('acoustic', false)], { battery_size: [500, 500, null] })
        const propulsions = ['', 'other_propulsion=1'].map((query) => score('e', settingsFrom(new URLSearchParams(query))).models.map(({ id }) => id))
        const materials = scoring([model('a', false), model('steel', false), model('aluminum', false)], { frame_material: ['aluminum', 'steel', 'aluminum'] })
        const bars = scoring([model('a', false, 'drop_bar'), model('flat', false, 'horizontal'), model('drop', false, 'drop_bar')])
        const ids = (score, query = '') => score('a', settingsFrom(new URLSearchParams(query))).models.map(({ id }) => id)
        const types = scoring([model('a', false), { ...model('cargo', false), vehicle_type: 'cargo_bike' }, model('bike', false)])
        const far = scoring([model('a', false), model('near', false), model('far', false)],
          Object.fromEntries(Object.entries(alike).map(([name, value]) => [name, [value, value, value + 10]])))
        const groupsets = scoring([model('a', false), model('tiagra', false), model('s1000', false)], { groupset_series: ['S-1000', 'Tiagra', 'S1000'] })
        const suspensions = scoring([model('a', false, null, 'rigid'), model('full', false, null, 'full'), model('steel', false, null, 'rigid')],
          { frame_material: ['aluminum', 'aluminum', 'steel'] })
        const activities = scoring([model('a', false), model('touring', false, null, null, 'touring'), model('commuting', false)], {},
          [...urban, { slug: 'touring', family: 'urban' }])
        const configurations = scoring([model('a', false), { ...model('frame', false), model_configuration: 'frame' }, model('complete', false)])
        const wheels = scoring([model('a', false), model('small', false), model('road', false)], { front_bsd: [622, 584, 622], rear_bsd: [622, 584, 622] })
        const clearances = [[28, 36], [28, 40]].map(([tight, roomy]) => scoring([model('a', false), model(String(tight), false), model(String(roomy), false)],
          { tire_clearance: [32, tight, roomy] }))
        const weighed = scoring([model('a', false), model('complete', false), { ...model('frame', false), model_configuration: 'frame_fork' }],
          { total_weight: [10, 3, 3] })
        return [...propulsions, ids(types), ids(types, 'different_types=1'), ids(configurations), ids(configurations, 'same_configuration=1'),
          ids(wheels), ids(wheels, 'same_wheels=1'), ...clearances.map((each) => ids(each)), ids(weighed), ids(materials), ids(bars), ids(bars, 'weights=handlebar.4'), ids(far), ids(groupsets), ids(suspensions), ids(activities)]
      })()
    JS
    expect(matched).to eq([["other_e"], ["acoustic"], ["bike"], ["cargo", "bike"], ["complete", "frame"], ["complete"], ["small", "road"], ["road"], ["36", "28"], ["28", "40"], ["frame", "complete"], ["aluminum", "steel"], ["drop"], ["drop", "flat"], ["near"], ["s1000", "tiagra"], ["steel", "full"], ["commuting", "touring"]])
  end

  it "keeps the search and its filters while the catalog loads, and says so when it doesn't" do
    serve_bikebook_catalog(manifest_status: 404)
    held = Queue.new
    page.driver.with_playwright_page do |playwright_page|
      playwright_page.context.route("#{Integrations::Bikebook::Catalog::URL}manifest.json", ->(route, _request) { held << route })
    end
    # searching, which a model alone would hide
    visit bikebook_path(vehicle_models: "m/aventon/2026/level_4_rec_step_through", electric: "1", search: 1, vehicle_type: "e_scooter")

    # what only the catalog names waits on it, rather than reading as Any or its slug
    expect(page).to have_field("Select a bike, choose multiple to compare them", placeholder: "Loading…", disabled: true, wait: 10)
    expect(page).to have_field("Vehicle types", placeholder: "Loading…", disabled: true, visible: :all)
    expect(all("[aria-label='Applied filters'] li").map(&:text)).to eq ["Propulsion: e-Vehicle (motorized)"]
    held.pop.fulfill(status: 404, headers: {"access-control-allow-origin" => "*"}, body: "")
    expect(page).to have_text("The catalog didn't load. Reload the page to try again.", wait: 10)
    expect(page).to have_field("Vehicle types", placeholder: "", disabled: true, visible: :all)
    expect(page).to have_css("h1", exact_text: "The world’s bicycle library — search, compare, and find your next ride.")
    # the search waits on the catalog, but the filters work from the URL alone
    expect(page).to have_css("#vehicle_models[disabled]")
    click_on "More filters"
    expect(page).to have_checked_field("e-Vehicle (motorized)")
    check "Human powered (Acoustic)"
    expect(page).to have_current_path(/[?&]electric=0,1\b/)
  end
end
