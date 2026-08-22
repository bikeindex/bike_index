# frozen_string_literal: true

module ComponentStructs
  # The hashes the menus and the row components take, and the constructors for the menu ones —
  # UserServices::MenuItemsAccount and UserServices::MenuItemsOrg read alike because both build
  # their rows here.
  #
  # A menu item, rendered by PageBlock::Navbar::OrgSidebar, ::AccountMenu and
  # ::UserSettingsMenu, and served by api/v3/me:
  #   {type: :divider}
  #   {type: :group, key:, label:, icon:, children: [...]}
  #   {type: :link, label:, path:, icon:, match:, matching_controllers:, id:, data:, danger:}
  #   {type: :disabled, label:}
  #
  # A UI::Tabs tab, which Admin::Headers::Tabs passes through:
  #   {label:, href:, active:, count:, classes:} — count and classes are optional
  #
  # A UI::ButtonGroup entry:
  #   {label:, href:, active:, disabled:} — an entry without an href renders a <button>, and
  #   anything else in it (data:, title:, target:) becomes an attribute
  module Items
    extend Functionable

    # `match:` and `matching_controllers:` are UI::ActiveLink's, which resolves them in the
    # browser. Nothing here depends on which page is current.
    def link(label, path, icon: nil, match: :path, matching_controllers: [], **attributes)
      {type: :link, label:, path:, icon:, match:, matching_controllers:, **attributes}
    end

    # A group whose children are all gated off doesn't render at all. `key` is what the
    # Stimulus controller opens and closes.
    def group(key, label, icon, children)
      present = children.compact
      return nil if present.none? { |child| child[:type] == :link }

      {type: :group, key:, label:, icon:, children: present}
    end

    def disabled(label)
      {type: :disabled, label:}
    end

    def divider
      {type: :divider}
    end
  end
end
