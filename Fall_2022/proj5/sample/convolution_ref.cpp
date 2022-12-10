#include "convolution.h"

void convolve_ref(int *A, int *B) {
  int local_in_buffer[MAX_BUFF_SIZE];
  int local_out_buffer[MAX_BUFF_SIZE];
  int kernel[KERNEL_SIZE];

  int dst[IMAGE_SIZE];
  int padded_dst[(TEST_IMG_ROWS + KERNEL_HEIGHT) *
                 (TEST_IMG_COLS + KERNEL_WIDTH)];

  int height = TEST_IMG_ROWS;
  int width = TEST_IMG_COLS;

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
