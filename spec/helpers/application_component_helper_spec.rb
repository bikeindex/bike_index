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

  describe "amount_display" do
    subject(:result) { helper.amount_display(payment, currency_name_suffix:) }

    let(:currency_name_suffix) { false }
    let(:payment) { Payment.new(amount_cents: 150000) }
    let(:basic_target) { "<span><span title=\"USD\">$</span><span class=\"\">1,500</span></span>" }
    before do
      helper.extend(ControllerHelpers)
      allow(view).to receive(:current_currency) { Currency.default }
    end

    it "displays amount with currency symbol" do
      expect(result).to eq basic_target
    end

    context "with currency_name_suffix: true" do
      let(:currency_name_suffix) { true }

      it "includes currency name" do
        expect(result).to eq '<span><span title="USD">$</span><span class="">1,500</span><span class="tw:text-[66%]"> USD</span></span>'

        expect(helper.amount_display(payment, currency_name_suffix: :if_not_default)).to eq basic_target
      end
    end

    context "with different currency" do
      let(:payment) { Payment.new(amount_cents: 25000, currency: "EUR") }
      let(:currency_name_suffix) { true }
      let(:target) { '<span><span title="EUR">€</span><span class="">250</span><span class="tw:text-[66%]"> EUR</span></span>' }

      it "displays the correct currency" do
        expect(result).to eq target
        expect(helper.amount_display(payment, currency_name_suffix: :if_not_default)).to eq target
      end
    end

    context "with zero amount" do
      let(:payment) { Payment.new(amount_cents: 0) }

      it "applies less-less-strong class to zero" do
        expect(result).to eq '<span><span title="USD">$</span><span class="less-less-strong">0</span></span>'
      end
    end

    context "with nil amount" do
      let(:payment) { Payment.new(amount_cents: nil) }

      it "applies less-less-strong class to zero" do
        expect(result).to be_nil
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
    context "error version" do
      let(:target) { "" }
      it "doesn't error" do
        expect(phone_link("+1", class: "phone-number-link")).to eq target
      end
    end
  end
end
