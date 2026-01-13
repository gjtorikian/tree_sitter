function add(a, b) {
  return a + b;
}

class Point {
  constructor(x, y) {
    this.x = x;
    this.y = y;
  }

  distance(other) {
    const dx = this.x - other.x;
    const dy = this.y - other.y;
    return Math.sqrt(dx * dx + dy * dy);
  }
}

const sum = add(1, 2);
const p1 = new Point(0.0, 0.0);
const p2 = new Point(3.0, 4.0);
console.log(`Sum: ${sum}`);
console.log(`Distance: ${p1.distance(p2)}`);
