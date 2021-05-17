// Thanks to Yaroslaw Turbin for the inspiration
// https://www.reddit.com/r/FastLED/comments/hv77xm/

#ifndef SCRNSVR_METABALLS_H
#define SCRNSVR_METABALLS_H
#include "XYmatrix.h"

#define MAX_RADIUS (int(ceil(sqrt(pow(XY_TOTALWIDTH, 2) + pow(XY_TOTALHEIGHT, 2)))))

DEFINE_GRADIENT_PALETTE(lava) {
    0, 255,   0,   0,
   32,   0,   0,   0,
   64,  32,  16,   0,
   96,  48,  32,   0,
  128,  96,  60,   0,
  160, 128, 128,   0,
  255, 255, 255, 255,
};

//CRGBPalette16 mbPal = lava; uint8_t constrain_val = 240; uint8_t colour_cycle = 0;
 CRGBPalette16 mbPal = RainbowStripeColors_p; uint8_t constrain_val = 255; uint8_t colour_cycle = 1;
// CRGBPalette16 mbPal = HeatColors_p; uint8_t constrain_val = 240; uint8_t colour_cycle = 0;

// leds[] is used as a temporary buffer during rendering
using buffer_type = uint8_t;
using pixel_func = void (*) (uint8_t r, buffer_type *dst);
extern uint32_t total_frames;
uint8_t* recip;

// functions used to write into the buffer
void set(uint8_t r, buffer_type *dst)        { *dst = r; }
void set_div(uint8_t r, buffer_type *dst)    { *dst = recip[r]; }
void set_2div(uint8_t r, buffer_type *dst)   { *dst = 2 * recip[r]; }
void add(uint8_t r, buffer_type *dst)        { *dst += r; }
void add_div(uint8_t r, buffer_type *dst)    { *dst += recip[r]; }
void add_2div(uint8_t r, buffer_type *dst)   { *dst += 2 * recip[r]; }
void sub(uint8_t r, buffer_type *dst)        { *dst -= r; }
void sub_div(uint8_t r, buffer_type *dst)    { *dst -= recip[r]; }
void sub_2div(uint8_t r, buffer_type *dst)   { *dst -= 2 * recip[r]; }
void qadd(uint8_t r, buffer_type *dst)       { *dst = qadd8(*dst, r); }
void qadd_div(uint8_t r, buffer_type *dst)   { *dst = qadd8(*dst, recip[r]); }
void qadd_2div(uint8_t r, buffer_type *dst)  { *dst = qadd8(*dst, 2 * recip[r]); }
void qsub(uint8_t r, buffer_type *dst)       { *dst = qsub8(*dst, r); }
void qsub_div(uint8_t r, buffer_type *dst)   { *dst = qsub8(*dst, recip[r]); }
void qsub_2div(uint8_t r, buffer_type *dst)  { *dst = qsub8(*dst, 2 * recip[r]); }
void mul_div(uint8_t r, buffer_type *dst)    { *dst = (recip[r] * *dst) >> 8; }

typedef struct {
  uint8_t xbpm, ybpm;
  pixel_func emit_pixel;
} Ball;

// try using different functions instead of qadd_div
// always use 'set...' first; the buffer isn't zeroed before use
Ball balls[] = {
  {36, 36, set_div},
  {56, 46, qadd_div},
  {60, 48, qadd_div},
  {34, 50, qadd_div},
  {38, 42, qadd_div},
//  {36, 42, qadd_div},
//  {34, 46, qadd_div},
//  {40, 42, qadd_div},
};

