# frozen_string_literal: true

require "rails_helper"

# Every public form that mails an address or creates a record renders this; a missing
# trap is invisible until the spam complaints arrive
RSpec.describe UI::Forms::Honeypot::Component, type: :component do
  let(:component) { render_inline(described_class.new) }

  it "hides the field from people, so only a bot fills it in" do
    expect(component).to have_css("div.tw\\:hidden > input", visible: :all)
    expect(component).to have_css("input[tabindex='-1'][autocomplete='off']", visible: :all)
    expect(component).to have_css("label", text: "Additional information", visible: :all)
  end

  # Renaming `additional` renders a trap nothing reads - the spam checks key on the string
  describe "the field name" do
    it "posts bare, for a top-level params[:additional]" do
      expect(component).to have_css("input[name='additional']", visible: :all)
    end

    context "with a form_builder" do
      let(:user) { User.new }
      let(:form_builder) do
        BikeIndexFormBuilder.new(:user, user, ActionView::Base.new(ActionView::LookupContext.new([]), {}, nil), {})
      end
      let(:component) { render_inline(described_class.new(form_builder:)) }

      it "scopes to the form's model" do
        expect(component).to have_css("input[name='user[additional]']", visible: :all)
        expect(User.new(additional: "filled").looks_like_spam?).to be_truthy
      end
    end
  end
end
