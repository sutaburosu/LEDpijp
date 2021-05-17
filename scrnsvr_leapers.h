// a quick hack I did for my cakeday
// https://www.reddit.com/r/FastLED/comments/h7s96r/

#ifndef SCRNSVR_LEAPERS_H
#define SCRNSVR_LEAPERS_H
#include "XYmatrix.h"

#define NUM_LEAPERS       16
#define GRAVITY           10
#define SETTLED_THRESHOLD 72
#define WALL_FRICTION     248  // 255 is no friction
#define DRAG              240  // 255 is no wind resistance

typedef struct {
  int16_t x, y, xd, yd;
} Leaper;
Leaper leapers[NUM_LEAPERS];

extern "C" {
  void restart_leaper(Leaper * lpr);
  void move_leaper(Leaper * lpr);
}
void wu_pixel(uint32_t x, uint32_t y, CRGB * col);

void leapers_setup() {
  for (uint8_t lpr = 0; lpr < NUM_LEAPERS; lpr++)
    leapers[lpr].x = XY_TOTALWIDTH * 256 / 2 ;
}

void scrnsvr_leapers() {
  static bool done_setup = false;
  if (!done_setup) {
    done_setup = true;
    leapers_setup();
  }
  // FastLED.clear();
  // fadeToBlackBy(leds, NUM_LEDS, 32);
  for (uint8_t lpr = 0; lpr < NUM_LEAPERS; lpr++) {
    move_leaper(&leapers[lpr]);
    CHSV hue = CHSV(lpr * 255 / NUM_LEAPERS, 255, 255);
    CRGB rgb;
    hsv2rgb_rainbow(hue, rgb);
    wu_pixel(leapers[lpr].x, leapers[lpr].y, &rgb);
  }
}

void restart_leaper(Leaper * lpr) {
  // leap up and to the side with some random component
  lpr->xd = random8() + XY_TOTALWIDTH * 2;
  lpr->yd = random8() + XY_TOTALHEIGHT * 16;

  // for variety, sometimes go 50% faster
  if (random8() < 12) {
    lpr->xd += lpr->xd >> 1;
    lpr->yd += lpr->yd >> 1;
  }

  // leap towards the centre of the screen
  if (lpr->x > (XY_TOTALWIDTH / 2 * 256)) {
    lpr->xd = -lpr->xd;
  }
}

void move_leaper(Leaper * lpr) {
  // add the X & Y velocities to the position
  lpr->x += lpr->xd;
  lpr->y += lpr->yd;

  // bounce off the floor and ceiling?
  if (lpr->y <= 0 || lpr->y >= ((XY_TOTALHEIGHT - 1) << 8)) {
    lpr->xd = ((int32_t)  lpr->xd * WALL_FRICTION) >> 8;
    lpr->yd = ((int32_t) -lpr->yd * WALL_FRICTION) >> 8;
    if (lpr->y <= 0)
      lpr->y = -lpr->y;
    else
      lpr->y = ((2 * XY_TOTALHEIGHT - 1) << 8) - lpr->y;
    // settled on the floor?
    if (lpr->y <= SETTLED_THRESHOLD && abs(lpr->yd) <= SETTLED_THRESHOLD) {
      restart_leaper(lpr);
    }
  }

  // bounce off the sides of the screen?
  if (lpr->x <= 0 || lpr->x >= (XY_TOTALWIDTH - 1) << 8) {
    lpr->xd = ((int32_t) -lpr->xd * WALL_FRICTION) >> 8;
    lpr->yd = ((int32_t)  lpr->yd * WALL_FRICTION) >> 8;
    if (lpr->x <= 0) {
      lpr->x = -lpr->x;
    } else {
      lpr->x = ((2 * XY_TOTALWIDTH - 1) << 8) - lpr->x;
    }
  }

  // gravity
  lpr->yd -= GRAVITY;

  // viscosity,  done badly
  // uint32_t speed2 = lpr->xd * lpr->xd + lpr->yd * lpr->yd;
  lpr->xd = ((int32_t) lpr->xd * DRAG) >> 8;
  lpr->yd = ((int32_t) lpr->yd * DRAG) >> 8;
}

// x and y are 24.8 fixed point
// Not Ray Wu. ;)  The idea came from Xiaolin Wu.
void wu_pixel(uint32_t x, uint32_t y, CRGB * col) {
  // extract the fractional parts and derive their inverses
  uint8_t xx = x & 0xff, yy = y & 0xff, ix = 255 - xx, iy = 255 - yy;
  // calculate the intensities for each affected pixel
  #define WU_WEIGHT(a,b) ((uint8_t) (((a)*(b)+(a)+(b))>>8))
  uint8_t wu[4] = {WU_WEIGHT(ix, iy), WU_WEIGHT(xx, iy),
                   WU_WEIGHT(ix, yy), WU_WEIGHT(xx, yy)};
  // multiply the intensities by the colour, and saturating-add them to the pixels
  for (uint8_t i = 0; i < 4; i++) {
    uint16_t xy = XYtile((x >> 8) + (i & 1), (y >> 8) + ((i >> 1) & 1));
    leds[xy].r = qadd8(leds[xy].r, col->r * wu[i] >> 8);
    leds[xy].g = qadd8(leds[xy].g, col->g * wu[i] >> 8);
    leds[xy].b = qadd8(leds[xy].b, col->b * wu[i] >> 8);
  }
}

#endif
