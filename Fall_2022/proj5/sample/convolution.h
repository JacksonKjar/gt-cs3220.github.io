/*
 * Copyright 2020 Xilinx, Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#ifndef CONVOLUTION_H_
#define CONVOLUTION_H_

#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include "hls_stream.h"
#include "ap_axi_sdata.h"

// uncomment to enable debugging
//#define DEBUG

#define KERNEL_HEIGHT 3
#define KERNEL_WIDTH  3

#define TEST_IMG_ROWS 100
#define TEST_IMG_COLS 100
//#define TEST_IMG_ROWS 5
//#define TEST_IMG_COLS 5

#define IMAGE_SIZE    (TEST_IMG_COLS * TEST_IMG_ROWS) // need to match with jupyter size
#define KERNEL_SIZE   (KERNEL_WIDTH * KERNEL_HEIGHT)  // need to match with jupyter size
#define MAX_BUFF_SIZE (IMAGE_SIZE + KERNEL_SIZE)

typedef int32_t data_t;

void convolve_ref (int *A, int *B);

void convolve_hls (hls::stream<ap_axis<32,2,5,6>> &A, hls::stream<ap_axis<32,2,5,6>> &B);

#endif // CONVOLUTION_H_ not defined
