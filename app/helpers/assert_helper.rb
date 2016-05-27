=begin
*****************************************************************
* File: app/helpers/assert_helper.rb 
* Name: module AssertHelper 
* Just create simple assert page
*****************************************************************
=end

module AssertHelper

=begin
  Name: assert_message
  Explication: method created to simulation an method assert to debug
  Params: condition
  Return: nothing or assert page
=end
	def assert_message(condition)
		if (condition)
			# if condition pass the program keep running
		else 
			redirect_to assert_path
			#server_exception = stop the program
		end
	end

=begin
  Name: assert_object_is_not_null
  Explication: method created to simulation an object is not null to debug 
  Params: object that will be evaluated 
  Return: nothing or error page
=end
	def assert_object_is_not_null(object)
    if( not object.nil? )
      # if condition pass the program keep running
    else
      redirect_to assert_error_null_path
    end
  end

end