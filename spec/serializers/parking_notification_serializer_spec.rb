require "rails_helper"

RSpec.describe ParkingNotificationSerializer, type: :lib do
  let(:subject) { described_class }
  let(:obj) { FactoryBot.create(:parking_notification) }
  let(:serializer) { subject.new(obj, root: false) }

  it "works" do
    expect(serializer.as_json.is_a?(Hash)).to be_truthy
  end
end
