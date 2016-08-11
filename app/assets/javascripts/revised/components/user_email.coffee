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
		result = @checkUserEmail(checkObj)
		@appendMessage(result)

	checkUserEmail: (obj) -> Mailcheck.run(obj)

	appendMessage: (result) ->
		if result
			$user_email = $('#user_email')
			$user_email.parent().addClass('has-warning')
			message = "Did you mean <ins>#{result}</ins> ?"
			$resultParagraph = "<small id='user_email_message'>" + message + "</small>"
			$user_email.after($resultParagraph)
			@appendMessageEvent(result)
		return false

	appendMessageEvent: (new_value) ->
		$resultParagraph = $("#user_email_message")
		$resultParagraph.click () => 
			$user_email = $('#user_email')
			$user_email.val(new_value)
									.parent().removeClass('has-warning')
			$resultParagraph.remove()


