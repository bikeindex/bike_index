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

    context "with current_currency CAD" do
      let(:payment) { Payment.new(amount_cents: 25000, currency: "CAD") }
      let(:target) { '<span><span title="CAD">$</span><span class="">250</span></span>' }
      before { allow(view).to receive(:current_currency) { Currency.new(:cad) } }

      it "suppresses the suffix when :if_not_default matches current_currency" do
        expect(helper.amount_display(payment, currency_name_suffix: :if_not_default)).to eq target
      end

      context "with USD payment" do
        let(:payment) { Payment.new(amount_cents: 150000) }
        let(:target) { '<span><span title="USD">$</span><span class="">1,500</span><span class="tw:text-[66%]"> USD</span></span>' }

        it "renders the suffix when payment currency differs from current_currency" do
          expect(helper.amount_display(payment, currency_name_suffix: :if_not_default)).to eq target
        end
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
end
