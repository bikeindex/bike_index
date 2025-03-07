require "rails_helper"

RSpec.describe StolenBike::DeactivateExpiredTheftAlertJob, type: :job do
  include_context :scheduled_job
  include_examples :scheduled_job_tests

  describe "#perform" do
    it "deactivates expired theft alerts" do
      active = FactoryBot.create_list(:theft_alert_begun, 2)
      expired = FactoryBot.create_list(:theft_alert_begun, 2,
        start_at: Time.current - 2.days,
        end_at: Time.current - 1.day)
      expect(TheftAlert.active.count).to eq(4)
      expect(TheftAlert.inactive.count).to eq(0)

      described_class.new.perform

      expect(TheftAlert.active.pluck(:id)).to eq(active.map(&:id))
      expect(TheftAlert.inactive.pluck(:id)).to eq(expired.map(&:id))
    end
  end
end
