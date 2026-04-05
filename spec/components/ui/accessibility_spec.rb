# frozen_string_literal: true

require "rails_helper"

RSpec.describe "UI component accessibility", :js, type: :system do
  let(:preview_base) { "/rails/view_components" }

  {
    "alert notice" => "ui/alert/component/notice",
    "alert error" => "ui/alert/component/error",
    "badge notice_sm" => "ui/badge/component/notice_sm",
    "button primary" => "ui/button/component/primary",
    "button secondary" => "ui/button/component/secondary",
    "button_link primary" => "ui/button_link/component/primary",
    "header h1" => "ui/header/component/h1",
    "dropdown default" => "ui/dropdown/component/default",
    "modal default" => "ui/modal/component/default"
  }.each do |name, path|
    it "#{name} is accessible" do
      visit("#{preview_base}/#{path}")
      # Skip page-level rules that come from the component preview layout, not from the components
      expect(page).to be_axe_clean.skipping(:"html-has-lang", :"landmark-one-main", :"page-has-heading-one", :region)
    end
  end
end
