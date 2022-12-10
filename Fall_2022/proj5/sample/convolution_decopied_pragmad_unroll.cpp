#include "convolution.h"

void convolve_hls(hls::stream<ap_axis<32, 2, 5, 6>> &A,
                  hls::stream<ap_axis<32, 2, 5, 6>> &B) {
#pragma HLS INTERFACE axis port = A
#pragma HLS INTERFACE axis port = B
#pragma HLS INTERFACE s_axilite port = return

  ap_axis<32, 2, 5, 6> axi_tmp;

  int width = TEST_IMG_COLS;
  int height = TEST_IMG_ROWS;

  int border_height = (KERNEL_HEIGHT - 1) / 2;
  int border_width = (KERNEL_WIDTH - 1) / 2;

  int padd_width = width + 2 * border_width;
  int padd_height = height + 2 * border_height;

  int kernel[KERNEL_SIZE];
  int padded_dst[padd_width * padd_height];

RI: // receive image
  for (int r = border_height; r < (height + border_height); r++) {
    for (int c = border_width; c < (width + border_width); c++) {
#pragma HLS loop_flatten
#pragma HLS pipeline
      int index = r * padd_width + c;
      A.read(axi_tmp);
      padded_dst[index] = axi_tmp.data.to_int();
    }
  }
RK: // receive kernel
  for (int i = 0; i < KERNEL_SIZE; i++)  {
    A.read(axi_tmp);
    kernel[i] = axi_tmp.data.to_int();
  }
  int last = padd_width * padd_height - 1;
CHB: // clear horizontal borders
  for (int i = 0; i < padd_width * border_height; i++) {
    padded_dst[i] = 0;
    padded_dst[last - i] = 0;
  }
CVB: // clear vertical borders
  for (int r = 0; r < padd_height; r++) {
    for (int c = 0; c < border_width; c++) {
#pragma HLS loop_flatten
      int i = r * padd_width + c;
      padded_dst[i] = 0;
      padded_dst[last - i] = 0;
    }
  }

  // Horizontal convolution pass - makes O(K*K) reads from input image per
  // output pixel
  int unsent = IMAGE_SIZE;
CR:
  for (int row = 0; row < height; ++row) {
  CC:
    for (int col = 0; col < width; ++col) {
#pragma HLS pipeline
      data_t tmp_data = 0;
    KH:
      for (int i = 0; i < KERNEL_WIDTH; ++i) {
      KW:
        for (int j = 0; j < KERNEL_HEIGHT; ++j) {
#pragma HLS loop_flatten
#pragma HLS unroll
          int src_loc = row  * padd_width +
                        col + j + i * padd_width;
          int kernel_loc = j + i * KERNEL_HEIGHT;
          tmp_data += padded_dst[src_loc] * kernel[kernel_loc];
        }
      }
      axi_tmp.data = tmp_data;
      axi_tmp.last = --unsent == 0;
      B.write(axi_tmp);
    }
  }
}
