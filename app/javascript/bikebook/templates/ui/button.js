// UI::Button::Component's BASE_CLASSES, FOCUS_CLASSES and DISABLED_CLASSES
export const BASE_CLASSES = 'tw:inline-flex tw:items-center tw:justify-center tw:gap-1.5 tw:cursor-pointer'
export const FOCUS_CLASSES = 'tw:focus:outline-none tw:focus:ring-3 tw:is-active:focus:ring-3'
export const DISABLED_CLASSES = 'tw:disabled:opacity-50 tw:disabled:cursor-not-allowed tw:aria-disabled:opacity-50 tw:aria-disabled:cursor-not-allowed'
const SIZES = { sm: 'tw:px-2.5 tw:py-1 tw:text-xs', md: 'tw:px-3 tw:py-1.5 tw:text-sm' }
const COLORS = {
  secondary: 'tw:text-gray-800 tw:bg-white/80 tw:border-gray-200 tw:not-disabled:not-aria-disabled:hover:border-purple-500 ' +
    'tw:not-disabled:not-aria-disabled:hover:bg-purple-50 tw:focus:ring-purple-500/40 tw:dark:bg-gray-900/80 tw:dark:text-gray-100 ' +
    'tw:dark:border-gray-700 tw:dark:not-disabled:not-aria-disabled:hover:border-purple-500 tw:dark:not-disabled:not-aria-disabled:hover:bg-purple-950',
  link: 'twlink tw:rounded-lg tw:p-0 tw:focus:ring-blue-500/40',
  link_gray: 'twlink-underlined tw:text-gray-500 tw:not-disabled:not-aria-disabled:hover:text-gray-700 tw:dark:text-gray-400 ' +
    'tw:dark:not-disabled:not-aria-disabled:hover:text-gray-200 tw:rounded-lg tw:p-0 tw:focus:ring-gray-500/40'
}
const ACTIVE_COLORS = {
  secondary: 'tw:is-active:text-white tw:is-active:bg-purple-500 tw:is-active:border-purple-500 tw:is-active:ring-2 tw:is-active:ring-purple-500/40',
  link_gray: 'tw:is-active:text-gray-900 tw:is-active:dark:text-gray-100'
}
// UI::Button::Component::LINK_COLORS
export const LINK_COLORS = ['link', 'link_gray']

// UI::Button::Component.build_classes for the colors the browser renders, secondary and the link colors, which aren't
// button-shaped
export const buttonClasses = ({ size = 'md', htmlClass, color = 'secondary' }) => [
  BASE_CLASSES, htmlClass, FOCUS_CLASSES, DISABLED_CLASSES,
  !LINK_COLORS.includes(color) && `tw:rounded-lg tw:border tw:font-medium tw:transition-colors ${SIZES[size]} tw:no-underline`,
  COLORS[color], ACTIVE_COLORS[color]
].filter(Boolean).join(' ')
