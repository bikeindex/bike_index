const STEPS = { ArrowUp: -1, ArrowLeft: -1, ArrowDown: 1, ArrowRight: 1 }

// An arrow key on a UI::DragHandle moves its item one place, as a drop beside the neighbour would.
// items is a function, read again after the move, which leaves the moved item at the neighbour's index
export function moveByKey (event, items, move) {
  const step = STEPS[event.key]
  if (!step) return
  event.preventDefault()
  const before = items()
  const index = before.findIndex(item => item.contains(event.target)) + step
  if (!before[index]) return
  move(before[index - step], before[index], step > 0)
  // Moving an element out of the DOM and back drops its focus
  const handle = items()[index].querySelector('[data-moved-message]')
  handle.focus()
  announce(handle.dataset.movedMessage.replace('%{position}', index + 1).replace('%{count}', before.length))
}

// Emptied first so the same position, twice, is still said twice
function announce (message) {
  const status = document.getElementById('drag-handle-status') ?? document.body.appendChild(liveRegion())
  status.textContent = ''
  window.requestAnimationFrame(() => { status.textContent = message })
}

function liveRegion () {
  const region = document.createElement('div')
  region.id = 'drag-handle-status'
  region.className = 'tw:sr-only'
  region.setAttribute('role', 'status')
  return region
}
