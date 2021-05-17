import java.io.FilenameFilter;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.attribute.BasicFileAttributes;
import java.nio.file.attribute.FileTime;
import processing.video.*;

FileTime glsl_mtime;
PShader glsl_shader;
String glsl_filename;
long glsl_next_check_ms = 0;
int glsl_n = 0;
boolean movie_playing = false;
boolean movie_reinit = false;
int movie_zoom = 100;
volatile boolean movie_present_frame = false;
float dragXOffset = 0.0; 
float dragYOffset = 0.0;
float bx, by;
Movie movie;
LEDpijp ledpijp;

void settings() {
  ledpijp = new LEDpijp(this, 2000000);
  size(ledpijp.suggestedwidth, ledpijp.suggestedheight, P3D);

    // 64-byte chunks give the best throughput for me using CH340G USB<->serial
  // on Windows 10. Try chunks up to the USB 2.0 maximum: 512-bytes
  // 0 disables chunking entirely.
  // 64 is the default value if you don't call set_chunksize().
  // ledpijp.set_chunksize(512);
  //ledpijp.set_chunksize(0);
}

void setup() {
  println(Capture.list());
}

void draw() {
  background(color(0,0,0));
  if (movie_playing && movie != null) {
    int wait = millis();
    while ((!movie_present_frame) && (millis() - wait < 250));
    if (movie_present_frame) {
      movie_present_frame = false;
      if (movie_reinit) {
        movie_zoom = 100 * pixelHeight / movie.height;
        bx = pixelWidth / 2;
        by = pixelHeight / 2;
        movie_reinit = false;
      }
      imageMode(CENTER);
      // image(movie, pixelWidth / 2, pixelHeight / 2, movie_zoom * movie.width / 100, movie_zoom * movie.height / 100);
      image(movie, bx, by, movie_zoom * movie.width / 100, movie_zoom * movie.height / 100);
      ledpijp.send();
    } 
  } else {
    use_shader(0); // reload the current shader if it's modified
    glsl_shader.set("time", millis() / 500.0);
    shader(glsl_shader);
    rect(0, 0, pixelWidth, pixelHeight);
    resetShader();
    ledpijp.send();
  }
}

int fps = 60;
void keyPressed() {
  switch (key) {
    case 'B': case 'b': case 's': case '?': case '/':
      byte[] cmdbuffer = new byte[1];
      cmdbuffer[0] = byte(key);
      ledpijp.command(cmdbuffer);
      if (key == '/')
        println("\nsender frame: " + ledpijp.sent_frames + " - fps: " + frameRate);
      break;
    case ' ':
      ledpijp.sending = ! ledpijp.sending;
      if (ledpijp.sending) {
        ledpijp.quit_screensaver();
      }
      break;
    case 'f':
      if (fps > 4) {  // Processing isn't happy below 4 FPS
        frameRate(--fps);
      }
      println("FPS goal: " + fps);
      break;
    case 'F':
      frameRate(++fps);
      println("FPS goal: " + fps);
      break;
    case 'l':
      ledpijp.change_led_order(1);
      break;
    case 'L':
      ledpijp.change_led_order(-1);
      break;
    case 'g':
      ledpijp.inc_gamma(-0.05);
      break;
    case 'G':
      ledpijp.inc_gamma(0.05);
      break;
    case ',':
      use_shader(-1);
      break;
    case '.':
      use_shader(1);
      break;
    case 'C':
      if (ledpijp.chunksize < 512)
        ledpijp.chunksize++;
      println("Chunk size: " + ledpijp.chunksize);
      break;
    case 'c':
      if (ledpijp.chunksize > 0)
        ledpijp.chunksize--;
      println("Chunk size: " + ledpijp.chunksize);
      break;
    case 't':
      if (ledpijp.fastled_show_ns > 10000)
        ledpijp.fastled_show_ns -= 10000;
      println("fastled_show_ns: " + ledpijp.fastled_show_ns);
      break;
    case 'T':
      ledpijp.fastled_show_ns += 10000;
      println("fastled_show_ns: " + ledpijp.fastled_show_ns);
      break;
    case 'm':
      if (movie != null) {
        movie.stop();
      }
      movie_playing = false;
      break;
    case 'o':
      if (movie != null) {
        movie.stop();
      }
      movie_playing = true; // disable the GLSL shader
      movie_present_frame = false; // but don't try to render anything
      selectInput("Select a file to process:", "movieSelected");
      break;
    case CODED:
      if (keyCode == RIGHT && movie_playing) {
        movie.jump(movie.time() + 30.0);
      }
      if (keyCode == LEFT && movie_playing && movie.time() > 5.0) {
        movie.jump(movie.time() - 5.0);
      }
      if (keyCode == UP) {
        movie_zoom += 1;
      }
      if (keyCode == DOWN && movie_zoom > 1) {
        movie_zoom -= 1;
      }
      break;
    default:
  }
}

