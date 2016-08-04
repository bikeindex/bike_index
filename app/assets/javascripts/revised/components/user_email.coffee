class BikeIndex.UserEmail extends BikeIndex
	constructor: -> 
		$("#user_email").blur () => 
			@checkEmailOnChange()

	checkEmailOnChange: () ->
		$user_email = $("#user_email")
		checkObj = 
			email: $user_email.val()
			suggested: (result) ->
				return result.full
			empty: () -> return false
		result = @checkUserEmail(checkObj)
		@appendMessage(result)

	checkUserEmail: (obj) -> Mailcheck.run(obj)

	appendMessage: (result) ->
		if result
			message = "Did you mean #{result} ?"
			$resultParagraph = "<p id='user_email_message'>" + message + "</p>"
			$("#user_email").after($resultParagraph)
			@appendMessageEvent(result)
		return false

	appendMessageEvent: (new_value) ->
		$resultParagraph = $("#user_email_message")
		$resultParagraph.click () => 
			$("#user_email").val(new_value)
			$resultParagraph.remove()


