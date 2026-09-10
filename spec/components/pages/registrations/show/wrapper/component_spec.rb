# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Registrations::Show::Wrapper::Component, type: :component do
  # The whole show tree renders inside this component's cache block
  it_behaves_like "cached_markup_digest"

  let(:bike) { FactoryBot.create(:bike, :with_ownership, owner_email: "new-owner@example.com") }
  let(:current_user) { bike.reload.current_ownership.creator }

  def cache_key(user: current_user, view: [:owner, nil])
    described_class.new(bike: bike.reload, current_user: user, view:, available_views: []).cache_key
  end

  # Claiming writes the ownership, and Ownership touches the bike so this expires
  describe "#cache_key" do
    it "changes when the new owner claims the bike" do
      expect { bike.current_ownership.mark_claimed }.to change { cache_key }
    end

    # The claim-impound card renders the viewer's own claim inside the cached body, and
    # it's only ever offered to somebody who isn't the owner
    it "changes when the viewer edits their impound claim" do
      claimant = FactoryBot.create(:user_confirmed)
      impound_record = FactoryBot.create(:impound_record, bike:)
      impound_claim = FactoryBot.create(:impound_claim, impound_record:, user: claimant)

      expect { impound_claim.update(message: "it has my sticker on it") }
        .to change { cache_key(user: claimant, view: [:public, nil]) }
    end

    # The alert renders the prompt inside the cached body, token and all, so two
    # notifications on one bike must not share an entry — they're the same component
    it "tells two notifications on the same bike apart" do
      first = FactoryBot.create(:parking_notification, bike:)
      second = FactoryBot.create(:parking_notification, bike:, retrieval_link_token: "another-token")
      keys = [first, second].map do |notification|
        alerts = {token: notification.retrieval_link_token,
                  token_type: notification.kind, matching_notification: notification}
        described_class.new(bike: bike.reload, current_user:, view: [:owner, nil],
          available_views: [], current_alerts: alerts).cache_key
      end

      expect(keys.first).to_not eq keys.last
    end

    # The recovery form's default and max are read off the clock into that same cached
    # alert, so an entry written yesterday must not be served with yesterday's max
    it "carries the recovery prompt's clock-derived bounds" do
      stolen_bike = FactoryBot.create(:stolen_bike, :with_ownership_claimed)
      alerts = {recovered_stolen_record: stolen_bike.current_stolen_record}
      key = described_class.new(bike: stolen_bike, current_user: nil, view: [:public, nil],
        available_views: [], current_alerts: alerts).cache_key

      expect(key.flatten).to include(Binxtils::TimeParser.round(Time.current), Time.current.end_of_day)
    end
  end

  # What the preview resolves isn't reliably greppable out of the page it renders, so
  # these check the component it built
  describe "ComponentPreview" do
    let(:preview) { Pages::Registrations::Show::Wrapper::ComponentPreview.new }
    let!(:organization) { FactoryBot.create(:organization_brakebills) }
    let!(:organized_bike) { FactoryBot.create(:bike_organized, :with_ownership_claimed, creation_organization: organization) }

    def built_component(rendered) = rendered.dig(:locals, :component)

    # The recipient usually has no account yet, so the page behind it is the public one
    it "renders the signed-out claim invitation over the public view" do
      component = built_component(preview.claim_invitation_signed_out)

      expect(component.instance_variable_get(:@current_user)).to be_nil
      expect(component.instance_variable_get(:@view)).to eq [:public, nil]
    end

    it "renders the bike named by bike_id, through the view the select names" do
      staff = FactoryBot.create(:organization_admin, organization:)
      stub_const("ENV", ENV.to_hash.merge("LOOKBOOK_USER_ID" => staff.id.to_s))

      component = built_component(preview.no_overlay(view: "org_admin", bike_id: organized_bike.id))

      expect(component.instance_variable_get(:@bike)).to eq organized_bike
      expect(component.instance_variable_get(:@view)).to eq [:staff, organization]
    end

    # ShowViews decides what the viewer may see, so an unentitled view falls back rather
    # than rendering a page the app never serves
    it "falls back to public when the lookbook user has no claim on the org" do
      stub_const("ENV", ENV.to_hash.merge("LOOKBOOK_USER_ID" => FactoryBot.create(:user_confirmed).id.to_s))

      component = built_component(preview.no_overlay(view: "org_admin"))

      expect(component.instance_variable_get(:@view)).to eq [:public, nil]
    end

    # Lookbook is mounted in production, where the bikes would be real people's
    it "renders a notice rather than the registration in production" do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("production"))

      rendered = preview.no_overlay

      expect(rendered[:component]).to be_a(UI::Alerts::Base::Component)
      expect(rendered[:component].instance_variable_get(:@text)).to match("disabled in production")
    end
  end
end
