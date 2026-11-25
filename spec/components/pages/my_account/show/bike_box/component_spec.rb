# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::MyAccount::Show::BikeBox::Component, type: :component do
  let(:component) { render_inline(box) }
  let(:user) { FactoryBot.create(:user_confirmed) }
  let(:organization) { FactoryBot.create(:organization, short_name: "Brakebills") }
  let(:bike) do
    FactoryBot.create(:bike, :with_ownership_claimed, user:, manufacturer: FactoryBot.create(:manufacturer, name: "Surly"),
      frame_model: "Midnight Special", serial_number: "SUR-77120934")
  end

  def box
    described_class.new(bike: bike.reload, current_user: user, user_alerts: described_class.user_alerts(user.reload),
      unfinished_b_params: described_class.unfinished_b_params([bike], user))
  end

  it "renders the registration, with no alerts" do
    expect(component).to have_link(href: "/bikes/#{bike.id}")
    expect(component).to have_css("strong", text: "Surly")
    expect(component).to have_text("SUR-77120934")
    expect(component).to have_link("List for sale")
    expect(component).to have_link("Mark stolen")
    expect(component).to have_link("Add a photo", href: "/bikes/#{bike.id}/edit/photos")
    expect(component).not_to have_css("[role=alert]")
    expect(component).not_to have_text("Hidden from other users")
    expect(component).not_to have_link(href: /strava_search/)
  end

  context "with only a stock photo" do
    before { bike.update(stock_photo_url: "https://bikebook.s3.amazonaws.com/uploads/Fr/10251/12_codacomp_bl.jpg") }

    it "shows it, and still asks for a photo of their own" do
      expect(component).to have_css("img[src*='small_12_codacomp_bl.jpg']")
      expect(component).to have_link("Add a photo", href: "/bikes/#{bike.id}/edit/photos")
    end
  end

  context "with a Bike Book catalog stock photo" do
    let(:stock_photo_url) { "https://bikebook.bikeindex.org/aventon/2022/level-2.jpg" }
    before { bike.update(stock_photo_url:) }

    it "shows it" do
      expect(component).to have_css("img[src='#{stock_photo_url}']")
    end
  end

  context "with a public image" do
    let!(:public_image) { FactoryBot.create(:public_image, imageable: bike) }

    it "is the public image's small url" do
      expect(component).to have_css("img[src='#{public_image.reload.image_url(:small)}']")
      expect(component).not_to have_text("Add a photo")
    end
  end

  context "with a photo of their own" do
    before { bike.update_column(:thumb_path, "https://files.bikeindex.org/uploads/Pu/1/small_bike.jpg") }

    it "links the photo to the bike, without asking for one" do
      expect(component).to have_css("a[href='/bikes/#{bike.id}'] img")
      expect(component).not_to have_text("Add a photo")
    end
  end

  context "hidden from other users" do
    before { bike.update(marked_user_hidden: true) }

    it "says so" do
      expect(component).to have_text("Hidden from other users")
    end
  end

  context "linked to Strava gear" do
    let!(:strava_gear) { FactoryBot.create(:strava_gear, item: bike, name: "My Road Bike", strava_id: "b1234") }

    it "links to Strava search for the gear" do
      expect(component).to have_link("My Road Bike", href: "/strava_search?gear=b1234")
    end
  end

  context "stolen, with an active impound claim" do
    let(:stolen_record) { FactoryBot.create(:stolen_record, bike:) }
    let(:bike_claimed) { FactoryBot.create(:bike) }
    let(:impound_record) { FactoryBot.create(:impound_record, bike: bike_claimed) }
    let!(:impound_claim) { FactoryBot.create(:impound_claim, stolen_record:, impound_record:, user:, status: :submitting) }

    it "edges the card in the status's colour, and links to the bike it claims" do
      expect(component).to have_css(".tw\\:border-l-red-600\\!")
      expect(component).to have_text("Submitted claim to")
      expect(component).to have_link("this found bike", href: "/bikes/#{bike_claimed.id}")
    end
  end

  describe "unfinished_b_params" do
    let!(:b_param) do
      FactoryBot.create(:b_param_unfinished_registration, creator: user, created_bike_id: bike.id,
        params: {bike: {manufacturer_id: bike.manufacturer_id, owner_email: owner_email}})
    end
    let!(:education_course_acknowledgment) { FactoryBot.create(:education_course_acknowledgment_pending, b_param:, bike:) }
    let(:owner_email) { user.email }

    it "finds the one the user still has to finish" do
      expect(described_class.unfinished_b_params([bike], user)).to eq(bike.id => b_param)
    end

    context "made for someone else, so its alert renders nothing" do
      let(:owner_email) { "someone-else@example.com" }

      it "leaves it out" do
        expect(described_class.unfinished_b_params([bike], user)).to eq({})
      end
    end
  end

  context "an e-bike" do
    before { bike.update(cycle_type: :bike, propulsion_type: :"pedal-assist") }

    it "marks it as an e-vehicle" do
      expect(component).to have_text("⚡")
      expect(component).to have_text("E-vehicle")
    end
  end

  context "with a bike sticker" do
    before { FactoryBot.create(:bike_sticker_claimed, code: "A40340", bike:, user:) }

    it "lists its code, with the registered and updated dates" do
      expect(component).to have_text(/Bike Sticker:\s+A 403 40/)
      expect(component).to have_text("Registered")
      expect(component).to have_text("Updated")
    end
  end

  context "stolen, with an address" do
    before do
      FactoryBot.create(:stolen_record, bike:, street: "100 W 1st St", city: "Chicago", postal_code: "60608")
      bike.update(updated_at: Time.current)
    end

    it "shows where" do
      expect(component).to have_text("Chicago")
    end
  end

  context "when the bike is for sale" do
    before { bike.update(is_for_sale: true) }

    it "offers to update the listing, and says it's for sale" do
      expect(component).to have_text("For Sale")
      expect(component).to have_link("Update listing")
      # The registered date in the badge, and the updated date
      expect(component).to have_css(".localizeTime", count: 2)
    end
  end

  context "with an unassigned_bike_org alert" do
    let!(:user_alert) { FactoryBot.create(:user_alert, user:, bike:, organization:, kind: "unassigned_bike_org") }
    let!(:other_alert) { FactoryBot.create(:user_alert, user:, organization:, kind: "unassigned_bike_org", bike: FactoryBot.create(:bike)) }

    before { UserAlert.refresh_alert_slugs(user) }

    it "renders only this bike's alert, tucked under the card" do
      expect(component).to have_css("[role=alert]", count: 1)
      expect(component).to have_css("li > div:last-child.tw\\:-mt-3 [role=alert].tw\\:pt-5\\!")
      expect(component).to have_text("associated with Brakebills")
      expect(component).to have_css("form[action='/user_alerts/#{user_alert.id}?add_bike_organization=true'] button", text: "Add it now!")
      expect(component).to have_css("form[action='/user_alerts/#{user_alert.id}?alert_action=dismiss'] button", text: "Ignore this suggestion")
    end
  end

  context "with the registration unfinished" do
    before do
      b_param = FactoryBot.create(:b_param_unfinished_registration, creator: user, created_bike_id: bike.id,
        params: {bike: {manufacturer_id: bike.manufacturer_id, owner_email: user.email}})
      FactoryBot.create(:education_course_acknowledgment_pending, b_param:, bike:)
    end

    it "renders the unfinished registration alert, above the registration" do
      expect(component).to have_css("li > [role=alert]:first-child", text: "Your Surly bike isn't registered yet!")
      expect(component).to have_link("finish the required steps")
    end
  end

  context "with caching", :caching do
    include_context :caching_basic

    def render_box = with_controller_class(ApplicationController) { render_inline(box) }

    it "caches the registration, and renders alerts outside the cache" do
      keys = fragments_written { render_box }
      expect(keys.count).to eq 1
      expect(keys.first).to include(bike.cache_key_with_version)
      expect(fragments_written { render_box }).to eq([])

      FactoryBot.create(:user_alert, user:, bike:, organization:, kind: "unassigned_bike_org")
      UserAlert.refresh_alert_slugs(user)
      rendered = nil
      expect(fragments_written { rendered = render_box }).to eq([])
      expect(rendered).to have_text("associated with Brakebills")
    end
  end
end
