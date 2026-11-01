import { html, nothing } from 'lit-html'
import { inlineBadge } from 'bikebook/templates/ui/badge'

// A gray "frame only" badge after a model's name where it isn't complete, by the kit's `names` of its configurations
export const configurationNote = ({ configuration, names = {}, size = 'sm' }) => configuration && configuration !== 'complete'
  ? html` ${inlineBadge({ text: (names[configuration] ?? configuration).toLowerCase(), size })}`
  : nothing
