#ifndef COMMON_HEADER_H
#define COMMON_HEADER_H

#include <cassert>
#include <iostream>
#include <fstream>
#include <cmath>
#include <algorithm>
#include <vector>
#include <string>
#include <sstream>

#define NS_PRIVATE_IMPLEMENTATION
#define MTL_PRIVATE_IMPLEMENTATION
#define MTK_PRIVATE_IMPLEMENTATION
#define CA_PRIVATE_IMPLEMENTATION
#include <Metal/Metal.hpp>
#include <AppKit/AppKit.hpp>
#include <MetalKit/MetalKit.hpp>

#include "Renderer.h"
#include "MyMTKViewDelegate.h"
#include "MyAppDelegate.h"

#include <simd/simd.h>

#endif