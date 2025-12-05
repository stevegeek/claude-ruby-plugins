# Collection class with enumeration patterns

class Task
  attr_reader :title, :completed

  def initialize(title, completed = false)
    @title = title
    @completed = completed
  end

  def complete!
    @completed = true
  end
end

class TaskList
  def initialize
    @items = [] #: Array[Task]
  end

  def add(title)
    task = Task.new(title)
    @items << task
    task
  end

  def each(&block)
    return enum_for(:each) unless block
    @items.each(&block)
  end

  def select(&block)
    @items.select(&block)
  end

  def completed
    @items.select { |task| task.completed }
  end

  def pending
    @items.reject { |task| task.completed }
  end

  def count
    @items.size
  end
end
