#include "Teensy4_ShieldV5_RBG.h"
#include <SmartMatrix.h>

//#define SMARTMATRIX_USE_PSRAM
//#define SCROLLER
#define COLOR_DEPTH 24                  // Choose the color depth used for storing pixels in the layers: 24 or 48 (24 is good for most sketches - If the sketch uses type `rgb24` directly, COLOR_DEPTH must be 24)
const uint16_t kMatrixWidth = 128;      // Set to the width of your display, must be a multiple of 8
const uint16_t kMatrixHeight = 64;      // Set to the height of your display
const uint8_t kRefreshDepth = 36;       // Tradeoff of color quality vs refresh rate, max brightness, and RAM usage.  36 is typically good, drop down to 24 if you need to.  On Teensy, multiples of 3, up to 48: 3, 6, 9, 12, 15, 18, 21, 24, 27, 30, 33, 36, 39, 42, 45, 48.  On ESP32: 24, 36, 48
const uint8_t kDmaBufferRows = 4;       // known working: 2-4, use 2 to save RAM, more to keep from dropping frames and automatically lowering refresh rate.  (This isn't used on ESP32, leave as default)
const uint8_t kPanelType = SM_PANELTYPE_HUB75_64ROW_MOD32SCAN;   // Choose the configuration that matches your panels.  See more details in MatrixCommonHub75.h and the docs: https://github.com/pixelmatix/SmartMatrix/wiki
const uint32_t kMatrixOptions = (SM_HUB75_OPTIONS_NONE);        // see docs for options: https://github.com/pixelmatix/SmartMatrix/wiki
const uint8_t kBackgroundLayerOptions = (SM_BACKGROUND_OPTIONS_NONE);
const uint8_t kScrollingLayerOptions = (SM_SCROLLING_OPTIONS_NONE);

SMARTMATRIX_ALLOCATE_BUFFERS(matrix, kMatrixWidth, kMatrixHeight, kRefreshDepth, kDmaBufferRows, kPanelType, kMatrixOptions);
SMARTMATRIX_ALLOCATE_BACKGROUND_LAYER(backgroundLayer, kMatrixWidth, kMatrixHeight, COLOR_DEPTH, kBackgroundLayerOptions);
#ifdef SCROLLER
  SMARTMATRIX_ALLOCATE_SCROLLING_LAYER(scrollingLayer, kMatrixWidth, kMatrixHeight, COLOR_DEPTH, kScrollingLayerOptions);
#endif



#include <stdarg.h>
#include "XYmatrix.h"
#include "scrnsvr_metaballs.h"
#include "scrnsvr_leapers.h"

// configure your LEDs in XYmatrix.h

#define BAUD                2000000
#define FRAME_TIMEOUT_MS    250
#define SCREENSAVER_MS      (1000 + FRAME_TIMEOUT_MS)
#define INITIAL_TIMEOUT_MS  5000
#define RECV_TIMEOUT_MS     10
#define NO_INPUT_AWAIT_MS   10

uint8_t brightness = BRIGHTNESS;
uint8_t screensaver_n = 0;
uint32_t total_frames = 0;
uint16_t fps = 0;

// The HardwareSerial library is too slow for 2Mbaud on AVR. ꜙ\(°_°)/ꜙ that.
// Only tested at 2Mbaud. 1Mbaud should work too. Others not so much.
#if defined(__AVR_ATmega328P__) || defined(__AVR_ATmega328PB__) || \
    defined(__AVR_ATmega328__)  || defined(__AVR_ATmega168__) || \
    defined(__AVR_ATmega168P__) || defined(__AVR_ATmega8__)
#define FAST_ATMEGA
#endif

