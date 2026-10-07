import { html, nothing } from 'lit-html'

const join = (...classes) => classes.filter(Boolean).join(' ')

// UI::Table::Component's GROUP_HEADING_CLASSES
const GROUP_HEADING_CLASSES = 'tw:px-1 tw:pt-4 tw:pb-1 tw:text-xs tw:font-bold tw:tracking-wider tw:uppercase tw:text-gray-500 tw:dark:text-gray-400'

// UI::Table::Component bordered and unsorted, with UI::TableColumn::Component's header and cells. `groups` is its
// record_groups, [heading, records] pairs in place of `records`. A column's `cell` and `cellClass` take the row's
// record, and a `rowHeader` column's cells are row headers
export const table = ({ records, groups = [[null, records]], classes, columns }) => html`<div class="twgutter-bleed tw:mb-4 tw:overflow-x-scroll tw:pb-3"
  data-controller="ui--table" data-ui--table-sticky-value="false"><table class=${join('ui-table tw:min-w-full tw:text-left tw:leading-[1.25]',
  'tw:border-separate tw:border-spacing-0 ui-table-bordered', classes)}><thead class="tw:bg-gray-50 tw:text-sm tw:dark:bg-gray-700"><tr>${
    columns.map((column) => html`<th class=${join('tw:px-1 tw:py-2 tw:border-b tw:border-l tw:border-t tw:border-gray-200 tw:dark:border-gray-600',
      column.classes, column.headerClasses)}>${column.label}</th>`)}</tr></thead>${
    groups.map(([heading, groupRecords]) => html`<tbody>${heading
      ? html`<tr><th scope="rowgroup" colspan=${columns.length} class=${GROUP_HEADING_CLASSES}>${heading}</th></tr>`
      : nothing}${groupRecords.map((record) => html`<tr>${columns.map((column) => {
        const cellClasses = join('tw:px-1 tw:py-1', 'tw:border-b tw:border-l tw:border-gray-200 tw:dark:border-gray-700', column.classes, column.cellClass?.(record))
        return column.rowHeader
          ? html`<th scope="row" class=${cellClasses}>${column.cell(record)}</th>`
          : html`<td class=${cellClasses}>${column.cell(record)}</td>`
      })}</tr>`)}</tbody>`)
  }</table></div>`