// zoom the movie with the mousewheel
void mouseWheel(MouseEvent event) {
  float e = - event.getCount();
  if (e < 0 && movie_zoom < 2 ) {
    return;
  }
  movie_zoom += e;
}

void mousePressed() {
  dragXOffset = mouseX - bx; 
  dragYOffset = mouseY - by; 
}

void mouseDragged() {
  bx = mouseX - dragXOffset; 
  by = mouseY - dragYOffset; 
}


// Called every time a new frame is available to read
void movieEvent(Movie m) {
  m.read();
  movie_present_frame = true;
}

void movieSelected(File selection) {
  if (selection != null) {
    movie = new Movie(this, selection.getAbsolutePath());
    movie_playing = true;
    movie.loop();
    movie_reinit = true;
  } else {
    movie_playing = false;
  }
}

static final FilenameFilter GLSLfilter = new FilenameFilter() {
  boolean accept(File f, String s) {
    return s.toLowerCase().endsWith(".glsl");
  }
};

void use_shader(int delta) {
  // regularly check if the shader has been modified
  if (millis() < glsl_next_check_ms && delta == 0) {
    return;
  }
  glsl_next_check_ms = millis() + 500;

  String[] filenames = new String[0];

  // get a directory listing to find the filename
  if (delta != 0 || glsl_shader == null) {
    try {
      File dir = new File(this.dataPath(""));
      filenames = dir.list(GLSLfilter);
      // println(filenames);
    } catch (Exception e) {
      println("filename: " + e.getMessage());
      return;
    }
    
    glsl_n += delta;
    if (glsl_n < 0)
      glsl_n += filenames.length;
    glsl_n %= filenames.length;
    glsl_mtime = null;
    glsl_filename = filenames[glsl_n];
  }

  // we need the modification time of this file
  BasicFileAttributes attr;
  try {
    Path file = Paths.get(dataPath(glsl_filename));
    attr = Files.readAttributes(file, BasicFileAttributes.class);
  } catch (IOException e) {
    println("mtime: " + e.getMessage());
    return;
  }

  // has the file modification time changed?
  int diff = 1;
  if (glsl_mtime != null)
    diff = attr.lastModifiedTime().compareTo(glsl_mtime);

  if (diff == 0)
    return;

  glsl_mtime = attr.lastModifiedTime();
  
  println(attr.lastModifiedTime().toString().substring(0,19) + " loading: " + glsl_filename);
  PShader old_shader = glsl_shader;
  try {
    glsl_shader = loadShader(glsl_filename);
    glsl_shader.set("resolution", float(pixelWidth), float(pixelHeight));
    glsl_shader.set("time", millis() / 500.0);
    shader(glsl_shader); // trigger the GLSL compiler
    resetShader();

  } catch (RuntimeException e) {
    println("load: " + e.getMessage());
    if (old_shader != null) {
      glsl_shader = old_shader;
      shader(glsl_shader);
      resetShader();
    }
  }
}
