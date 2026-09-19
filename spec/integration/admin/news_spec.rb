# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin news", :js, type: :system do
  let(:superuser) { FactoryBot.create(:superuser) }
  let(:blog) { FactoryBot.create(:blog, title: "Untagged post") }

  before do
    Organization.example # Read replica
    %w[Partners Theft\ prevention].each { FactoryBot.create(:content_tag, name: it) }
    sign_in(superuser)
  end

  # The tags multiselect is required, which the browser enforces only while nothing is picked
  it "requires a tag, and saves the ones picked" do
    visit "/admin/news/#{blog.to_param}/edit"
    expect(page).to have_css('#blog_content_tag_names[aria-expanded="false"]', wait: 10)

    click_button "Save"
    expect(find_field("blog_content_tag_names")[:validationMessage]).to be_present
    expect(blog.reload.content_tag_names).to eq([])

    find_field("blog_content_tag_names").click
    find('[role="option"]', text: "Partners").click
    find('[role="option"]', text: "Theft prevention").click
    find('[aria-label="Remove Partners"]').click
    send_keys(:escape)

    click_button "Save"
    expect(page).to have_css("[data-hw-combobox-chip]", text: "Theft prevention", wait: 10)
    expect(blog.reload.content_tag_names).to eq(["Theft prevention"])
  end
end
