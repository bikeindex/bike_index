# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::DragHandle::Component, :js, type: :system do
  def item_order = all("[data-sortable-target='item'] span:last-child").map(&:text)

  it "moves its row by dragging, or a place at a time by its arrow keys" do
    visit "/rails/view_components/ui/drag_handle/component/default"
    expect(item_order).to eq ["First item", "Second item", "Third item"]
    expect_axe_clean
    # The status a move is announced in, there once a handle has focus rather than added by the move
    send_keys(:tab)
    expect(page).to have_css("#drag-handle-status:empty", visible: :all)

    find("[aria-label='Move Third item']").drag_to(find("[data-sortable-target='item']", text: "First item"))
    expect(item_order).to eq ["Third item", "First item", "Second item"]

    find("[aria-label='Move First item']").send_keys(:up)
    expect(item_order).to eq ["First item", "Third item", "Second item"]
    expect(page).to have_css("#drag-handle-status", text: "Position 1 of 3", visible: :all)
    # Still on the handle, and the top row goes no higher
    send_keys(:up, :down, :down)
    expect(item_order).to eq ["Third item", "Second item", "First item"]
    expect(page).to have_css("#drag-handle-status", text: "Position 3 of 3", visible: :all)
  end
end
