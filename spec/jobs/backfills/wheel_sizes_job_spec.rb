require "rails_helper"

RSpec.describe Backfills::WheelSizesJob, type: :job do
  let(:instance) { described_class.new }

  describe "perform" do
    let!(:wheel_size) { FactoryBot.create(:wheel_size, iso_bsd: 356, name: "14in", priority: :standard) }

    it "creates the new sizes, updates an existing one by iso_bsd, and is idempotent" do
      expect { instance.perform }.to change(WheelSize, :count).by 6
      expect(wheel_size.reload).to have_attributes(name: "14in moto", priority: "uncommon")

      expect { instance.perform }.not_to change(WheelSize, :count)
    end
  end
end
