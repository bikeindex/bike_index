# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApplicationComponentHelper, type: :helper do
  describe "number_display" do
    it "formats numbers with delimiter" do
      result = helper.number_display(1234)
      expect(result).to eq '<span class="">1,234</span>'
    end

    it "applies less-less-strong class for zero values" do
      result = helper.number_display(0)
      expect(result).to eq '<span class="less-less-strong">0</span>'
    end

    it "does not apply class for non-zero values" do
      result = helper.number_display(42)
      expect(result).to eq '<span class="">42</span>'
    end

    it "handles negative numbers" do
      result = helper.number_display(-100)
      expect(result).to eq '<span class="">-100</span>'
    end
  end
end
