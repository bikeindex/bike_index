prev = document.getElementById('bi-slide-prev')
next = document.getElementById('bi-slide-next')
if document.contains(prev)
  window.mySwipe = new Swipe(document.getElementById('slider'), 
    auto: 4000
  )  
  if document.body.addEventListener
    prev.addEventListener "click", ->
      mySwipe.prev()
    next.addEventListener "click", ->
      mySwipe.next()
  else
    prev.attachEvent "click", ->
      mySwipe.prev()
    next.attachEvent "click", ->
      mySwipe.next()
  