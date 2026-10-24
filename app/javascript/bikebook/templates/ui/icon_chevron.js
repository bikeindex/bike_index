import { chevronRight } from 'bikebook/templates/icons'

const ROTATIONS = { right: '', down: ' tw:rotate-90', left: ' tw:rotate-180', up: ' tw:rotate-270' }
const SIZES = { sm: 'tw:h-3 tw:w-3', md: 'tw:h-4 tw:w-4' }

// UI::IconChevron::Component
export const iconChevron = ({ size = 'sm', direction = 'right' } = {}) => chevronRight(`tw:inline-block ${SIZES[size]}${ROTATIONS[direction]}`)