// visits each pixel in raster order whilst maintaining xroot == √(x² + y²)
// using only a single sqrt() per frame rather than one per pixel.
void radial_fill(int8_t x_offset, int8_t y_offset, pixel_func emit_pixel) {
  uint8_t screenx, screeny;
  uint8_t xroot, yroot;
  uint16_t xsumsquares, ysumsquares, xnextsquare, ynextsquare;
  int8_t x, y;

  // offset the origin in screen space
  y = y_offset;
  ysumsquares = x_offset * x_offset + y * y;
  yroot = sqrt16(ysumsquares);
  ynextsquare = yroot * yroot;

  // Quadrant II (top left)
  screeny = 0;
  while (y < 0 && screeny < XY_HEIGHT) {
    // uint8_t xy0 = XY(0, XY_HEIGHT - screeny);
    // int8_t xydx = XY(1, XY_HEIGHT - screeny) - xy0;
    // CRGB* dst = &leds[xy0];
    x = x_offset;
    screenx = 0;
    xsumsquares = ysumsquares;
    xroot = yroot;
    if (x < 0) {
      xnextsquare = xroot * xroot;
      while (x < 0 && screenx < XY_WIDTH) {
        // emit_pixel(xroot, (buffer_type *) dst); dst += xydx;
        emit_pixel(xroot, (buffer_type *) &leds[XY(screenx, screeny)]);
        xsumsquares += 2 * x++ + 1;
        if (xsumsquares < xnextsquare)
          xnextsquare -= 2 * xroot-- - 1;
        screenx++;
      }
    }
    // Quadrant I (top right)
    if (screenx < XY_WIDTH) {
      xnextsquare = (xroot + 1) * (xroot + 1);
      while (screenx < XY_WIDTH) {
        // emit_pixel(xroot, (buffer_type *) dst); dst += xydx;
        emit_pixel(xroot, (buffer_type *) &leds[XY(screenx, screeny)]);
        xsumsquares += 2 * x++ + 1;
        if (xsumsquares >= xnextsquare)
          xnextsquare += 2 * ++xroot + 1;
        screenx++;
      }
    }
    ysumsquares += 2 * y++ + 1;
    if (ysumsquares < ynextsquare)
      ynextsquare -= 2 * yroot-- - 1;
    screeny++;
  }
  // Quadrant III (bottom left)
  ynextsquare = (yroot + 1) * (yroot + 1);
  while (screeny < XY_HEIGHT) {
    // uint8_t xy0 = XY(0, XY_HEIGHT - screeny);
    // int8_t xydx = XY(1, XY_HEIGHT - screeny) - xy0;
    // CRGB* dst = &leds[xy0];
    x = x_offset;
    screenx = 0;
    xsumsquares = ysumsquares;
    xroot = yroot;
    if (x < 0) {
      xnextsquare = xroot * xroot;
      while (x < 0 && screenx < XY_WIDTH) {
        // emit_pixel(xroot, (buffer_type *) dst); dst += xydx;
        emit_pixel(xroot, (buffer_type *) &leds[XY(screenx, screeny)]);
        xsumsquares += 2 * x++ + 1;
        if (xsumsquares < xnextsquare)
          xnextsquare -= 2 * xroot-- - 1;
        screenx++;
      }
    }
    // Quadrant IV (bottom right)
    if (screenx < XY_WIDTH) {
      xnextsquare = (xroot + 1) * (xroot + 1);
      while (screenx < XY_WIDTH) {
        // emit_pixel(xroot, (buffer_type *) dst); dst += xydx;
        emit_pixel(xroot, (buffer_type *) &leds[XY(screenx, screeny)]);
        xsumsquares += 2 * x++ + 1;
        if (xsumsquares >= xnextsquare)
          xnextsquare += 2 * ++xroot + 1;
        screenx++;
      }
    }
    ysumsquares += 2 * y++ + 1;
    if (ysumsquares >= ynextsquare)
      ynextsquare += 2 * ++yroot + 1;
    screeny++;
  }
}

void scrnsvr_metaballs() {
  // animate a lookup table of field intensity at each radius
  uint8_t beat = beatsin8(30, 1, 255);
  static uint8_t recipLUT[MAX_RADIUS];
  for (uint16_t i = 0; i < MAX_RADIUS; i++)
    recipLUT[i] = beat / (i + 1);

  // apply each ball's field to the temp buffer in leds[]
  uint8_t phase = 0;
  uint8_t num_balls = sizeof(balls) / sizeof(Ball);
  for (uint8_t ball = 0; ball < num_balls; ball++) {
    int8_t bx = -beatsin8(balls[ball].xbpm, 0, XY_TOTALWIDTH  - 1, 0, phase);
    int8_t by = -beatsin8(balls[ball].ybpm, 0, XY_TOTALHEIGHT - 1, 0, phase + 64);
    recip = recipLUT;// + ball * 1;
    radial_fill(bx + XY_XOFFSET, by + XY_YOFFSET, balls[ball].emit_pixel);
    phase += 48;
  }

  // convert the intermediate buffer to CRGB
  uint8_t cycle = colour_cycle * total_frames;
  CRGB *pixel = leds;
  for (uint16_t i = 0; i < NUM_LEDS; i++) {
    buffer_type col = *((buffer_type *) pixel);
    if (col > constrain_val)
      col = constrain_val;
    *pixel++ = ColorFromPalette(mbPal, col + cycle, 255);
  }
}

#endif
