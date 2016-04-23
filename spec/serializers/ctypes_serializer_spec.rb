require 'spec_helper'

describe CtypeSerializer do
  let(:ctype) { FactoryGirl.create(:ctype, has_multiple: true) }
  subject { CtypeSerializer.new(ctype) }

  it { expect(subject.name).to eq(ctype.name) }
  it { expect(subject.slug).to eq(ctype.slug) }
  it { expect(subject.has_multiple).to be_truthy }
end
