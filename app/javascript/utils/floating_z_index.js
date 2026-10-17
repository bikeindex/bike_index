// Where a floating element (a dropdown menu, a tooltip) sits: above
// SharedBlocks::Navbar::OrgSidebar's tw:z-[1050], which a menu opened at the left edge of
// the content column extends over, and below bootstrap's $zindex-modal (1061).
const FLOOR = 1051

// The open ones, in the order they were raised, each a step above the last. Renumbered rather than
// climbing, so the ceiling is however many are open at once - a counter incremented per open reaches
// the modal band within a session of hovering
const open = []

const renumber = () => open.forEach((element, index) => { element.style.zIndex = FLOOR + index })

// Puts `element` above every other open one, though it's open already
export function claimFloatingZIndex (element) {
  if (open.includes(element)) open.splice(open.indexOf(element), 1)
  open.push(element)
  renumber()
}

export function releaseFloatingZIndex (element) {
  if (open.includes(element)) open.splice(open.indexOf(element), 1)
  renumber()
}
