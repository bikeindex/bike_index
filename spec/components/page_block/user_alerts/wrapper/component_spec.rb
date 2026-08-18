# frozen_string_literal: true

require "rails_helper"

RSpec.describe PageBlock::UserAlerts::Wrapper::Component, type: :component do
  let(:component) { described_class.new(current_user: user) }
  let(:user) { FactoryBot.create(:user_confirmed) }

  it "doesn't render without a user, or without an alert" do
    expect(described_class.new(current_user: nil).render?).to be_falsey
    expect(component.render?).to be_falsey
  end

  # The wrapper switches on general_kinds, so a kind there with no component renders nothing
  it "has a component, a preview scenario and a spec for every kind of alert" do
    # The rest of the directory is the chrome the alerts share
    alert_names = Rails.root.glob("app/components/page_block/user_alerts/*").select(&:directory?)
      .map { |dir| dir.basename.to_s }.sort - %w[bike_list_modal wrapper]
    scenarios = PageBlock::UserAlerts::Wrapper::ComponentPreview.public_instance_methods(false).map(&:to_s)

    expect(alert_names).to eq UserAlert.general_kinds.sort
    alert_names.each do |alert|
      expect(scenarios).to include(alert), "UserAlerts::#{alert.camelize} has no preview scenario"
      spec = Rails.root.join("spec/components/page_block/user_alerts/#{alert}/component_spec.rb")
      expect(spec.exist?).to be_truthy, "UserAlerts::#{alert.camelize} has no component spec"
    end
  end

  context "with stolen_bike_without_location" do
    let!(:bike) { FactoryBot.create(:stolen_bike, :with_ownership_claimed, user:) }
    let(:alert_slugs) { ["stolen_bike_without_location"] }

    before { user.update(alert_slugs:) }

    it "renders the location modal" do
      expect(render_inline(component).text).to include("Please add theft location")
    end

    context "with a street" do
      before { bike.current_stolen_record.update(street: "278 Broadway", skip_geocoding: true) }

      # The kind is chosen off the slug, so a stale slug renders nothing rather than
      # falling through to the next kind
      it "doesn't render" do
        expect(render_inline(component).text.strip).to eq ""
      end
    end

    context "with theft_alert_without_photo too" do
      let(:alert_slugs) { %w[theft_alert_without_photo stolen_bike_without_location] }

      it "renders the higher priority location modal" do
        expect(render_inline(component).text).to include("Please add theft location")
      end
    end
  end

  context "with theft_alert_without_photo" do
    let!(:bike) { FactoryBot.create(:stolen_bike, :with_ownership_claimed, user:) }
    let!(:theft_alert) { FactoryBot.create(:theft_alert, stolen_record: bike.current_stolen_record, user:) }

    before { user.update(alert_slugs: ["theft_alert_without_photo"]) }

    it "renders the photo modal" do
      expect(render_inline(component).text).to include("Please add a photo")
    end
  end

  context "with unfinished_registration" do
    let!(:b_param) { FactoryBot.create(:b_param_unfinished_registration, creator: user) }

    # The b_param's own callback puts the alert on the user, so nothing else has to run
    it "renders the resume link" do
      expect(user.reload.alert_slugs).to eq ["unfinished_registration"]
      expect(render_inline(component).text).to include("Your cargo bike isn't registered yet!")
    end

    context "with a stolen bike missing its location too" do
      let!(:bike) { FactoryBot.create(:stolen_bike, :with_ownership_claimed, user:) }

      before { user.update(alert_slugs: %w[stolen_bike_without_location unfinished_registration]) }

      it "renders the higher priority location modal" do
        expect(render_inline(component).text).to include("Please add theft location")
      end
    end

    context "once the bike is created" do
      before { b_param.update(created_bike_id: FactoryBot.create(:bike).id) }

      it "renders nothing" do
        expect(render_inline(component).text.strip).to eq ""
      end
    end
  end

  context "with phone_waiting_confirmation" do
    let!(:user_phone) { FactoryBot.create(:user_phone, user:) }

    before do
      Flipper.enable(:phone_verification)
      user.update(alert_slugs: %w[phone_waiting_confirmation stolen_bike_without_location])
    end

    it "renders the phone confirmation prompt" do
      expect(render_inline(component).text).to include("Confirm your phone number")
    end

    context "with phone_verification disabled" do
      let!(:bike) { FactoryBot.create(:stolen_bike, :with_ownership_claimed, user:) }

      before { Flipper.disable(:phone_verification) }

      it "renders the next alert instead" do
        expect(render_inline(component).text).to include("Please add theft location")
      end
    end

    context "with the phone already confirmed" do
      let!(:user_phone) { FactoryBot.create(:user_phone_confirmed, user:) }

      it "renders nothing and enqueues an update to clear the stale slug" do
        expect { expect(render_inline(component).text.strip).to eq "" }
          .to change(CallbackJobs::AfterUserChangeJob.jobs, :count).by 1
      end
    end
  end
end
