# frozen_string_literal: true

require "rails_helper"

RSpec.describe Form::FileUpload::Component, :js, type: :system do
  let(:base_path) { "/rails/view_components/form/file_upload/component/" }

  context "default" do
    it "shows the selected filename in the field" do
      visit("#{base_path}default")

      expect(page).to have_css("[data-form--file-upload-target='filename']", text: "No file chosen")

      attach_file("file", Rails.root.join("spec/fixtures/bike.jpg").to_s, make_visible: true)

      expect(page).to have_css("[data-form--file-upload-target='filename']", text: "bike.jpg")
    end
  end
end
