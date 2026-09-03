// Where a floating element (a dropdown menu, a tooltip) sits: above
// SharedBlocks::Navbar::OrgSidebar's tw:z-[1050], which a menu opened at the left edge of
// the content column extends over, and below bootstrap's $zindex-modal (1061).
const FLOOR = 1051

// Counted rather than climbing, so the ceiling is however many are open at once - a
// counter incremented per open reaches the modal band within a session of hovering
const open = new Set()

export function claimFloatingZIndex (element) {
  open.add(element)
  return FLOOR + open.size - 1
}

export function releaseFloatingZIndex (element) {
  open.delete(element)
}
