import java.awt.Color;
import java.awt.image.BufferedImage;
import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.List;
import javax.imageio.ImageIO;
public class image {

    public static int convert(String code) {
        switch (code) {
            case "R": return new Color(237, 28, 36).getRGB();
            case "B": return new Color(0, 0, 0).getRGB();
            case "Y": return new Color(255, 242, 0).getRGB();
            default:
                String[] p = code.replaceAll("[()\\s]", "").split(",");
                return new Color(Integer.parseInt(p[0]),
                        Integer.parseInt(p[1]),
                        Integer.parseInt(p[2])).getRGB();
        }
    }
    public static void main(String[] args) throws IOException {
        String inPath = args.length > 0 ? args[0] : "output.txt";
        String outPath = args.length > 1 ? args[1] : "smiley2.png";
        List<String> lines = Files.readAllLines(Paths.get(inPath));
        lines.removeIf(String::isBlank);
        int height = lines.size();
        int width = lines.get(0).trim().split("\\s+(?![^(]*\\))").length;
        BufferedImage img = new BufferedImage(width, height, BufferedImage.TYPE_INT_RGB);
        for (int y = 0; y < height; y++) {

            String[] pixels = lines.get(y).trim().split("\\s+(?![^(]*\\))");
            for (int x = 0; x < width; x++) {
                img.setRGB(x, y, convert(pixels[x]));
            }
        }
        ImageIO.write(img, "png", new File(outPath));
        System.out.println("Wrote " + outPath + " (" + width + "x" + height + ")");
    }
}
