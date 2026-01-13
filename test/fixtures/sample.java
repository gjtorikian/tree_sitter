public class Sample {
    public static int add(int a, int b) {
        return a + b;
    }

    public static void main(String[] args) {
        int sum = add(1, 2);
        Point p1 = new Point(0.0, 0.0);
        Point p2 = new Point(3.0, 4.0);
        System.out.println("Sum: " + sum);
        System.out.println("Distance: " + p1.distance(p2));
    }
}

class Point {
    private double x;
    private double y;

    public Point(double x, double y) {
        this.x = x;
        this.y = y;
    }

    public double distance(Point other) {
        double dx = this.x - other.x;
        double dy = this.y - other.y;
        return Math.sqrt(dx * dx + dy * dy);
    }
}
