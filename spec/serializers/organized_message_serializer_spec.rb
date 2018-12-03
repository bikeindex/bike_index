require "spec_helper"

describe OrganizedMessageSerializer, type: :lib do
  let(:subject) { OrganizedMessageSerializer }
  let(:obj) { FactoryGirl.create(:organization_message) }
  let(:serializer) { subject.new(obj, root: false) }

  describe "caching" do
    include_context :caching_basic
    it "is cached" do
      expect(serializer.perform_caching).to be_truthy
      expect(serializer.as_json.is_a?(Hash)).to be_truthy
    end
  end
end
