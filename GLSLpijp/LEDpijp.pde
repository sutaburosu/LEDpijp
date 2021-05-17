import java.util.Arrays;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import processing.serial.*;

public class LEDpanel {
  final int SERPENTINE = 16, ROWMAJOR = 8, TRANSPOSE = 4, FLIPMAJOR = 2, FLIPMINOR = 1;
  int id, width, height, xoffset, yoffset, layout;
  float gamma;
  Serial port;
  String name;
  int[] gammatable = new int[256];
  byte[] panelBytes;

  public LEDpanel(int id, int width, int height, int xoffset, int yoffset, int layout, float gamma, Serial port, String name, boolean yflip) {
    this.id = id;
    this.width = width;
    this.height = height;
    this.xoffset = xoffset;
    this.yoffset = yoffset;
    this.layout = layout;
    this.set_gamma(gamma);
    this.port = port;
    this.name = name;
    if (yflip) {
      // reverse the vertical order of the pixels
      if ((this.layout & ROWMAJOR) != 0)
        this.layout ^= FLIPMINOR;
      else
        this.layout ^= FLIPMAJOR;
    }
    this.panelBytes = new byte[3 * this.width * this.height];
  }

  public void set_gamma(float gamma) {
    if (this.gamma != gamma) {
      this.gamma = gamma;
      for (int i = 0; i < 256; i++)
        gammatable[i] = (int)(pow(i / 255.0, this.gamma) * 255.0 + 0.5);
    }
  }

  // I think TRANSPOSE is only useful to rotate square panels.
  public int XY(int x, int y) {
    int major, minor, sz_major, sz_minor;
    if (x >= width || y >= height)
      return (width * height);
    if ((layout & ROWMAJOR) != 0) {
      major = x; minor = y; sz_major = width;  sz_minor = height;
    } else {
      major = y; minor = x; sz_major = height; sz_minor = width;
    }
    if (((layout & FLIPMAJOR) != 0) ^ (((minor & 1) != 0) && ((layout & SERPENTINE) != 0)))
      major = sz_major - 1 - major;
    if ((layout & FLIPMINOR) != 0)
      minor = sz_minor - 1 - minor;
    if ((layout & TRANSPOSE) != 0)
      return major * sz_minor + minor;
    else
      return minor * sz_major + major;
  }
}

public class LEDpijp {
  PApplet parent;
  int baud;
  int totalwidth, totalheight, panelwidth, panelheight;
  int suggestedwidth = 512;
  int suggestedheight = 256;
  boolean yflip = true;   // Processing's Y axis is reversed compared to the .ino
  int chunksize = 64;
  LEDpanel ledpanel[] = new LEDpanel[0];
  byte[] cmdblock = new byte[0];
  long frame_sent_ns = 0;
  long fastled_show_ns = 0;
  boolean sending = true;
  long sent_frames = 0;
  PImage ledImage;
  final int RECV_TIMEOUT_MS = 10;      // these two timeouts should match those
  final int FRAME_TIMEOUT_MS = 250;   // in the Arduino sketch
  String ledtype;
  float gamma_mul = 1.0;
  
  public LEDpijp(PApplet parent, int baud) {
    this.parent = parent;
    this.baud = baud;

    // pull the configuration from any connected panels
    discover_panels(baud);
    if (ledpanel.length == 0) {
      println("!!! Found no usable panels !!!");
      return;
    }

    long this_show_ns = frame_time(panelwidth, panelheight, ledtype);
    if (this_show_ns > fastled_show_ns)
      fastled_show_ns = this_show_ns;
    ledImage = createImage(panelwidth, panelheight, RGB);

    // ~~suggest the narrowest window that Processing won't silently resize~~
    // being able to grab the title bar is handy, so a bit wider than that
    int mul = 1;
    while (totalwidth * mul < /*96*/ 140) {
      if (mul == 1)
        mul++;
      else
        mul += 2;
    }
    suggestedwidth = mul * totalwidth;
    suggestedheight = mul * totalheight;
  }

  public void set_chunksize(int size) {
    if (size > 0) {
      this.chunksize = size;
    }
  }

  // queue a command to be sent to all panels before the next frame
  private void command(byte[] cmd) {
    cmdblock = cmd;
  }
  
