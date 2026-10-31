# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Admin::Users::Show::Component, type: :component do
  let(:user) { FactoryBot.create(:user_confirmed) }
  let(:active_tab) { :ambassador_tasks }
  let(:component) { render_inline(described_class.new(user:, active_tab:)) }

  it "says when the user isn't an ambassador" do
    expect(component).to have_content("Not an ambassador")
  end

  # Those tabs are the filtered admin index, which renders the header itself
  context "with a tab that has an index" do
    let(:active_tab) { :bikes }

    it "raises" do
      expect { component }.to raise_error(ArgumentError, /bikes/)
    end
  end
end
