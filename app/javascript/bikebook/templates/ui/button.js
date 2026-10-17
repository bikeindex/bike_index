const SIZES = { sm: 'tw:px-2.5 tw:py-1 tw:text-xs', md: 'tw:px-3 tw:py-1.5 tw:text-sm' }
const COLORS = {
  secondary: 'tw:text-gray-800 tw:bg-white tw:border tw:border-gray-200 tw:not-disabled:not-aria-disabled:hover:border-purple-500 ' +
    'tw:not-disabled:not-aria-disabled:hover:bg-purple-50 tw:focus:ring-purple-500/40 tw:dark:bg-gray-800 tw:dark:text-gray-100 ' +
    'tw:dark:border-gray-700 tw:dark:not-disabled:not-aria-disabled:hover:border-purple-500 tw:dark:not-disabled:not-aria-disabled:hover:bg-purple-950',
  link: 'twlink tw:rounded-lg tw:p-0 tw:focus:ring-blue-500/40'
}
const ACTIVE_COLORS = {
  secondary: 'tw:is-active:text-white tw:is-active:bg-purple-500 tw:is-active:border-purple-500 tw:is-active:ring-2 tw:is-active:ring-purple-500/40'
}

// UI::Button::Component.build_classes for the colors the browser renders, secondary and link, which isn't button-shaped
export const buttonClasses = ({ size = 'md', htmlClass, color = 'secondary' }) => [
  'tw:inline-flex tw:items-center tw:justify-center tw:gap-1.5 tw:cursor-pointer', htmlClass,
  'tw:focus:outline-none tw:focus:ring-3 tw:is-active:focus:ring-3',
  'tw:disabled:opacity-50 tw:disabled:cursor-not-allowed tw:aria-disabled:opacity-50 tw:aria-disabled:cursor-not-allowed',
  color !== 'link' && `tw:rounded-lg tw:font-medium tw:transition-colors ${SIZES[size]} tw:no-underline`,
  COLORS[color], ACTIVE_COLORS[color]
].filter(Boolean).join(' ')
