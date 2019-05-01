require "spec_helper"

describe OrganizedMessageSerializer, type: :lib do
  let(:subject) { OrganizedMessageSerializer }
  let(:obj) { FactoryBot.create(:organization_message) }
  let(:serializer) { subject.new(obj, root: false) }

  it "works" do
    expect(serializer.as_json.is_a?(Hash)).to be_truthy
  end
end
