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

#include "convolution.h"
#include <cstdlib>
#include <iostream>

int main() {
  data_t *src_img = new data_t[IMAGE_SIZE];
  data_t *dst_img = new data_t[IMAGE_SIZE];
  data_t *ref_img = new data_t[IMAGE_SIZE];
  data_t *kernel = new data_t[KERNEL_SIZE];
  data_t *send_data = new data_t[MAX_BUFF_SIZE];

  hls::stream<ap_axis<32, 2, 5, 6>> A, B;
  ap_axis<32, 2, 5, 6> axi_tmp;

  const int chkr_size = 5;
  const data_t max_pix_val = 255;
  const data_t min_pix_val = 0;
  int err_cnt = 0;
  int ret_val = 20;

  // Generate the source image with a fixed test pattern - checker-board
  for (int i = 0; i < TEST_IMG_ROWS; ++i) {
    data_t chkr_pair_val[2];
    if ((i / chkr_size) % 2 == 0) {
      chkr_pair_val[0] = max_pix_val;
      chkr_pair_val[1] = min_pix_val;
    } else {
      chkr_pair_val[0] = min_pix_val;
      chkr_pair_val[1] = max_pix_val;
    }
    for (int j = 0; j < TEST_IMG_COLS; ++j) {
      data_t pix_val = chkr_pair_val[(j / chkr_size) % 2];
      src_img[i * TEST_IMG_COLS + j] = pix_val;
    }
  }

  // generate I kernel
  for (int i = 0; i < KERNEL_HEIGHT; ++i) {
    for (int j = 0; j < KERNEL_WIDTH; ++j) {
      int val =
          ((i == (KERNEL_HEIGHT / 2)) && (j == (KERNEL_WIDTH / 2))) ? 1 : 0;
      kernel[i * KERNEL_HEIGHT + j] = val;
      printf("kernel i:%d j:%d val:%d \n", i, j, val);
    }
  }

  // create a data structure to pass to convolve.
  for (int i = 0, j = 0; i < MAX_BUFF_SIZE; ++i) {
    if (i < IMAGE_SIZE) {
      send_data[i] = src_img[i];
    } else {
      send_data[i] = kernel[j++];
    }
  }

  for (int i = 0, j = 0; i < MAX_BUFF_SIZE; ++i) {
    if (i < IMAGE_SIZE) {
      axi_tmp.data = src_img[i];
    } else {
      axi_tmp.data = kernel[j++];
    }
    axi_tmp.keep = 1;
    axi_tmp.strb = 1;
    axi_tmp.user = 1;
    axi_tmp.id = 0;
    axi_tmp.dest = 1;
    axi_tmp.last = (i == (MAX_BUFF_SIZE - 1));
    A.write(axi_tmp);
  }

  convolve_ref(send_data, ref_img);

  convolve_hls(A, B);

  {
    ap_axis<32, 2, 5, 6> axi_tmp;
    int i = 0;
    while (1) {
      B.read(axi_tmp);
      dst_img[i++] = axi_tmp.data.to_int();
      if (axi_tmp.last)
        break;
    }
  }

  // Check DUT vs reference result
  for (int i = 0; i < TEST_IMG_ROWS; ++i) {
    for (int j = 0; j < TEST_IMG_COLS; ++j) {
      data_t dst_val = dst_img[i * TEST_IMG_COLS + j];
      data_t ref_val = ref_img[i * TEST_IMG_COLS + j];
#if 0
            std::cout << "i:" << i;
            std::cout <<"  j:" <<j;
            std::cout <<"  " ;
            std::cout <<" orig_val: " << orig_val; 
            std::cout <<" ref_val: " << ref_val;
            std::cout << std::endl;
#endif
      if (dst_val != ref_val) {
        ++err_cnt;
#if 0
                std::cout << "!!! ERROR: Mismatch detected at coord(" << i;
                std::cout << ", " << j << " ) !!!";
                std::cout << std::endl;
#endif
      }
    }
  }

  std::cout << std::endl;

  if (err_cnt == 0) {
    std::cout << "*** TEST PASSED ***" << std::endl;
    ret_val = 0;
  } else {
    std::cout << "!!! TEST FAILED - " << err_cnt << " mismatches detected !!!";
    std::cout << std::endl;
    ret_val = -1;
  }

  delete[] src_img;
  delete[] dst_img;
  delete[] ref_img;
  delete[] send_data;
  delete[] kernel;

  return ret_val;
}
