import { html, nothing } from 'lit-html'

const join = (...classes) => classes.filter(Boolean).join(' ')

// UI::Table::Component bordered and unsorted, with UI::TableColumn::Component's header and cells. A column's `cell`
// and `cellClass` take the row's record, and a `rowHeader` column's cells are row headers. With an `alignKey`, each row
// is a data-align-row bikebook--align-rows sizes to the same row of a compared vehicle's table
export const table = ({ records, classes, columns, alignKey }) => html`<div class="twgutter-bleed tw:mb-4 tw:overflow-x-scroll tw:pb-3"
  data-controller="ui--table" data-ui--table-sticky-value="false"><table class=${join('ui-table tw:min-w-full tw:text-left tw:leading-[1.25]',
  'tw:border-separate tw:border-spacing-0 ui-table-bordered', classes)}><thead class="tw:bg-gray-50 tw:text-sm tw:dark:bg-gray-700"><tr data-align-row=${alignKey ? `${alignKey}:head` : nothing}>${
    columns.map((column) => html`<th class=${join('tw:px-1 tw:py-2 tw:border-b tw:border-l tw:border-t tw:border-gray-200 tw:dark:border-gray-600',
      column.classes, column.headerClasses)}>${column.label}</th>`)}</tr></thead><tbody>${
    records.map((record, index) => html`<tr data-align-row=${alignKey ? `${alignKey}:${index}` : nothing}>${columns.map((column) => {
      const cellClasses = join('tw:px-1 tw:py-1', 'tw:border-b tw:border-l tw:border-gray-200 tw:dark:border-gray-700', column.classes, column.cellClass?.(record))
      return column.rowHeader
        ? html`<th scope="row" class=${cellClasses}>${column.cell(record)}</th>`
        : html`<td class=${cellClasses}>${column.cell(record)}</td>`
    })}</tr>`)
  }</tbody></table></div>`
