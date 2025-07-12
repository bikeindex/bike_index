# frozen_string_literal: true

require "rails_helper"

RSpec.describe SearchResults::BikeBox::Component, type: :component do
  let(:options) { {bike:, current_user:, skip_cache:} }
  let(:skip_cache) { false }
  let(:instance) { described_class.new(**options) }
  let(:component) { render_inline(instance) }
  let(:bike) { FactoryBot.create(:bike) }
  let(:current_user) { User.new }

  def expect_serial_is_hidden(component, serial, skip_cache: false)
    expect(component).to have_text("hidden because")
    expect(component).to_not have_text(serial.upcase)
    expect(instance.instance_variable_get(:@is_cached)).to eq(!skip_cache)
  end

  def expect_serial_is_visible(component, serial, skip_cache: false)
    expect(component).to have_text(serial.upcase)
    expect(instance.instance_variable_get(:@is_cached)).to eq(!skip_cache)
  end

  it "renders" do
    expect(component).to be_present
    expect(component).to have_content bike.mnfg_name
    expect(component.css("a").first["href"]).to match("/bikes/#{bike.id}")

    expect_serial_is_visible(component, bike.serial_number)
  end

  context "with stolen_record" do
    let!(:stolen_record) { FactoryBot.create(:stolen_record, bike:) }
    it "renders" do
      expect(bike.reload.status).to eq "status_stolen"
      expect(component).to have_content bike.mnfg_name
      expect(component).to have_content "stolen"
      expect(component.css("a").first["href"]).to match("/bikes/#{bike.id}")
      expect(component).to have_content(l(stolen_record.date_stolen, format: :convert_time))

      expect_serial_is_visible(component, bike.serial_number)
    end
  end

  context "with impound_record" do
    let!(:impound_record) { FactoryBot.create(:impound_record, bike:) }
    it "renders" do
      expect(bike.reload.status).to eq "status_impounded"
      expect(bike.send(:can_see_hidden_serial?, current_user)).to be_falsey
      expect(component).to have_content bike.mnfg_name
      expect(component).to have_content "found"
      expect(component.css("a").first["href"]).to match("/bikes/#{bike.id}")
      expect(component).to have_content(l(impound_record.impounded_at, format: :convert_time))

      expect_serial_is_hidden(component, bike.serial_number)
    end

    context "with current_user" do
      let(:bike) { FactoryBot.create(:bike, :with_ownership, user: current_user) }
      let(:current_user) { FactoryBot.create(:user) }

      it "renders without serial" do
        expect(bike.reload.status).to eq "status_impounded"
        expect(bike.send(:can_see_hidden_serial?, current_user)).to be_truthy
        expect(component).to have_content bike.mnfg_name
        expect(component).to have_content "found"
        expect(component.css("a").first["href"]).to match("/bikes/#{bike.id}")
        expect(component).to have_content(l(impound_record.impounded_at, format: :convert_time))

        expect_serial_is_hidden(component, bike.serial_number)
      end

      context "with skip_cache" do
        let(:skip_cache) { true }
        it "renders serial" do
          expect(bike.reload.status).to eq "status_impounded"
          expect(component).to have_content bike.mnfg_name
          expect(component).to have_content "found"
          expect(component.css("a").first["href"]).to match("/bikes/#{bike.id}")
          expect(component).to have_content(l(impound_record.impounded_at, format: :convert_time))

          expect_serial_is_visible(component, bike.serial_number, skip_cache: true)
        end
      end
    end
  end

  context "unregistered_parking_notification" do
    let(:bike) { FactoryBot.create(:bike, :with_ownership, updated_at: Time.current - 2.hours, status: "unregistered_parking_notification") }

    it "renders without serial" do
      expect(bike.reload.status).to eq "unregistered_parking_notification"
      expect(component).to have_content bike.mnfg_name
      expect(component.css("a").first["href"]).to match("/bikes/#{bike.id}")

      expect_serial_is_hidden(component, bike.serial_number)
    end
  end

  context "with marketplace_record" do
    let!(:marketplace_listing) { FactoryBot.create(:marketplace_listing, :for_sale, status:) }
    let(:bike) { marketplace_listing.item }
    let(:status) { :draft }

    it "does not render marketplace_listing" do
      expect(marketplace_listing.reload.status).to eq "draft"
      expect(bike.reload.status).to eq "status_with_owner"
      expect(component).to have_content bike.mnfg_name
      expect(component).to_not have_content "for sale"
      expect(component.css("a").first["href"]).to match("/bikes/#{bike.id}")

      expect_serial_is_visible(component, bike.serial_number)
    end

    context "status for_sale" do
      let(:status) { :for_sale }
      it "renders marketplace_listing" do
        expect(marketplace_listing.reload.status).to eq "for_sale"
        expect(bike.reload.status).to eq "status_with_owner"
        expect(bike.current_event_record&.id).to eq marketplace_listing.id
        expect(component).to have_content bike.mnfg_name
        expect(component).to have_content "for sale"
        expect(component.css("a").first["href"]).to match("/bikes/#{bike.id}")
        expect(component).to have_content(l(marketplace_listing.published_at, format: :convert_time))
        expect(component).to have_content marketplace_listing.amount

        expect_serial_is_visible(component, bike.serial_number)
      end

      context "stolen_record" do
        let!(:stolen_record) { FactoryBot.create(:stolen_record, bike:) }
        it "does not render marketplace_listing" do
          expect(bike.reload.status).to eq "status_stolen"
          expect(bike.current_event_record&.id).to eq stolen_record.id
          expect(component).to have_content bike.mnfg_name
          expect(component).to have_content "stolen"
          expect(component.css("a").first["href"]).to match("/bikes/#{bike.id}")
          expect(component).to have_content(l(stolen_record.date_stolen, format: :convert_time))

          expect_serial_is_visible(component, bike.serial_number)
        end
      end
    end
  end
end
