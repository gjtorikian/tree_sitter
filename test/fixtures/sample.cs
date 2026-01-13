using System;

public class Sample
{
    public static int Add(int a, int b)
    {
        return a + b;
    }

    public static void Main(string[] args)
    {
        int sum = Add(1, 2);
        Point p1 = new Point(0.0, 0.0);
        Point p2 = new Point(3.0, 4.0);
        Console.WriteLine($"Sum: {sum}");
        Console.WriteLine($"Distance: {p1.Distance(p2)}");
    }
}

public class Point
{
    public double X { get; }
    public double Y { get; }

    public Point(double x, double y)
    {
        X = x;
        Y = y;
    }

    public double Distance(Point other)
    {
        double dx = X - other.X;
        double dy = Y - other.Y;
        return Math.Sqrt(dx * dx + dy * dy);
    }
}
