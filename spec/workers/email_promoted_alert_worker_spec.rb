require 'rails_helper'

RSpec.describe EmailPromotedAlertWorker, type: :worker do
  let(:stolen_record) { FactoryBot.create(:stolen_record_recovered) }
  let(:ownership) { FactoryBot.create(:ownership) }
  let(:user) { ownership.creator }
  let(:bike) { ownership.bike }
  let!(:theft_alert) { FactoryBot.create(:theft_alert, stolen_record: stolen_record) }
  it "sends a promoted alert emails" do
    ActionMailer::Base.deliveries = []
    EmailPromotedAlertWorker.new.perform(theft_alert.id)
    expect(ActionMailer::Base.deliveries.empty?).to be_falsey
  end
end
