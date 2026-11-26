import { chevronRight } from 'bikebook/templates/icons'

const SIZES = { sm: 'tw:h-3 tw:w-3', md: 'tw:h-4 tw:w-4' }

// UI::IconChevron::Component, pointing right
export const iconChevron = ({ size = 'sm' } = {}) => chevronRight(`tw:inline-block ${SIZES[size]}`)
