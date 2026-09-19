# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin news images", :js, type: :system do
  let(:user) { FactoryBot.create(:superuser) }
  # Tags are required, so the form won't save without one
  let(:blog) { FactoryBot.create(:blog, content_tag_names: [FactoryBot.create(:content_tag).name]) }
  let!(:public_image) { FactoryBot.create(:public_image, imageable: blog, name: "Already here") }

  before do
    Organization.example # Logging in lands on the admin dashboard, which reads it from the replica
    sign_in(user)
  end

  it "uploads photos, makes one the primary image, and deletes another" do
    visit edit_admin_news_path(blog.title_slug)

    expect(page).to have_css("li[id^='image-']", count: 1)
    expect(page).to have_css("#image-#{public_image.id}", text: "Already here")

    # stored on its own - the blog's form isn't submitted
    expect {
      attach_file("Upload", Rails.root.join("spec/fixtures/bike.jpg").to_s, make_visible: true)

      expect(page).to have_css("li[id^='image-']", count: 2)
    }.to change(blog.public_images, :count).by(1)

    uploaded = blog.public_images.reorder(:id).last
    within("#image-#{uploaded.id}") do
      expect(page).to have_css("img[src='#{uploaded.image_url}']")
      # the markup to paste into the post body, which is the reason the images are listed here
      expect(page).to have_field(type: "textarea", with: /<img class="post-image" src="#{uploaded.image_url}"/)
    end
    # the row that stood in for it while it uploaded is gone
    expect(page).to have_no_css("[data-ui--forms--files--picker-target='status'] li")

    # An image's radio sits outside the blog's form, and still saves with it
    within("#image-#{uploaded.id}") { choose "primary image" }
    click_button "Save"

    expect(page).to have_content("Blog saved!")
    expect(blog.reload.index_image_id).to eq uploaded.id
    within("#image-#{uploaded.id}") { expect(page).to have_checked_field("primary image") }

    # one radio group across the form and the list, so choosing this clears the image's
    choose "No primary image"
    within("#image-#{uploaded.id}") { expect(page).to have_unchecked_field("primary image") }
    click_button "Save"

    expect(page).to have_content("Blog saved!")
    expect(blog.reload.index_image_id).to eq 0
    expect(page).to have_checked_field("No primary image")

    # the Save reloaded the page, and a click before the controller connects does nothing
    wait_for_stimulus("admin--public-image")
    expect {
      within("#image-#{public_image.id}") { click_button "delete" }

      expect(page).to have_no_css("#image-#{public_image.id}")
    }.to change(PublicImage, :count).by(-1)
  end
end
