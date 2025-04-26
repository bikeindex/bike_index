# frozen_string_literal: true

require "rails_helper"

RSpec.describe LegacyFormWell::AddressRecordWithDefault::Component, type: :component do
  let(:user) { FactoryBot.create(:user) }
  let(:address_record) { }
  let(:organization) { nil }
  let(:options) { {form_builder:, organization:, no_street: user.no_address?} }
  let(:bike) { FactoryBot.create(:bike, :with_ownership, user:) }
  let(:marketplace_listing) { MarketplaceListing.find_or_build_current_for(bike) }

  def rendered_component(passed_bike, passed_user)
    render_in_view_context do
      form_with(model: passed_bike, multipart: true, html: { class: 'primary-edit-bike-form' }) do |f|
        f.fields_for :current_marketplace_listing do |ml|
          ml.fields_for :address_record do |address_form|
            # Here we provide the form_builder to the component
            render(LegacyFormWell::AddressRecordWithDefault::Component.new(
              form_builder: address_form,
              user: passed_user
            ))
          end
        end
      end
    end
  end

  before do
    FactoryBot.create(:state_california)
    Country.united_states
    user.update(address_record:) if address_record.present?
    bike.current_marketplace_listing = marketplace_listing
  end

  let(:component) { rendered_component(bike, user) }

  it "does not show user_account_address" do
    expect(user.reload.address_record).to be_blank

    expect(component).to_not have_text("Use account address")
  end

  context "with user address" do
    let!(:address_record) { FactoryBot.create(:address_record, user:, kind: :user) }

    it "use account address is checked" do
      expect(user.reload.address_record).to be_present
      expect(marketplace_listing.address_record.user_account_address).to be_truthy

      expect(component).to have_text("Use account address")
      expect(page).to have_checked_field("bike[current_marketplace_listing_attributes][address_record_attributes][user_account_address]")
    end

    context "marketplace_listing address" do
      let(:marketplace_listing) { FactoryBot.create(:marketplace_listing, item: bike, address_record: listing_address_record) }
      let(:listing_address_record) { address_record }

      it "user_account_address is checked when address record is user record" do
        expect(user.reload.address_record).to be_present
        expect(marketplace_listing.address_record.user_account_address).to be_truthy

        expect(component).to have_text("Use account address")
        expect(page).to have_checked_field("bike[current_marketplace_listing_attributes][address_record_attributes][user_account_address]")
      end

      context "non-user address record" do
        let(:listing_address_record) { FactoryBot.create(:address_record, kind: :marketplace_listing, user:) }

        it "user_account_address is unchecked when address record different" do
          expect(user.reload.address_record).to be_present
          expect(marketplace_listing.address_record.user_account_address).to be_falsey

          expect(component).to have_text("Use account address")
          expect(page).to_not have_checked_field("bike[current_marketplace_listing_attributes][address_record_attributes][user_account_address]")
        end
      end
    end
  end
end
