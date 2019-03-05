require 'spec_helper'

describe FrameMaterial do
  describe "name" do
    let(:enum) { :organic }
    subject { FrameMaterial.new(enum) }

    it "returns the normalized enum name" do
      expect(subject.name).to eq(FrameMaterial::NAMES[enum])
    end
  end
end