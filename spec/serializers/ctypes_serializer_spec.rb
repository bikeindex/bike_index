require "rails_helper"

RSpec.describe CtypeSerializer, type: :lib do
  let(:subject) { described_class }
  let(:obj) { FactoryBot.create(:ctype, has_multiple: true) }
  let(:serializer) { subject.new(obj, root: false) }

  it "is as expected" do
    expect(serializer.name).to eq(obj.name)
    expect(serializer.slug).to eq(obj.slug)
    expect(serializer.has_multiple).to be_truthy
    expect(serializer.as_json.is_a?(Hash)).to be_truthy
  end
end