  private void quit_screensaver() {
    // send the command to briefly disable the screensaver. This is not
    // 100% necessary, but helps to prevent glitches when anything takes
    // longer than FRAME_TIMEOUT_MS.  I'm looking at you, GLSL compiler.
    byte[] cmd = new byte[1];
    cmd[0] = byte(0);
    for (int p = 0; p < ledpanel.length; p++) {
      if (ledpanel[p] != null) {
        ledpanel[p].port.write(cmd);
      }
    }
    // FastLED.show() may be running, so wait for that to complete,
    // plus RECV_TIMEOUT, plus 1ms for the USB CDC event to be sent
    delay(int(fastled_show_ns / 1000 / 1000) + 3 + 1);
    frame_sent_ns = System.nanoTime();
  }

  private void change_led_order(int inc) {
    for (int p = 0; p < ledpanel.length; p++) {
      if (ledpanel[p] == null) {
        continue;
      }
      int tmp = ledpanel[p].layout + inc;
      if (tmp < 0) {
        tmp += 32;
      }
      tmp %= 32;
      print(p + ": " + tmp + "\t");
      ledpanel[p].layout = tmp;
    }
    println();
  }

  public long frame_time(int width, int height, String ledtype) {
    int us_per_led;
    switch (ledtype) {
      case "SMARTMATRIX":
        us_per_led = 0;
        return 1000; // 6ms
      case "WS2812B": case "TM1829": case "TM1812": case "TM1809": case "TM1804":
      case "UCS1903B": case "UCS1904": case "WS2812": case "WS2852": case "GS1903":
      case "WS2811": case "APA104": case "GE8822": case "GW6205":
        // 800KHz LEDs
        us_per_led = 30;
        break;
      case "TM1803": case "UCS1903": case "WS2811_400": case "GW6205_400":
        // 400KHz LEDs
        us_per_led = 60;
        break;
      case "LPD6803": case "LPD8806": case "WS2801": case "WS2803":
      case "SM16716": case "P9813": case "APA102": case "SK9822": case "DOTSTAR":
        // SPI LEDs
        us_per_led = 1;  // TODO what value would be appropriate here?
        break;
      default:
        print("!!! Don't have timings for " + ledtype);
        println(" !!! Assuming 100μs per LED.");
        us_per_led = 100;
    }

    // plus 0.5ms to help with sync
    return 1000 * (500 + us_per_led * width * height);
  }

  private void send() {
    // capture and resize segments of the main window into panel-sized tiles
    for (int p = 0; p < ledpanel.length; p++) {
      if (ledpanel[p] == null) {
        continue;
      }
      ledImage.copy(g,
        pixelWidth  * ledpanel[p].xoffset / totalwidth,
        pixelHeight * ledpanel[p].yoffset / totalheight,
        pixelWidth  * ledpanel[p].width   / totalwidth,
        pixelHeight * ledpanel[p].height  / totalheight,
        0, 0, ledpanel[p].width, ledpanel[p].height);
      // apply gamma correction and rearrange pixels into the LEDs' native order
      for (int y = 0, index = 0; y < ledpanel[p].height; y++) {
        for (int x = 0; x < ledpanel[p].width; x++) {
          color c = ledImage.pixels[ledpanel[p].XY(x, y)];
          ledpanel[p].panelBytes[index++] = byte(ledpanel[p].gammatable[(c >> 16) & 0xff]);
          ledpanel[p].panelBytes[index++] = byte(ledpanel[p].gammatable[(c >> 8) & 0xff]);
          ledpanel[p].panelBytes[index++] = byte(ledpanel[p].gammatable[c & 0xff]);
        }
      }
    }
    
    // allow time for the previous FastLED.show() to complete
    long pause = fastled_show_ns - (System.nanoTime() - frame_sent_ns);
    if (pause > 0) {
      long end, start = System.nanoTime();
      do {
        end = System.nanoTime();
      } while (end - start < pause);
    } else if (pause <= (FRAME_TIMEOUT_MS * -1000000)) {
      // we're very late sending this frame; FRAME_TIMEOUT_MS will have expired
      // in the Arduino sketch. Prepare the receiver for reception first
      quit_screensaver();
    }
    
    // send any queued commands
    if (cmdblock.length > 0) {
      for (int p = 0; p < ledpanel.length; p++) {
        if (ledpanel[p] != null) {
          ledpanel[p].port.write(cmdblock);
        }
      }
      cmdblock = new byte[0];
      delay(RECV_TIMEOUT_MS + 1);
    }
    
    if (chunksize == 0) {
      for (int p = 0; p < ledpanel.length; p++) {
        if (ledpanel[p] == null) { continue; }
        if (sending) {
          ledpanel[p].port.write(ledpanel[p].panelBytes);
        }
      }
    } else if (chunksize > 0) {
      // Split the LED data into chunks and send them round-robin to each panel
      int remaining = panelwidth * panelheight * 3;
      int sent = 0;
      byte uart_buff[] = new byte[chunksize];
      while (remaining > 0) {
        int this_size = min(remaining, chunksize);
        if (uart_buff.length != this_size) {
          uart_buff = new byte[this_size];
        }
        for (int p = 0; p < ledpanel.length; p++) {
          if (ledpanel[p] == null) {
            continue;
          }
          uart_buff = Arrays.copyOfRange(ledpanel[p].panelBytes, sent, sent + this_size);
          if (sending) {
            ledpanel[p].port.write(uart_buff);
          }
        }
        remaining -= this_size;
        sent += this_size;
      }
    }


    frame_sent_ns = System.nanoTime();
    if (sending)
      sent_frames++;
    
    // print any received data
    for (int p = 0; p < ledpanel.length; p++) {
      if (ledpanel[p] == null) {
        continue;
      }
      if (ledpanel[p].port.available() > 0) {
        String recvd = ledpanel[p].port.readString();
        if (recvd != null) {
          print(p + ": " + recvd);
        }
      }
    }
  }
  
