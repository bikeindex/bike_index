require "rails_helper"

RSpec.shared_examples "bike_attributable" do
  let(:model_sym) { subject.class.name.underscore.to_sym }
  let(:instance) { FactoryBot.create model_sym }

  describe "frame_colors" do
    it "returns an array of the frame colors" do
      black = Color.new(name: "Black")
      blue = Color.new(name: "Blue")
      obj = subject.class.new(primary_frame_color: blue, secondary_frame_color: black)
      expect(obj.frame_colors).to eq(%w[Blue Black])
    end
  end
end
