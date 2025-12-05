# Basic class with attributes, nil handling, and methods

class User
  attr_reader :name, :email, :age

  def initialize(name, email, age = nil)
    @name = name
    @email = email
    @age = age
  end

  def adult?
    if age = @age
      age >= 18
    else
      false
    end
  end

  def display_name
    "#{@name} <#{@email}>"
  end

  def greeting(formal: false)
    if formal
      "Dear #{@name}"
    else
      "Hi #{@name}!"
    end
  end
end
