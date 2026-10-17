import { html } from 'lit-html'
import { tabs } from 'bikebook/templates/ui/tabs'

export const VIEWS = { basics: 'Overview', geometry: 'Sizes & geometry', components: 'Components', motors: 'Motor & Battery', all: 'All' }

// what an in-place link focuses once it renders, keeping the reader's place in the tabs
export const CURRENT_VIEW = '#vehicle-views [aria-current]'

// The `views` of what's picked, each a link to this page with it, which replaces the history entry rather than adding
// one, and `search`, a { label, href } for a tab that shows the search a lone model hides. data-in-place and
// data-replace sit on the wrapper because UI::Tabs takes no attributes per tab
// Out to the window's edges, as the views' cards are
export const jumpTo = (current, path, views, search = null) => html`<div id="vehicle-views" class="tw:mx-[calc(50%-50vw)] tw:w-screen tw:px-4"
  data-in-place=${CURRENT_VIEW} data-replace>${tabs({
  navLabel: 'Views',
  marginClasses: 'tw:mt-2',
  tabs: [...views.map((view) => ({ label: VIEWS[view], href: path(view), active: view === current })), ...(search ? [search] : [])]
})}</div>`
