<?php

function add($a, $b) {
    return $a + $b;
}

class Point {
    public $x;
    public $y;

    public function __construct($x, $y) {
        $this->x = $x;
        $this->y = $y;
    }

    public function distance($other) {
        $dx = $this->x - $other->x;
        $dy = $this->y - $other->y;
        return sqrt($dx * $dx + $dy * $dy);
    }
}

$sum = add(1, 2);
$p1 = new Point(0.0, 0.0);
$p2 = new Point(3.0, 4.0);
echo "Sum: $sum\n";
echo "Distance: " . $p1->distance($p2) . "\n";
