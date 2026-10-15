import { html } from 'lit-html'
import { tabs } from 'bikebook/templates/ui/tabs'

export const VIEWS = { basics: 'Overview', geometry: 'Sizes & geometry', components: 'Components', motors: 'Motor & Battery', all: 'All' }

// what an in-place link focuses once it renders, keeping the reader's place in the tabs
export const CURRENT_VIEW = '#vehicle-views [aria-current]'

// The `views` of what's picked, each a link to this page with it. data-in-place sits on the wrapper because
// UI::Tabs takes no attributes per tab
export const jumpTo = (current, path, views) => html`<div id="vehicle-views" data-in-place=${CURRENT_VIEW}>${tabs({
  navLabel: 'Views',
  marginClasses: 'tw:mt-2',
  tabs: views.map((view) => ({ label: VIEWS[view], href: path(view), active: view === current }))
})}</div>`
