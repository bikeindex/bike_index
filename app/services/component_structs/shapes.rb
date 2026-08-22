# frozen_string_literal: true

module ComponentStructs
  # The hashes the menus and the row components take, and the constructors for them — so
  # UserServices::MenuItemsAccount and UserServices::MenuItemsOrg read alike, and a caller
  # can't spell a shape a way the component doesn't read. Every constructor takes
  # **attributes, which is how a caller carries a key of its own through: the org sidebar
  # marks its super admin row, Admin::Organizations::Tabs tags each tab to filter on.
  #
  # A menu item, rendered by PageBlock::Navbar::OrgSidebar, ::AccountMenu and
  # ::UserSettingsMenu, and served by api/v3/me:
  #   {type: :divider}
  #   {type: :group, key:, label:, icon:, children: [...]}
  #   {type: :link, label:, path:, icon:, match_paths:, match_params:} — plus whatever the
  #     menu rendering it reads back: id:, data:, danger:, super_admin:
  #   {type: :disabled, label:}
  #
  # A UI::Tabs tab, which Admin::Headers::Tabs passes through:
  #   {label:, href:, active:, count:, classes:}
  #
  # A UI::ButtonGroup entry:
  #   {label:, href:, active:, disabled:} — anything else in it (data:, title:, target:)
  #   becomes an attribute on the chip
  module Shapes
    extend Functionable

    # `match_paths:` and `match_params:` are UI::ActiveLink's, which resolves them in the
    # browser. section: is the common case of match_paths: — the row covers everything
    # under its own path.
    def link(label, path, icon: nil, section: false, **attributes)
      covered = section ? {match_paths: "#{path}/**"} : {}
      {type: :link, label:, path:, icon:, **covered, **attributes}
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

    # count: renders beside the label, classes: adds to the tab's own
    def tab(label, href, active: false, count: nil, classes: nil, **attributes)
      {label:, href:, active:, count:, classes:, **attributes}
    end

    # An entry without an href renders a <button> rather than a link, so href: is where a
    # chip driven by a Stimulus action differs from one that navigates
    def entry(label, href: nil, active: false, disabled: false, **attributes)
      {label:, href:, active:, disabled:, **attributes}
    end

    def divider
      {type: :divider}
    end
  end
end