void setup() {
//  FastLED.addLeds<LED_TYPE, DATA_PIN, COLOR_ORDER>(leds, NUM_LEDS);
//  FastLED.setCorrection(LED_CORRECTION);
//  FastLED.setTemperature(LED_TEMPERATURE);
//  FastLED.setDither(DISABLE_DITHER);
//  FastLED.setBrightness(brightness);
//  FastLED.clear();
//  FastLED.show();
  matrix.addLayer(&backgroundLayer);
#ifdef SCROLLER
  matrix.addLayer(&scrollingLayer);
#endif
  // matrix.setRefreshRate(280);
  matrix.begin();
  backgroundLayer.setBrightness(brightness);
//  backgroundLayer.enableColorCorrection(false);

#ifdef SCROLLER
  scrollingLayer.setMode(wrapForward);
  scrollingLayer.setColor({0x00, 0x7f, 0x00});
  scrollingLayer.setSpeed(128);
  scrollingLayer.setFont(font8x13);
  scrollingLayer.start("10 PRINT \"Hello, World.\" 20 GOTO 10 ||||||||||||||||||||||||", -1);
  scrollingLayer.setOffsetFromTop((kMatrixHeight/2) - 7);
#endif

  myserial_begin(BAUD, RECV_TIMEOUT_MS);
}

void loop() {
  static uint32_t last_frame_ms = millis();
  static uint16_t await_ms = INITIAL_TIMEOUT_MS;
  static uint32_t good_frames = 0;
  static uint32_t bad_frames = 0;

  // if sketch uses swapBuffers(false), wait to get a new backBuffer() pointer after the swap is done:
  // while(backgroundLayer.isSwapPending());

  rgb24 *buffer = backgroundLayer.backBuffer();
  leds = (CRGB *) buffer;

  // periodically send a stats for nerds report
  if ((total_frames & 0xff) == 0xfff) {
    myserial_snprintf(64, "FPS %d b%" PRIu32 " g%" PRIu32 "\t",
                       fps/*FastLED.getFPS()*/, bad_frames, good_frames);
    Serial.print(matrix.getRefreshRate());
    Serial.print(" ");
    Serial.print(matrix.getdmaBufferUnderrunFlag());
    Serial.print(" ");
    Serial.print(matrix.getRefreshRateLoweredFlag());
  }

  // wait for some serial data to arrive
  int16_t in = 0;
  uint32_t ms = millis();
  while (in <= 0 && millis() - ms < await_ms) {
#if !defined(FAST_ATMEGA)
    in = Serial.available();
#else
    in = UCSR0A & (1 << RXC0);
#endif
  }

  // nothing received for a while: fade to black then show screensaver
  if (in <= 0) {
    await_ms = NO_INPUT_AWAIT_MS;
//    Serial.print('s');
    if (millis() - last_frame_ms < SCREENSAVER_MS)
      fadeToBlackBy(leds, NUM_LEDS, 1);
    else
      screensaver();
//    Serial.print('e');
    showLEDs();
//    Serial.println('f');
    return;
  }

  // receive up to NUM_LEDS * 3 bytes, with a timeout
  uint16_t recvd = 0;
  char *dst = (char *) leds;
#if !defined(FAST_ATMEGA)
  recvd = Serial.readBytes( dst, NUM_LEDS * 3);
#else
  ms = millis();
  while (recvd < NUM_LEDS * 3 && millis() - ms < RECV_TIMEOUT_MS) {
    while (!(UCSR0A & (1 << RXC0)) && millis() - ms < RECV_TIMEOUT_MS);
    if ((UCSR0A & (1 << RXC0))) {
      *dst++ = UDR0;
      if (++recvd == NUM_LEDS * 3)
        break;
      ms = millis();
    }
  }
#endif

  // discard any surplus bytes to help with sync
#if !defined(FAST_ATMEGA)
  while (Serial.available() > 0) {
    char tmp;
    Serial.readBytes(&tmp, 1);
    recvd++;
  }
#else
  while (UCSR0A & (1 << RXC0)) {
    uint8_t tmp = UDR0;
    (void) tmp;
    recvd++;
  }
#endif

  // full frame received: show it
  if (recvd == NUM_LEDS * 3) {
    last_frame_ms = millis();
    good_frames++;
    await_ms = FRAME_TIMEOUT_MS;
    showLEDs();
    return;
  }

  // 1-byte commands
  if (recvd == 1) {
    byte * data = (byte *) leds;
    switch (data[0]) {
      case 'B':
        brightness = qadd8(brightness, 1);
        myserial_printint(brightness);
        break;
      case 'b':
        brightness = qsub8(brightness, 1);
        myserial_printint(brightness);
        break;
      case 's':
        screensaver_n = addmod8(screensaver_n, 1, 2);
        myserial_printint(screensaver_n);
        break;
      case '?':
        print_config();
        break;
      case '/':
        myserial_snprintf(64, "FPS %d b%" PRIu32 " g%" PRIu32 "\t",
                          fps, bad_frames, good_frames);
        break;
      case 0:
        // quit screensaver command
        await_ms = FRAME_TIMEOUT_MS;
        return;
        break;
      default:
        break;
    }
    // FastLED.setBrightness(brightness);
    backgroundLayer.setBrightness(brightness);
    return;
  }

  // If we get this far,  we're out-of-sync with the sender.
  // Pause the screensaver for a moment to help to regain sync.
  await_ms = FRAME_TIMEOUT_MS;
  bad_frames++;
  Serial.print('b');
}


