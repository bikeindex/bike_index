import { html, nothing } from 'lit-html'

const present = (data) => data != null && Object.keys(data).length > 0

// UI::JsonDisplay::Component without the width options the browser doesn't render
export const jsonDisplay = ({ data, small = false, noMaxHeight = false }) => present(data)
  ? html`<div class="highlightjs-json ${small ? 'tw:text-xs' : ''}" data-controller="ui--json-display"><pre
    class=${noMaxHeight ? nothing : 'tw:max-h-72'}><code class="language-json">${JSON.stringify(data, null, 2)}</code></pre></div>`
  : nothing
