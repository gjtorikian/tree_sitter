package main

import (
	"fmt"
	"math"
)

func add(a, b int) int {
	return a + b
}

type Point struct {
	x, y float64
}

func NewPoint(x, y float64) Point {
	return Point{x: x, y: y}
}

func (p Point) Distance(other Point) float64 {
	dx := p.x - other.x
	dy := p.y - other.y
	return math.Sqrt(dx*dx + dy*dy)
}

func main() {
	sum := add(1, 2)
	p1 := NewPoint(0.0, 0.0)
	p2 := NewPoint(3.0, 4.0)
	fmt.Printf("Sum: %d\n", sum)
	fmt.Printf("Distance: %f\n", p1.Distance(p2))
}