void print_config() {
  myserial_snprintf(100,
                    "id:%d xy:%dx%d(%dx%d) o:%dx%d l:%d g:%s t:" STRINGIFY(LED_TYPE) "\r\n",
                    XY_PANELID, XY_WIDTH, XY_HEIGHT, XY_TOTALWIDTH, XY_TOTALHEIGHT,
                    XY_XOFFSET, XY_YOFFSET, XY_LAYOUT, XY_GAMMA);
}


void showLEDs() {
#if !defined(FAST_ATMEGA)
//  digitalWrite(LED_BUILTIN, digitalRead(LED_BUILTIN) ^ 1);
//  FastLED.show();
  backgroundLayer.swapBuffers(true);
//  digitalWrite(LED_BUILTIN, digitalRead(LED_BUILTIN) ^ 1);
#else
//  PORTB ^= 1 << PORTB5;  // toggle pin 13
//  FastLED.show();
//  PORTB ^= 1 << PORTB5;  // toggle pin 13
#endif
  total_frames++;
//  fps = (uint16_t) matrix.countFPS();
}


void screensaver() {
  switch (screensaver_n) {
    case 0:
      for (int i = 0; i < NUM_LEDS; i++)
        leds[i] = 0;
      scrnsvr_leapers();
      break;
    case 1:
      scrnsvr_metaballs();
      break;
  }
}


void myserial_begin(long baud, uint16_t timeout) {
#if !defined(FAST_ATMEGA)
  Serial.begin(baud);
  Serial.setTimeout(timeout);
#else
  (void) timeout;               // suppress unused variable warning
  UBRR0 = F_CPU / 8 / baud - 1; // baud rate pre-scale for U2X == 1
  UCSR0A = 1 << U2X0;           // double speed asynchronous
  UCSR0B |= (1 << TXEN0);       // enable transmit
  UCSR0B |= (1 << RXEN0);       // enable receive
  UCSR0C = 3 << UCSZ00;         // 8-None-1 asynchronous
#endif
}


void myserial_printint(int16_t val) {
  char buffer[9];
  int len = sprintf(buffer, "%d\r\n", val);
  myserial_write(buffer, len);
}


void myserial_println_uint16(uint16_t val) {
  char buffer[8];
  int len = sprintf(buffer, "%u\r\n", val);
  myserial_write(buffer, len);
}


void myserial_write(const char * out, size_t len) {
#if !defined(FAST_ATMEGA)
  Serial.write(out, len);
#else
  while (len-- > 0) {
    while (!(UCSR0A & (1 << UDRE0)));   // wait for USART to be idle
    UDR0 = *out++;
  }
#endif
}


void myserial_snprintf(const uint8_t buf_size, const char *fmt, ...) {
  if (buf_size == 0)
    return;
  char buffer[buf_size];
  va_list args;
  va_start(args, fmt);
  int len = vsnprintf(buffer, buf_size, fmt, args);
  if (len > buf_size - 1)
    len = buf_size - 1;
  myserial_write(buffer, len);
  va_end(args);
}