  private void discover_panels(int baud) {
    // connect to all serial ports
    String[] portlist = Serial.list();
    Serial[] candidates = new Serial[portlist.length];
    for (int portn = 0; portn < portlist.length; portn++) {
      try {
        candidates[portn] = new Serial(parent, portlist[portn], baud);
      } catch (RuntimeException e) {
        // ignore any serial ports that cannot be opened
      };
    }
  
    // wait for bootloader
    delay(1750);
  
    // send the query string to each port
    for (int portn = 0; portn < candidates.length; portn++) {
      if (candidates[portn] == null) continue;
      candidates[portn].write(byte('?'));
    }
    delay(200);

    // everybody stand back.  https://xkcd.com/208/
    Pattern regex = Pattern.compile("^id:(?<id>\\d+)\\s+" +
      "xy:(?<panelwidth>\\d+)x(?<panelheight>\\d+)" + 
      "\\((?<totalwidth>\\d+)x(?<totalheight>\\d+)\\)\\s+" +
      "o:(?<xoffset>\\d+)x(?<yoffset>\\d+)\\s+" +
      "l:(?<layout>\\d+) g:(?<gamma>\\d+\\.?\\d*)" +
      "(\\s+t:(?<ledtype>\\S+))?\\s");

    for (int portn = 0; portn < candidates.length; portn++) {
      if (candidates[portn] == null) continue;
      if (candidates[portn].available() <= 0) {
        continue;
      }

      String recvd = candidates[portn].readString();
      //println(recvd);
      Matcher m = regex.matcher(recvd);  //  \o/ o/
      if (!m.find()) {
        continue;
      }
      print(portlist[portn] + ": " + recvd);
      int id = int(m.group("id"));

      if (ledpanel.length == 0) {
        this.totalwidth = int(m.group("totalwidth"));
        this.totalheight = int(m.group("totalheight"));
        this.panelwidth = int(m.group("panelwidth"));
        this.panelheight = int(m.group("panelheight"));
        this.ledtype = m.group("ledtype");
      } else {
        if (this.totalwidth != int(m.group("totalwidth")) | 
            this.totalheight != int(m.group("totalheight"))) {
          println("Panels disagree about TOTALWIDTH / TOTALHEIGHT.  Hold your hat.");
        }
        if (this.panelwidth != int(m.group("panelwidth")) |
            this.panelheight != int(m.group("panelheight"))) {
          println("Panels have different dimensions. This is untested.");
        }
      }

      // grow the array if necessary
      while (ledpanel.length < id + 1) {
        ledpanel = (LEDpanel[]) concat(ledpanel, new LEDpanel[1]);
      }

      if (ledpanel[id] != null) {
        println(portlist[portn], "Ignoring duplicate PANELID", id);
        continue;
      }

      // add this panel to the matrix (after flipping the Y offset to be +ve down)
      int yoffset = int(m.group("yoffset"));
      yoffset = int(m.group("totalheight")) - int(m.group("panelheight")) - yoffset;
      ledpanel[id] = new LEDpanel(id,
        int(m.group("panelwidth")), int(m.group("panelheight")),
        int(m.group("xoffset")), yoffset,
        int(m.group("layout")), float(m.group("gamma")),
        candidates[portn], portlist[portn], yflip);
    }
  }

  public void inc_gamma(float inc) {
    for (int p = 0; p < ledpanel.length; p++) {
      if (ledpanel[p] == null) {
        continue;
      }
      ledpanel[p].set_gamma(int(100 * (inc + ledpanel[p].gamma)) / 100.0);
      print(p + ": " + ledpanel[p].gamma + "\t");
    }
    println();
  }
}
