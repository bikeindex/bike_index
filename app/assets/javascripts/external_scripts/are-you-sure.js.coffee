#!
# * jQuery Plugin: Are-You-Sure (Dirty Form Detection)
# * https://github.com/codedance/jquery.AreYouSure/
# *
# * Copyright (c) 2012-2013, Chris Dance and PaperCut Software http://www.papercut.com/
# * Dual licensed under the MIT or GPL Version 2 licenses.
# * http://jquery.org/license
# *
# * Author:   chris.dance@papercut.com
# * Version:  1.5.0
# * Date:     15th Nov 2013
# 
(($) ->
  $.fn.areYouSure = (options) ->
    settings = $.extend(
      message: "You have unsaved changes!"
      dirtyClass: "dirty"
      change: null
      silent: false
      fieldSelector: "select,textarea,input[type='text'],input[type='password'],input[type='checkbox'],input[type='radio'],input[type='hidden'],input[type='color'],input[type='date'],input[type='datetime'],input[type='datetime-local'],input[type='email'],input[type='month'],input[type='number'],input[type='range'],input[type='search'],input[type='tel'],input[type='time'],input[type='url'],input[type='week']"
    , options)
    getValue = ($field) ->
      return null  if $field.hasClass("ays-ignore") or $field.hasClass("aysIgnore") or $field.attr("data-ays-ignore") or $field.attr("name") is `undefined`
      return "ays-disabled"  if $field.is(":disabled")
      val = undefined
      type = $field.attr("type")
      type = "select"  if $field.is("select")
      switch type
        when "checkbox", "radio"
          val = $field.is(":checked")
        when "select"
          val = ""
          $field.children("option").each (o) ->
            $option = $(this)
            val += $option.val()  if $option.is(":selected")

        else
          val = $field.val()
      val

    storeOrigValue = ->
      $field = $(this)
      $field.data "ays-orig", getValue($field)

    checkForm = (evt) ->
      isFieldDirty = ($field) ->
        getValue($field) isnt $field.data("ays-orig")

      isDirty = false
      $form = $(this).parents("form")
      
      # Test on the target first as it's the most likely to be dirty.
      isDirty = true  if isFieldDirty($(evt.target))
      unless isDirty
        $form.find(settings.fieldSelector).each ->
          $field = $(this)
          if isFieldDirty($field)
            isDirty = true
            false # break

      markDirty $form, isDirty

    markDirty = ($form, isDirty) ->
      changed = isDirty isnt $form.hasClass(settings.dirtyClass)
      $form.toggleClass settings.dirtyClass, isDirty
      
      # Fire change event if required
      if changed
        settings.change.call $form, $form  if settings.change
        $form.trigger "dirty.areYouSure", [$form]  if isDirty
        $form.trigger "clean.areYouSure", [$form]  unless isDirty
        $form.trigger "change.areYouSure", [$form]

    rescan = ->
      $form = $(this)
      newFields = $form.find(settings.fieldSelector).not("[ays-orig]")
      $(newFields).each storeOrigValue
      $(newFields).bind "change keyup", checkForm

    reinitialize = ->
      $form = $(this)
      allFields = $form.find(settings.fieldSelector)
      $(allFields).each storeOrigValue
      markDirty $form, false

    unless settings.silent
      $(window).bind "beforeunload", ->
        $dirtyForms = $("form").filter("." + settings.dirtyClass)
        
        # $dirtyForms.removeClass(settings.dirtyClass); // Prevent multiple calls?
        settings.message  if $dirtyForms.length > 0

    @each (elem) ->
      return  unless $(this).is("form")
      $form = $(this)
      $form.submit ->
        $form.removeClass settings.dirtyClass

      $form.bind "reset", ->
        markDirty $form, false

      
      # Add a custom events
      $form.bind "rescan.areYouSure", rescan
      $form.bind "reinitialize.areYouSure", reinitialize
      fields = $form.find(settings.fieldSelector)
      $(fields).each storeOrigValue
      $(fields).bind "change keyup", checkForm

) jQuery