require "rails_helper"

RSpec.describe DeactivateExpiredTheftAlertWorker, type: :job do
  let(:instance) { described_class.new }
  include_context :scheduled_worker
  include_examples :scheduled_worker_tests

  describe "#perform" do
    it "deactivates expired theft alerts" do
      active = FactoryBot.create_list(:theft_alert_begun, 2)
      expired = FactoryBot.create_list(:theft_alert_begun, 2,
                                       begin_at: Time.current - 2.days,
                                       end_at: Time.current - 1.day)
      expect(TheftAlert.active.count).to eq(4)
      expect(TheftAlert.inactive.count).to eq(0)

      described_class.new.perform

      expect(TheftAlert.active.pluck(:id)).to eq(active.map(&:id))
      expect(TheftAlert.inactive.pluck(:id)).to eq(expired.map(&:id))
    end
  end
end
