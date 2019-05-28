require "spec_helper"

describe Cgroup do
  it_behaves_like "friendly_slug_findable"

  describe "additional_parts" do
    it "finds additional parts" do
      expect(Cgroup.additional_parts.name).to eq "Additional parts"
    end
  end
end
