# frozen_string_literal: true

def add(a, b)
  a + b
end

class Point
  attr_reader :x, :y

  def initialize(x, y)
    @x = x
    @y = y
  end

  def distance(other)
    dx = @x - other.x
    dy = @y - other.y
    Math.sqrt(dx * dx + dy * dy)
  end
end

sum = add(1, 2)
p1 = Point.new(0.0, 0.0)
p2 = Point.new(3.0, 4.0)
puts "Sum: #{sum}"
puts "Distance: #{p1.distance(p2)}"
