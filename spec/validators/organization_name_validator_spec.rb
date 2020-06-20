require "rails_helper"

RSpec.describe OrganizationNameValidator do
  it "returns true for a name" do
    expect(OrganizationNameValidator.valid?("biking")).to be_truthy
  end

  describe "invalid names" do
    it { expect(OrganizationNameValidator.valid?("bike")).to be_falsey }

    it { expect(OrganizationNameValidator.valid?("b")).to be_falsey }

    it { expect(OrganizationNameValidator.valid?("bikes")).to be_falsey }

    it { expect(OrganizationNameValidator.valid?("bíkes")).to be_falsey }

    it { expect(OrganizationNameValidator.valid?("bikes")).to be_falsey }

    it { expect(OrganizationNameValidator.valid?("stores")).to be_falsey }

    it { expect(OrganizationNameValidator.valid?("400")).to be_falsey }
  end
end
