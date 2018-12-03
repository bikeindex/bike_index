require 'spec_helper'

describe CtypeSerializer, type: :lib do
  let(:ctype) { FactoryGirl.create(:ctype, has_multiple: true) }
  let(:serializer) { CtypeSerializer.new(ctype) }

  it "is as expected" do
    expect(serializer.name).to eq(ctype.name)
    expect(serializer.slug).to eq(ctype.slug)
    expect(serializer.has_multiple).to be_truthy
  end
end