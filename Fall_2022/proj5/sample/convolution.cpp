#include "convolution.h"

void convolve_ref(int *A, int *B) {
  int local_in_buffer[MAX_BUFF_SIZE];
  int local_out_buffer[MAX_BUFF_SIZE];
  int kernel[KERNEL_SIZE];

  int dst[IMAGE_SIZE];
  int padded_dst[(TEST_IMG_ROWS + KERNEL_HEIGHT) *
                 (TEST_IMG_COLS + KERNEL_WIDTH)];

  int height = TEST_IMG_COLS;
  int width = TEST_IMG_ROWS;

  int border_height = (KERNEL_HEIGHT - 1) / 2;
  int border_width = (KERNEL_WIDTH - 1) / 2;

  int padd_width = width + 2 * border_width;
  int padd_height = height + 2 * border_height;

  printf("boarder_height:%d border_width:%d\n", border_height, border_width);
  printf("width:%d height:%d padd_width:%d padd_height:%d\n", width, height,
         padd_width, padd_height);

  // initialize kernel
  for (int i = 0; i < KERNEL_SIZE; ++i) {
    kernel[i] = A[i + IMAGE_SIZE];
  }

  // initialize local buffer
  for (int i = 0; i < MAX_BUFF_SIZE; ++i) {
    local_in_buffer[i] = A[i];
  }

  // Clear dst frame buffer
  for (int i = 0; i < height * width; ++i) {
    local_out_buffer[i] = 0;
  }

  for (int i = 0; i < padd_height * padd_width; ++i) {
    padded_dst[i] = 0;
  }

  for (int i = 0; i < height; i++) {
    for (int j = 0; j < width; j++) {
      int pos = i * width + j;
      int new_pos = (i + border_height) * padd_width + (j + border_width);
      padded_dst[new_pos] = local_in_buffer[pos];
    }
  }

  // Horizontal convolution pass - makes O(K*K) reads from input image per
  // output pixel
  for (int row = border_height; row < (height + border_height); ++row) {
    for (int col = border_width; col < (width + border_width); ++col) {
      int dst_loc = (row - border_height) * width + (col - border_width);
      data_t tmp_data = 0;
      for (int i = 0; i < KERNEL_WIDTH; ++i) {
        for (int j = 0; j < KERNEL_HEIGHT; ++j) {
          int src_loc = (row - border_height) * padd_width +
                        (col - border_width) + j + (i)*padd_width;
          int kernel_loc = j + i * KERNEL_HEIGHT;
          tmp_data += padded_dst[src_loc] * kernel[kernel_loc];
        }
      }
      local_out_buffer[dst_loc] = tmp_data;
    }
  }

  for (int i = 0; i < IMAGE_SIZE; ++i) {
    B[i] = local_out_buffer[i];
  }
}

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
  int img_buff[KERNEL_SIZE];
#pragma HLS array_partition variable=kernel
#pragma HLS array_partition variable=img_buff

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
#pragma HLS pipeline
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

CIB:
  for (int i = 0; i < KERNEL_SIZE; i++) {
#pragma HLS unroll
    img_buff[i] = 0;
  }

  // Horizontal convolution pass - makes O(K*K) reads from input image per
  // output pixel
  int unsent = IMAGE_SIZE;
CR:
  for (int row = 0; row < height; ++row) {
  CC:
    for (int col = 0; col < padd_width; ++col) {
#pragma HLS pipeline
      for (int i = 1; i < KERNEL_SIZE; i++) {
#pragma HLS unroll
        img_buff[i-1] = img_buff[i];
      }
      for (int i = 0; i < KERNEL_HEIGHT; i++) {
#pragma HLS unroll
        img_buff[i * KERNEL_WIDTH +2 ] = padded_dst[(row + i) * padd_width + col];
      }
      if (col <= border_width || col - border_width > width) {
        continue;
      }
      data_t acc = 0;
      for (int i = 0; i < KERNEL_SIZE; i++) {
#pragma HLS unroll
        acc += img_buff[i] * kernel[i];
      }
      axi_tmp.data = acc;
      axi_tmp.last = --unsent == 0;
      B.write(axi_tmp);
    }
  }
}
