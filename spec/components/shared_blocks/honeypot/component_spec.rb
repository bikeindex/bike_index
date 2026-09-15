# frozen_string_literal: true

require "rails_helper"

# Every public form that mails an address or creates a record renders this. A missing
# trap is invisible until the spam complaints arrive, so the coverage here is the
# contract each of those forms is relying on.
RSpec.describe SharedBlocks::Honeypot::Component, type: :component do
  let(:component) { render_inline(described_class.new) }

  it "hides the field from people, so only a bot fills it in" do
    expect(component).to have_css("div.tw\\:hidden > input", visible: :all)
    # Out of the tab order, and nothing the browser would autofill on a rider's behalf
    expect(component).to have_css("input[tabindex='-1'][autocomplete='off']", visible: :all)
    expect(component).to have_css("label", text: "Additional information", visible: :all)
  end

  # `additional` is a wire contract, not a style choice - User#looks_like_spam?,
  # Feedback#looks_like_spam? and BikeServices::Register all key on that exact string,
  # and users_controller and feedbacks_controller permit it by name. Renaming it here
  # renders a trap nothing reads, which no spec on those forms would catch
  describe "the field name" do
    it "posts as `additional` without a form_builder, for a top-level params[:additional]" do
      expect(component).to have_css("input[name='additional']", visible: :all)
    end

    context "with a form_builder" do
      let(:user) { User.new }
      let(:form_builder) do
        BikeIndexFormBuilder.new(:user, user, ActionView::Base.new(ActionView::LookupContext.new([]), {}, nil), {})
      end
      let(:component) { render_inline(described_class.new(form_builder:)) }

      it "scopes to the form's model, for the models carrying attr_accessor :additional" do
        expect(component).to have_css("input[name='user[additional]']", visible: :all)
        expect(User.new(additional: "filled").looks_like_spam?).to be_truthy
      end
    end
  end
end
