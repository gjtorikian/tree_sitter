import math

def add(a, b):
    return a + b

class Point:
    def __init__(self, x, y):
        self.x = x
        self.y = y

    def distance(self, other):
        dx = self.x - other.x
        dy = self.y - other.y
        return math.sqrt(dx * dx + dy * dy)

sum_result = add(1, 2)
p1 = Point(0.0, 0.0)
p2 = Point(3.0, 4.0)
print(f"Sum: {sum_result}")
print(f"Distance: {p1.distance(p2)}")
