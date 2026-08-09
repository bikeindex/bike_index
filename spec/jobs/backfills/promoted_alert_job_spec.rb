require "rails_helper"

RSpec.describe Backfills::PromotedAlertJob, type: :job do
  let(:instance) { described_class.new }
  let(:stolen_record) { FactoryBot.create(:stolen_record, :in_vancouver) }
  let!(:theft_alert) do
    FactoryBot.create(:theft_alert_begun, stolen_record:, notes: "some notes",
      facebook_data: {campaign_id: "xxx"}, reach: 42, created_at: Time.current - 2.years)
  end

  def new_promoted_alert
    PromotedAlert.create!(stolen_record:, theft_alert_plan: theft_alert.theft_alert_plan,
      user: theft_alert.user)
  end

  it "copies every column, ids and timestamps included" do
    expect { instance.perform }.to change(PromotedAlert, :count).by(1)

    promoted_alert = PromotedAlert.last
    theft_alert.reload
    expect(promoted_alert.id).to eq theft_alert.id
    expect(promoted_alert.created_at).to eq theft_alert.created_at
    expect(promoted_alert.updated_at).to eq theft_alert.updated_at
    TheftAlert.column_names.each do |column|
      expect(promoted_alert.send(column)).to eq(theft_alert.send(column)), "#{column} doesn't match"
    end
  end

  it "leaves room in the sequence for the copied ids" do
    instance.perform

    expect(new_promoted_alert.id).to be > theft_alert.id
  end

  context "with the sequence parked past the theft alerts, as CreatePromotedAlerts leaves it" do
    let(:parked_at) { theft_alert.id + 10_000 }
    before { PromotedAlert.connection.execute("SELECT setval('promoted_alerts_id_seq', #{parked_at}, false)") }

    it "copies without colliding, and doesn't wind the sequence back" do
      instance.perform

      expect(PromotedAlert.find(theft_alert.id)).to be_present
      expect(new_promoted_alert.id).to eq parked_at
    end
  end

  it "doesn't duplicate on a second run" do
    instance.perform
    expect { instance.perform }.to_not change(PromotedAlert, :count)
  end

  context "with polymorphic references" do
    let!(:notification) do
      FactoryBot.create(:notification, kind: "theft_alert_posted", notifiable: theft_alert,
        user: theft_alert.user)
    end
    let!(:user_alert) do
      FactoryBot.create(:user_alert, kind: "theft_alert_without_photo", alertable: theft_alert,
        user: theft_alert.user)
    end

    it "repoints them at the promoted alert" do
      instance.perform

      promoted_alert = PromotedAlert.find(theft_alert.id)
      expect(notification.reload.notifiable).to eq promoted_alert
      expect(user_alert.reload.alertable).to eq promoted_alert
      expect(promoted_alert.notifications.pluck(:id)).to eq([notification.id])
    end
  end
end
