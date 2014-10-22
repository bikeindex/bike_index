require "spec_helper"

describe CtypeSerializer do
  let(:ctype) { FactoryGirl.create(:ctype, has_multiple: true) }
  subject { CtypeSerializer.new(ctype) }
  
  it { subject.name.should == ctype.name }
  it { subject.slug.should == ctype.slug }
  it { subject.has_multiple.should be_true }
end
