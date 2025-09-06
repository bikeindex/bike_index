# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApplicationComponentHelper, type: :helper do
  describe "number_display" do
    subject(:result) { helper.number_display(number) }

    context "with large number" do
      let(:number) { 1234 }

      it "formats numbers with delimiter" do
        expect(result).to eq '<span class="">1,234</span>'
      end
    end

    context "with zero value" do
      let(:number) { 0 }

      it "applies less-less-strong class" do
        expect(result).to eq '<span class="less-less-strong">0</span>'
      end
    end

    context "with non-zero value" do
      let(:number) { 42 }

      it "does not apply class" do
        expect(result).to eq '<span class="">42</span>'
      end
    end

    context "with negative number" do
      let(:number) { -100 }

      it "handles negative numbers" do
        expect(result).to eq '<span class="">-100</span>'
      end
    end
  end

  describe "phone_link and phone_display" do
    it "displays phone with an area code and country code" do
      expect(phone_display("999 999 9999")).to eq("999-999-9999")
      expect(phone_display("+91 8041505583")).to eq("+91-804-150-5583")
    end
    context "no phone" do
      it "returns empty string if empty" do
        expect(phone_link(nil, class: "phone-number-link")).to eq ""
      end
    end
    context "with extension" do
      let(:target) { '<a href="tel:+11-121-1111 ; 2929222">+11-121-1111 x 2929222</a>' }
      it "returns link" do
        expect(phone_display("+11 1211111 x2929222")).to eq "+11-121-1111 x 2929222"
        expect(phone_link("+11 121 1111 x2929222")).to eq target
      end
    end
    context "passed class" do
      let(:target) { '<a class="phone-number-link" href="tel:777-777-7777 ; 2929222">777-777-7777 x 2929222</a>' }
      it "has class" do
        expect(phone_display("777 777 7777 ext. 2929222")).to eq "777-777-7777 x 2929222"
        expect(phone_link("777 777 7777 ext. 2929222", class: "phone-number-link")).to eq target
      end
    end
  end
end
