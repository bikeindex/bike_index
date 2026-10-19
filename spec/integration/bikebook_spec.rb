# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Bikebook", :js, type: :system do
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
    tips = "[aria-label='How to use Bike Book']"
    expect(page).to have_css(tips).and have_link("Trek Marlin 5 vs Specialized Rockhopper Sport", href: %r{vehicle_models=m/trek/2026/marlin_5_gen_3,})
    # and, filtered or not, some of the catalog to start from, in its order: half e-bikes, as far as the five models
    # that aren't go, each a class legal where the visitor is (so no Segway GT3 Pro, Haul ST CA or Sur-Ron), and at
    # least three at $1,500 or less
    expect(page).to have_text("30 models to compare.")
    expect(find("[aria-label='Models to compare']").all("a").map { it[:href][/vehicle_models=(.+)/, 1] }).to eq %w[m/aventon/2026/current_exp
      m/aventon/2025/aventure_m m/aventon/2026/ramblas_adv m/aventon/2026/level_4_adv m/specialized/2025/haul_st m/aventon/2025/abound_lr
      m/aventon/2026/soltera_3_adv m/kris_holm/2023/kh36 m/kris_holm/2023/kh29 m/kris_holm/2023/kh27_5 m/kris_holm/2023/kh24 m/kris_holm/2023/kh20]
    within(tips) { click_on "More filters" }
    expect(page).to have_css("#vehicle-filters", visible: true)
    # which a filter changes in place
    check "Human powered (Acoustic)"
    expect(page).to have_text("5 models match your filters.")
    expect(all("[aria-label='Models to compare'] a").map { it[:href][/vehicle_models=(.+)/, 1] })
      .to eq %w[m/kris_holm/2023/kh36 m/kris_holm/2023/kh29 m/kris_holm/2023/kh27_5 m/kris_holm/2023/kh24 m/kris_holm/2023/kh20]
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
    expect(page).to have_css(".hw-combobox__group__label", text: /\(30 matching models\)/i)

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
      .to eq(["Model group", "Years", "Primary activity", "Frame material", "Suspension front/rear", "Groupset", "Price", "E-vehicle class", "Electric Certification", "Description"])
    # no groupset listed, so its gear count alone, with the rest of its drivetrain in the tooltip
    expect(find("[aria-label='Overview'] tr", text: /\AGroupset/).find("td").text(:all).squish).to match(/\A1x8 \? Drivetrain: /)
    expect(find("[aria-label='Overview']")).to have_text("The Level 4 REC").and have_button("Read more")
    expect(page).to have_title(/Aventón Level 4 REC Step-Through/)
    expect(page).to have_css(".hw-combobox__chip", text: "Aventón Level 4 REC Step-Through")
    expect(page).to have_current_path("/bikebook?search=1&vehicle_models=m/aventon/2026/level_4_rec_step_through")
    # for the search logs, what the reader typed once they stopped, and then what they picked
    expect(logged).to eq ["count=2&q=level+4+rec", "vehicle_models=m/aventon/2026/level_4_rec_step_through"]

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
    # certification is unknown, as the motor's section says. Wheel sizes and vehicle types show only where they differ, and
    # each end's travel once one is suspended, its specs under its heading in one tooltip
    classes = page.evaluate_script(<<~JS)
      (async () => {
        const catalog = (file) => fetch(`https://bikebook-catalog.bikeindex.org/catalog/${file}`).then((response) => response.json())
        const [{ VehiclePresenter }, { basics }, { fragmentOf }, { kit }, vocabulary] = await Promise.all([import('bikebook/vehicle_presenter'),
          import('bikebook/templates/vehicles/basics'), import('bikebook/render'), catalog('kit.json'), catalog('vocabulary.json')])
        const wheels = (front, rear) => [{ bsd: front, position: ['front'] }, { bsd: rear, position: ['rear'] }]
        const rowsOf = (datas) => [...fragmentOf(basics({ presenter: new VehiclePresenter(kit, vocabulary), vehicles: datas.map((data, index) => ({ value: String(index), data })) }))
          .querySelectorAll('tbody tr')]
        const rows = rowsOf([{ model: 'Electric', type: 'cargo_bike', motors: [{ rated_power: 250 }], wheels: wheels(622, 584), suspension: { front: { travel: 120 } } },
          { model: 'Acoustic', type: 'bike', wheels: wheels(622, 622) }])
        const cells = (label) => [...rows.find((each) => each.querySelector('th').textContent.trim() === label).querySelectorAll('td')]
        return [cells('E-vehicle class').map((cell) => [cell.textContent.trim(), cell.querySelector('.twless-strong') != null]),
          cells('Electric Certification').map((cell) => [...cell.querySelectorAll('button')].map((badge) => badge.textContent.replace(/\\s+/g, ' ').trim())),
          cells('Wheel size').map((cell) => cell.textContent.replace(/\\s+/g, ' ').trim()), cells('Vehicle type').map((cell) => cell.textContent.trim()),
          cells('Suspension front/rear').map((cell) => [cell.textContent.replace(/\\s+/g, ' ').trim(), [...cell.querySelectorAll('.twless-strong')].map((each) => each.textContent)]),
          rowsOf([{ model: 'One', type: 'bike', wheels: wheels(622, 622) }, { model: 'Two', type: 'bike', wheels: wheels(622, 622) }])
            .filter((row) => /Wheel size|Vehicle type|Suspension/.test(row.textContent)).length]
      })()
    JS
    expect(classes).to eq([[["—", false], ["not e-vehicle", true]], [["? Certification unknown"], []], ["700 C front, 650 B rear", "700 C"], ["Cargo Bike", "Bike"], [["120 mm front (no rear suspension) ? Front suspensionTravel: 120 mm", []], ["Rigid", ["Rigid"]]], 0])
    # a description over 200 characters is cut at a word, its paragraphs kept, and one within them is whole
    excerpts = page.evaluate_script(<<~JS)
      (async () => {
        const catalog = (file) => fetch(`https://bikebook-catalog.bikeindex.org/catalog/${file}`).then((response) => response.json())
        const [{ VehiclePresenter }, { basics }, { fragmentOf }, { kit }, vocabulary] = await Promise.all([import('bikebook/vehicle_presenter'),
          import('bikebook/templates/vehicles/basics'), import('bikebook/render'), catalog('kit.json'), catalog('vocabulary.json')])
        const description = (text) => {
          const rendered = fragmentOf(basics({ presenter: new VehiclePresenter(kit, vocabulary), vehicles: [{ value: '0', data: { model: 'One', description: text } }] }))
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
    # the wheels compared under the size, rather than on each model's sizes card (these list no max tire)
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
    # wheels alone - its wheelbase apart - on the drawn frame's rear axle, saying which it's missing
    within("[aria-label='Geometry overlay']") do
      expect(first("ul").all("li").map(&:text)).to eq(["Aventón Level 4 REC Step-Through Regular", "Aventón Level 2 Step-Through M/L"])
      frames = all("svg[role='img'] > g", visible: :all).map { |frame| [frame.all("circle", visible: :all).map { it[:cx].to_f }, frame.has_css?("path", visible: :all)] }
      expect(frames).to match([[[be < 0, be > 0], true], [[be < 0, be > 0], false]])
      expect(frames.dig(1, 0, 1) - frames.dig(1, 0, 0)).to be_within(0.1).of(1130)
      expect(page).to have_text(/Aventón Level 2 Step-Through doesn't list its BB Drop, Head Angle, .* or the measures to calculate them, so only its wheels/)
        .and have_text("are drawn, the rear axle on Aventón Level 4 REC Step-Through's.")
      # the same wheel size, its tires too near each other's for the wheel note
      expect(page).to have_no_text("diameter")
    end
    within("[aria-label='Sizes & geometry comparison']") do
      expect(page).to have_css("thead th", text: "Level 2 Step-Through")
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
    # under its frame, wheels, brakes, suspension and drivetrain
    headings = find("section[aria-label='Aventón Level 2 Step-Through components']").all("h2").map { it.text.downcase }
    expect(headings.first(5)).to eq(["frame", "wheels", "brakes", "suspension", "drivetrain"])
    # each row level with the other card's, its blank standing in where only the other has the component
    tops = page.evaluate_script(<<~JS)
      [...document.querySelectorAll("section[aria-label$=' components']")].map((card) => [...card.querySelectorAll('[data-align-row]')]
        .map((row) => [row.dataset.alignRow, Math.round(row.getBoundingClientRect().top)]))
    JS
    expect(tops.first.map(&:first)).to eq(tops.last.map(&:first))
    expect(page).to have_css("section[aria-label$=' components'] tbody tr", exact_text: "")
    expect(tops.first.zip(tops.last).map { |(_, first), (_, last)| (first - last).abs }).to all(be <= 1)
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
    expect(history_length.call).to eq entries
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
        const data = { model: 'Enduro', frame: { material: 'aluminum', coil_compatible: true }, groupset: { manufacturer: 'SRAM', description: 'GX Eagle', electronic: false },
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
    # its groupset's tooltip the rest of its drivetrain
    expect(specs["groupset"]).to match(/\ASRAM GX Eagle, 1x12 \? Drivetrain: 1 Front, 12 Rear Chainring: 32\W*t Cogs: 10–\W*52\W*t\z/)
    expect(specs["suspension"]).to eq([["Front", "170 mm, lockout ? Travel: 170 mm Spring: Air Lockout: Yes"], ["Rear", "160 mm, 157.5 × 62.5 mm shock, coil"]])
    expect(specs["frame"]).to include(["Coil compatible", "Yes"])

    find("[aria-label='Remove Aventón Level 2 Step-Through']").click
    expect(page).to have_css("article", count: 1)
    expect(page).to have_no_css("[data-comparison]")
    expect(page).to have_css(".hw-combobox__chip", count: 1)
    # one model still gets the table and the overlay, its frame alone
    click_link "Sizes & geometry"
    expect(page).to have_css("[aria-label='Sizes & geometry comparison'] thead th", count: 2).and have_css("[aria-label='Geometry overlay'] svg g", count: 1)

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

    # A filter's options count the catalog's models, and its chips come from them
    click_on "More filters"
    # the classes are the US market's, which the visitor's country isn't
    expect(page).to have_no_field("US Class 2")
    choose_option("Market", "United States")
    expect(page).to have_css("#vehicle-models-count", exact_text: "(23 matching models)")
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
    choose_option("Market", "Any")
    expect(page).to have_css("#vehicle-models-count", exact_text: "(30 matching models)")
    find_field("Manufacturers").click
    find("#manufacturer-hw-listbox [role='option']", text: "Kris Holm (5)").click
    expect(page).to have_css("[data-async-id='manufacturer'] .hw-combobox__chip", text: "Kris Holm")
    expect(page).to have_css("#vehicle-models-count", exact_text: "(5 matching models)")
    # checked propulsions match any of them
    check "e-Vehicle (motorized)"
    expect(page).to have_css("#vehicle-models-count", exact_text: "(0 matching models)")
    check "Human powered (Acoustic)"
    expect(page).to have_css("#vehicle-models-count", exact_text: "(5 matching models)")
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
    expect(page).to have_css("#vehicle-models-count", exact_text: "(30 matching models)")
    expect(page).to have_no_link("Clear filters").and have_no_css("[aria-label='Applied filters'] li")
    expect(page).to have_css(".hw-combobox__chip", count: 2).and have_css("[data-comparison] article", count: 2)
    expect(page).to have_no_current_path(/manufacturer|electric/)
    # and from the open panel, where the market and e-bike classification are nothing to clear, and stay through a clear
    click_on "More filters", match: :first
    find_field("Market").click
    find("#market-hw-listbox [role='option']", text: "United States (US)").click
    expect(page).to have_css("#vehicle-models-count", exact_text: "(23 matching models)")
    check "US Class 2"
    expect(page).to have_css("#vehicle-models-count", exact_text: "(18 matching models)")
    expect(page).to have_no_link("Clear filters")
    choose_option("Suspension", "Rigid")
    within("#vehicle-filters") { click_link "Clear filters" }
    expect(page).to have_css("#vehicle-models-count", exact_text: "(18 matching models)")
    expect(page).to have_no_current_path(/suspension/)
    expect(page).to have_checked_field("US Class 2").and have_checked_field("e-Vehicle (motorized)").and have_field("Market", with: "United States (US)")
    expect(page).to have_current_path(/[?&]market=US\b/).and have_current_path(/[?&]electric=1,class_2(&|\z)/)

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
    # a vehicle listing no figure that sizes a frame is its wheels alone, the rear axle on the first frame's, under a note
    expect(page).to have_css("[aria-label='Geometry overlay'] p + ul li", exact_text: "Segway GT3 Pro doesn't list its Reach, Stack, Top Tube (effective), " \
      "Front Centre and Head Tube or the measures to calculate them, so only its wheels are drawn, the rear axle on Aventón Level 4 REC Step-Through's.")
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

    # and on a phone too, rather than stacking
    page.current_window.resize_to(390, 844)
    expect(card_rows.call).to eq 1
    expect(scrolls_sideways.call).to be true
    page.current_window.resize_to(1920, 1080)
  end

  it "searches the visitor's market and shows their state's classes until others are chosen, leaving them out of the URL" do
    serve_bikebook_catalog
    page.driver.with_playwright_page { it.set_extra_http_headers("CF-IPCountry" => "CA") }
    logged = []
    page.driver.with_playwright_page { it.on("request", ->(request) { logged << request.url.split("?").last if request.url.include?(search_bikebook_path) }) }
    visit bikebook_path
    expect(page).to have_css("#vehicle-models-count", exact_text: "(6 matching models)", wait: 10)
    type_into(vehicle_field, "haul")
    expect(page).to have_css(vehicle_option, count: 1, text: "$3,599.99")
    # the URL says the search shows, but not what's typed or the visitor's own market
    expect(page).to have_current_path("/bikebook?search=1")
    # but a model's exact id finds it, though the market leaves it out, saying so rather than counting it
    type_into(vehicle_field, "m/specialized/2025/haul_st")
    expect(page).to have_css(".hw-combobox__group__label", exact_text: "(model doesn't match filters)")
    expect(page).to have_css(vehicle_option, count: 1).and have_no_css(vehicle_option, text: "$3,599.99")
    type_into(vehicle_field, "m/specialized/2025/haul_st_ca")
    expect(page).to have_css(".hw-combobox__group__label", exact_text: "(1 matching model)")

    # its listbox closed, which covers the filters
    vehicle_field.send_keys(:escape)
    click_on "More filters", match: :first
    expect(page).to have_field("Market", with: "Canada (CA)")
    find_field("Market").click
    # by name rather than the catalog's order, which is by code, and only those with models
    # each with its code, as a state's shown, rather than a count
    markets = all("#market-hw-listbox [role='option']").map(&:text)
    expect(markets).to eq ["Any", "Canada (CA)", "China (CN)", "United Arab Emirates (AE)", "United States (US)"]
    find("#market-hw-listbox [role='option']", exact_text: "Any").click
    expect(page).to have_css("#vehicle-models-count", exact_text: "(30 matching models)")
    expect(page).to have_current_path(/[?&]market=all\b/)
    # each re-runs the vehicle combobox's search, logged once it settles, though only the market changed
    page.evaluate_script("new Promise((resolve) => setTimeout(resolve, 1100))")
    expect(logged.last).to end_with "&market=all&q=Specialized+Haul+ST+%282025%29"
    type_into(find_field("Market"), "united")
    find("#market-hw-listbox [role='option']", text: "United States (US)").click
    expect(page).to have_css("#vehicle-models-count", exact_text: "(23 matching models)")
    expect(page).to have_current_path(/[?&]market=US\b/)
    page.evaluate_script("new Promise((resolve) => setTimeout(resolve, 1100))")
    expect(logged.last).to eq "count=0&market=US&q=Specialized+Haul+ST+%282025%29"
    # and stays out of the collapsed filters' summary
    expect(find("[aria-label='Applied filters']", visible: :all).text(:all)).to be_empty

    # a market the catalog has no models in searches them all
    page.driver.with_playwright_page { it.set_extra_http_headers("CF-IPCountry" => "JP") }
    visit bikebook_path
    expect(page).to have_css("#vehicle-models-count", exact_text: "(30 matching models)", wait: 10)

    # and a visitor Cloudflare can't place searches the US
    page.driver.with_playwright_page { it.set_extra_http_headers("CF-IPCountry" => "XX") }
    visit bikebook_path
    expect(page).to have_css("#vehicle-models-count", exact_text: "(23 matching models)", wait: 10)

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
    expect(page).to have_no_link("Search other bikes")
    expect(page).to have_current_path("/bikebook?vehicle_models=m/aventon/2026/level_4_rec_step_through&view=all&search=1")
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
    expect(page).to have_title("Bikebook", exact: true)

    # pasted and entered at once, an id is picked, though its search answers after the Enter
    vehicle_field.set("m/aventon/2026/level_4_rec_step_through")
    vehicle_field.send_keys(:enter)
    expect(page).to have_css("article h1", text: "Level 4 REC Step-Through")
    expect(page).to have_current_path("/bikebook?view=all&search=1&vehicle_models=m/aventon/2026/level_4_rec_step_through")

    # the Bike Book mark goes back to the empty search
    click_link "Bike Book"
    expect(page).to have_no_css("article")
    expect(page).to have_current_path("/bikebook?search=1")

    # Filters with nothing picked say what they leave, and lead into the list or back to the filters
    visit bikebook_path(price_max: 3000)
    expect(page).to have_text("20 models match your filters.", wait: 10)
    # under the tips' card, over some of what they leave: a manufacturer not yet listed first, then an activity, then a
    # model group, and both models at $1,500 or less. Each is an e-bike, as the market has no other under $3,000
    expect(page).to have_css("[data-bikebook--tips-target='prompt'] + p", text: "20 models match your filters.")
    featured = find("[aria-label='Models to compare']")
    expect(featured.all("a").map { it[:href][/vehicle_models=(.+)/, 1] }).to eq %w[m/aventon/2025/aventure_m m/aventon/2026/ramblas_adv
      m/aventon/2026/level_4_adv m/aventon/2026/level_4_adv_step_through m/specialized/2025/haul_st m/aventon/2025/abound_lr
      m/aventon/2025/aventure_3 m/aventon/2025/aventure_3_step_through m/aventon/2024/sinch_2_5 m/aventon/2025/pace_4_step_through
      m/aventon/2026/soltera_3_adv m/aventon/2024/soltera_2_5]
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
    expect(page).to have_css(".hw-combobox__chip", text: "Specialized Haul ST")
    # filters leaving no legal e-bike feature what they do leave
    visit bikebook_path(vehicle_type: "e_motorcycle")
    expect(page).to have_css("[aria-label='Models to compare'] a", text: "Sur-Ron", wait: 10)
    # outside the US, an e-bike is legal by the market's own e-bike law, which the Canadian model is under with no US class
    visit bikebook_path(market: "CA")
    expect(page).to have_css("[aria-label='Models to compare'] a", text: "Specialized Haul ST", wait: 10)
    visit bikebook_path(primary_activity: "atb_gravel", price_max: 1500)
    expect(page).to have_text("No models match your filters.", wait: 10)
    # the example whose filters these are, active
    expect(page).to have_css("a[data-active='true']", count: 1, exact_text: "Gravel bikes under $1,500")
    click_on "Change filters"
    expect(page).to have_css("#vehicle-filters", visible: true)
    # as the steps' More filters does, through the panel's own collapse, focusing its first field
    visit bikebook_path
    within("[aria-label='How to use Bike Book']", wait: 10) { click_on "More filters" }
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
  end

  it "keeps each compared vehicle's size in the URL, the others nearest the first's by top tube unless picked" do
    serve_bikebook_catalog
    visit bikebook_path(vehicle_models: "m/aventon/2026/current_adv,m/aventon/2026/current_exp", view: "geometry")
    expect(page).to have_css("[aria-label='Sizes & geometry comparison'] tbody th", exact_text: "Size", wait: 10)

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

    overlay = find("[aria-label='Geometry overlay'] svg[role='img']")
    medium = [overlay[:viewBox], overlay.find("g > path", match: :first, visible: :all)[:d]]
    size_select.call("Current ADV").select("Large")
    expect_size.call("Current EXP", "Large")
    # the overlay draws each in its size
    within("[aria-label='Geometry overlay']") do
      expect(all("li").map(&:text)).to eq(["Aventón Current ADV Large", "Aventón Current EXP Large"])
      # to the same scale, so the larger frame draws larger
      expect(find("svg[role='img']")[:viewBox]).to eq medium.first
      expect(find("svg[role='img'] g > path", match: :first, visible: :all)[:d]).not_to eq medium.last
      # the leftmost column's frame lowest
      expect(all("svg[role='img'] > g > title", visible: :all).map { it.text(:all) }).to eq(["Aventón Current ADV, Large", "Aventón Current EXP, Large"])
      # a legend button fades the other frame and draws its own on top, until it's pressed again
      wait_for_stimulus("bikebook--geometry-overlay")
      click_on "Aventón Current ADV"
      expect(page).to have_css("button[aria-pressed='true']", count: 1, text: "Current ADV")
      expect(all("svg[role='img'] > g", visible: :all).map { it[:opacity] }).to eq([nil, "0.2"])
      expect(find("svg[role='img'] > use", visible: :all)[:href]).to eq "#geometry-frame-0"
      click_on "Aventón Current ADV"
      expect(page).to have_no_css("button[aria-pressed='true']")
      expect(page).to have_no_css("svg[role='img'] > g[opacity]", visible: :all)
    end
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
          frame({ bb_drop: 70 }, [{ type: 'tire', dimensions: { width: 30 } }], { wheels: [{ bsd: 622, position: ['front', 'rear'] }] }).rearRadius, frameGeometry(data, { geometry: { wheelbase: 1020 } })]
      })
    JS
    # the front axle from the fork's rake, or its fork's or its trail's where the size lists none, a rake from where its
    # wheelbase puts the front axle, and without any, its kind's or no frame; a head tube from the fork's length, and without it none; a seat tube slacker than its effective angle ending
    # on the down tube; the head tube's top from the fork and top tube; wheels from the bottom bracket's height and drop,
    # and the trail; a BMX's fork and head tube a typical one's, and a road bike's tire; a tire its component's where its
    # wheel lists none; and without any figure that sizes a frame, only its wheels
    expect(frames).to eq([[[-414, 70], [606, 70], [446, 457], [-146, 478], [0, 0]], 281, [], [-414, 70], ["seat_tube_ct"], ["fork_rake"], ["fork_rake"],
      [["fork_rake"], "road bike"],
      [625, 70], [616, 70], [453, 438], ["head_tube"], [33, 34], [[405, 572], %w[reach stack]], ["wheel_size"], [360, 361, ["wheel_size"]], 9,
      [[367, 567], %w[reach stack], %w[fork_rake fork_length_a2c head_tube]], [339, {"bsd" => 622, "tire" => 28, "rimListed" => true}], 341,
      {"missing" => %w[reach stack top_tube_effective front_center head_tube], "wheels" => {"rearRadius" => 351, "frontRadius" => 351, "wheelbase" => 1020}}])

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

    # Small's top tube is nearer Soltera's Medium than its Small
    type_into(vehicle_field, "soltera")
    retry_on_detach { find(vehicle_option, text: "Aventón Soltera 3 ADV").click }
    expect(page).to have_css("[data-comparison] article", count: 2)
    click_link "Sizes & geometry"
    expect_size.call("Soltera 3 ADV", "Medium")
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
        const [{ VehiclePresenter }, { geometryOverlay }, { frameGeometry }, { render }, { kit }, vocabulary] = await Promise.all([
          import('bikebook/vehicle_presenter'), import('bikebook/templates/vehicles/geometry_overlay'), import('bikebook/frame_geometry'),
          import('lit-html'), catalog('kit.json'), catalog('vocabulary.json')])
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
          render(geometryOverlay({ presenter, vehicles, sizes, frames: vehicles.map(({ data }, index) => frameGeometry(data, sizes[index])) }), container)
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

    # one frame to draw is drawn alone, and the overlay says what the other is missing
    lone = page.evaluate_script(<<~JS)
      (async () => {
        const catalog = (file) => fetch(`https://bikebook-catalog.bikeindex.org/catalog/${file}`).then((response) => response.json())
        const [{ VehiclePresenter }, { geometryOverlay }, { frameGeometry }, { render }, { kit }, vocabulary] = await Promise.all([
          import('bikebook/vehicle_presenter'), import('bikebook/templates/vehicles/geometry_overlay'), import('bikebook/frame_geometry'),
          import('lit-html'), catalog('kit.json'), catalog('vocabulary.json')])
        const presenter = new VehiclePresenter(kit, vocabulary)
        const geometry = { reach: 450, stack: 620, head_angle: 64, chainstay: 445, bb_drop: 20, seat_angle: 77, head_tube: 120, fork_rake: 44 }
        const road = { model: 'Road', sizes: [{ name: 'M', geometry }], wheels: [{ bsd: 622, tire_width: 25, position: ['front', 'rear'] }] }
        const bare = { model: 'Bare', sizes: [{ name: 'M' }] }
        const vehicles = [{ data: road }, { data: bare }]
        const sizes = [road.sizes[0], bare.sizes[0]]
        const container = document.createElement('div')
        render(geometryOverlay({ presenter, vehicles, sizes, frames: vehicles.map(({ data }, index) => frameGeometry(data, sizes[index])) }), container)
        return [container.querySelectorAll("svg[role='img'] > g").length, [...container.querySelectorAll('li')].at(-1).textContent.replace(/\\s+/g, ' ').trim()]
      })()
    JS
    expect(lone).to eq([1, "Bare doesn't list its Reach, Stack, Top Tube (effective), Front Centre and Head Tube or the measures to calculate them, " \
      "so it can't be drawn."])

    # the first vehicle's last pick is what a comparison with none picked starts nearest
    visit bikebook_path(vehicle_models: "m/aventon/2026/level_4_adv,m/aventon/2026/current_exp", view: "geometry")
    expect(page).to have_css("[aria-label='Sizes & geometry comparison']", wait: 10)
    expect_size.call("Level 4 ADV", "Extra Large")
    expect_size.call("Current EXP", "Extra Large")
    # 650b against 700c, whatever their tires
    expect(diameters.call).to eq(["Aventón Level 4 ADV's 650 B wheels with 56 mm tires are approximately 696 mm diameter",
      "Aventón Current EXP's 700 C wheels with 64 mm tires are approximately 750 mm diameter"])
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
    # a tire's difference in mm all the same
    expect(find("[aria-label='Sizes & geometry comparison'] tr", text: "Front wheel")).to have_css(".tw\\:text-gray-500", text: /\A−8\W*mm\z/)
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
      expect_template(UI::Badge::Component.new(text: "⚡", title: "E-vehicle", color: :purple), "bikebook/templates/ui/badge#badge",
        "{ text: '⚡', title: 'E-vehicle', color: 'purple' }")

      expect_template(UI::IconChevron::Component.new(size: :md), "bikebook/templates/ui/icon_chevron#iconChevron", "{ size: 'md' }")
      expect_template(UI::IconChevron::Component.new, "bikebook/templates/ui/icon_chevron#iconChevron", "undefined")

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
      expect(series.map { it["color"] }).to eq(UI::Chart::Component::COLORS.first(5))
      expect(series).to all(satisfy { |each| [each["bottom"], each["top"]] == ["tw:border-b-[#{each["color"]}]!", "tw:border-t-[#{each["color"]}]!"] })

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
      /\ATotal length: 194\W*cm \(6 feet, 4\.4 inches\) \(total length is the wheelbase plus each wheel’s radius, estimating its tire based on its width\) Cargo length: 78\.7\W*cm \(2 feet, 7 inches\)\z/,
      /\AMax load \(rider \+ cargo\) 160\W*kg\z/, /\AGross weight rating \(bike \+ rider \+ cargo\) 200\W*kg\z/])
    click_link "All"
    expect(page).to have_css("section div", text: /\AE-vehicle class\s*US Class 3 \?\s*w\/ optional throttle US Class 2 \?\z/, wait: 10)
    expect(page).to have_css("dd > span.tw\\:block", text: /\Aw\/ optional throttle US Class 2/)
    # years keyed by year, read newest first, each with its colorways, and the max load with the frame
    years = find("article h1", text: "Haul ST").ancestor("article").find("h2", text: /\Amodel years\z/i).ancestor("section")
    expect(years.all("tr").map { it.first("td").text }).to eq %w[2026 2025]
    expect(years).to have_text("Satin Obsidian").and have_text("Gloss White Mountains")
    expect(find("h2", text: /\Aframe\z/i).ancestor("section")).to have_text(/Max load \(rider \+ cargo\)\W*190\W*kg/)

    # beside its Canadian model, sold outside the visitor's market, the Overview leads with each one's, until any market will do
    visit bikebook_path(vehicle_models: "m/specialized/2025/haul_st,m/specialized/2025/haul_st_ca", filters: 1)
    expect(page).to have_css("[aria-label='Overview comparison'] tbody tr:first-child", text: /\AMarkets\s*United States\s*Canada\z/, wait: 10)
    choose_option("Market", "Any")
    expect(page).to have_no_css("[aria-label='Overview comparison'] th", exact_text: "Markets")

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
      .and have_text(/models to compare\. Search them/).and have_no_css("[aria-label='How to use Bike Book']").and have_no_text("Nothing selected yet")
    expect(page).to have_current_path("/bikebook?classifications=evc/us/class_3&search=1")
  end

  it "keeps the search and its filters while the catalog loads, and says so when it doesn't" do
    serve_bikebook_catalog(manifest_status: 404)
    # searching, which a model alone would hide
    visit bikebook_path(vehicle_models: "m/aventon/2026/level_4_rec_step_through", electric: "1", search: 1)

    expect(page).to have_text("The catalog didn't load. Reload the page to try again.", wait: 10)
    expect(page).to have_css("h1", exact_text: "The world’s bicycle library — search, compare, and find your next ride.")
    # the search waits on the catalog, but the filters work from the URL alone
    expect(page).to have_css("#vehicle_models[disabled]")
    click_on "More filters"
    expect(page).to have_checked_field("e-Vehicle (motorized)")
    check "Human powered (Acoustic)"
    expect(page).to have_current_path(/[?&]electric=0,1\b/)
  end
end
