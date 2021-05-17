#ifndef XYMATRIX_H
#define XYMATRIX_H
#define FASTLED_INTERNAL 0  // suppress FastLED version info during build
#include <FastLED.h>

// Set all the config below properly, and then you need only
// change this before uploading to each MCU
#define XY_PANELID        0

// Configuration for the LED panel attached to this MCU
#define LED_TYPE          SMARTMATRIX
#define DATA_PIN          2
#define COLOR_ORDER       GRB
#define XY_WIDTH          128
#define XY_HEIGHT         64
//#define XY_LAYOUT         (SERPENTINE | ROWMAJOR)
#define XY_LAYOUT         (ROWMAJOR | FLIPMINOR)
#define BRIGHTNESS        64
#define LED_CORRECTION    UncorrectedColor
#define LED_TEMPERATURE   UncorrectedTemperature

// Gamma correction for PANELID 0, 1, 2, 3, etc.
const char* XY_PANELID_GAMMA[] = {
  "1.0", "1.8", "1.8", "1.8",
};

// Automatically (1) or manually (0) position each panel
#if 1
  // Automatically place same-sized panels in raster order.
  // Set XPANELS to 3 and YPANELS to 2, and the PANELIDs will be layed out like:
  //   3  4  5
  //   0  1  2
  #define XY_XPANELS      1
  #define XY_YPANELS      1
  
#else
  // Place each panel manually.  Set the total width and height, and offset
  // each panel within that space.  Gaps and overlaps work fine.
  // Different shaped panels should work too, but only if NUM_LEDS is the same.

  // Positive numbers on the Y axis mean up: bottom-left is (0, 0)

  // three 16x16 panels arranged diagonally,  each overlapping by 4x4 pixels
  #define XY_TOTALWIDTH   40
  #define XY_TOTALHEIGHT  40
  #if   (XY_PANELID == 0)
    #define XY_XOFFSET    0
    #define XY_YOFFSET    0
  #elif (XY_PANELID == 1)
    #define XY_XOFFSET    12
    #define XY_YOFFSET    12
  #elif (XY_PANELID == 2)
    #define XY_XOFFSET    24
    #define XY_YOFFSET    24
  #else
    #error "Missing XY_PANELID offsets in XYmatrix.h"
  #endif
#endif

// end of configuration

#if defined(XY_XPANELS)
  // complete the automatic layout
  #define XY_XPANEL       ((XY_PANELID) % (XY_XPANELS))
  #define XY_YPANEL       ((XY_PANELID) / (XY_XPANELS))
  #define XY_TOTALWIDTH   ((XY_XPANELS) * (XY_WIDTH))
  #define XY_TOTALHEIGHT  ((XY_YPANELS) * (XY_HEIGHT))
  #define XY_XOFFSET      (XY_XPANEL * (XY_WIDTH))
  #define XY_YOFFSET      (XY_YPANEL * (XY_HEIGHT))
#endif

#if (((XY_XOFFSET) + (XY_WIDTH) > XY_TOTALWIDTH) || \
     ((XY_YOFFSET) + (XY_HEIGHT) > XY_TOTALHEIGHT))
  #error "Panel size + offset exceeds TOTALWIDTH or TOTALHEIGHT.  Check your layout in XYmatrix.h"
#endif

#define XY_GAMMA          XY_PANELID_GAMMA[XY_PANELID]
#define STRINGIFY(a)      _STRINGIFY(a)
#define _STRINGIFY(a)     #a

#define NUM_LEDS ((XY_WIDTH) * (XY_HEIGHT))
// 1 extra for XY() to use when out-of-bounds
CRGB *leds; //[NUM_LEDS + 1];

enum XY_layout {
  // I think TRANSPOSE is only useful to rotate square panels
  SERPENTINE = 16, ROWMAJOR = 8, TRANSPOSE = 4, FLIPMAJOR = 2, FLIPMINOR = 1
};

uint16_t XY(uint8_t x, uint8_t y) {
  uint8_t major, minor, sz_major, sz_minor;
  if (x >= XY_WIDTH || y >= XY_HEIGHT)
    return 0; //NUM_LEDS;
  if (XY_LAYOUT & ROWMAJOR)
    major = x, minor = y, sz_major = XY_WIDTH,  sz_minor = XY_HEIGHT;
  else
    major = y, minor = x, sz_major = XY_HEIGHT, sz_minor = XY_WIDTH;
  if ((XY_LAYOUT & FLIPMAJOR) ^ (minor & 1 && (XY_LAYOUT & SERPENTINE)))
    major = sz_major - 1 - major;
  if (XY_LAYOUT & FLIPMINOR)
    minor = sz_minor - 1 - minor;
  if (XY_LAYOUT & TRANSPOSE)
    return major * (uint16_t) sz_major + minor;
  else
    return minor * (uint16_t) sz_major + major;
}

// 0,0 is bottom-left
uint16_t XYtile(uint8_t x, uint8_t y) {
  #pragma GCC diagnostic push
  #pragma GCC diagnostic ignored "-Wtype-limits"
  if (x < XY_XOFFSET || y < XY_YOFFSET)
    return 0; //NUM_LEDS;
  #pragma GCC diagnostic pop
  return XY(x - XY_XOFFSET, y - XY_YOFFSET);
}

// // 0,0 is top-left
// // derive the offset in Processing's coordinate system
// #define XY_YOFFSET_TL     ((XY_TOTALHEIGHT) - (XY_HEIGHT) - (XY_YOFFSET))
// uint16_t XYtiletl(uint8_t x, uint8_t y) {
//   #pragma GCC diagnostic push
//   #pragma GCC diagnostic ignored "-Wtype-limits"
//   if (x < XY_XOFFSET || y < XY_YOFFSET_TL)
//     return NUM_LEDS;
//   #pragma GCC diagnostic pop
//   return XY(x - XY_XOFFSET, y - XY_YOFFSET_TL);
// }

#endif
