# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin news images", :js, type: :system do
  let(:user) { FactoryBot.create(:superuser) }
  let(:blog) { FactoryBot.create(:blog) }
  let!(:public_image) { FactoryBot.create(:public_image, imageable: blog, name: "Already here") }

  before do
    Organization.example # Logging in lands on the admin dashboard, which reads it from the replica
    visit new_session_path
    fill_in "Email", with: user.email
    click_button "Continue"
    fill_in "Password", with: "testthisthing7$"
    click_button "Log in"
  end

  # The upload stores the image on its own - the page's own form is never submitted here
  it "adds each uploaded photo to the images the blog already has, with the markup to embed it" do
    visit edit_admin_news_path(blog.title_slug)

    expect(page).to have_css("#public_images li", count: 1)
    expect(page).to have_css("#public_images li", text: "Already here")

    expect {
      attach_file("Upload", Rails.root.join("spec/fixtures/bike.jpg").to_s, make_visible: true)

      expect(page).to have_css("#public_images li", count: 2)
    }.to change(blog.public_images, :count).by(1)

    uploaded = blog.public_images.reorder(:id).last
    within("#image-#{uploaded.id}") do
      expect(page).to have_css("img[src='#{uploaded.image_url}']")
      # the markup to paste into the post body, which is the reason the images are listed here
      expect(page).to have_field(type: "textarea", with: /<img class="post-image" src="#{uploaded.image_url}"/)
      expect(page).to have_link("delete")
    end
    # the row that stood in for it while it uploaded is gone
    expect(page).to have_no_css("[data-ui--forms--file-upload-multi-target='status'] li")
  end
end
