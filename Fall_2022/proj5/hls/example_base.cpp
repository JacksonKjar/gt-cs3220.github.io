#include "ap_axi_sdata.h"
#include "hls_stream.h"

#include "convolution.h"

void example(hls::stream<ap_axis<32, 2, 5, 6>> &A,
             hls::stream<ap_axis<32, 2, 5, 6>> &B) {
#pragma HLS INTERFACE axis port = A
#pragma HLS INTERFACE axis port = B
#pragma HLS INTERFACE s_axilite port = return

  int local_in_buffer[MAX_BUFF_SIZE];
  int local_out_buffer[MAX_BUFF_SIZE];
  int kernel[KERNEL_SIZE];

  int padded_dst[(TEST_IMG_ROWS + KERNEL_HEIGHT) *
                 (TEST_IMG_COLS + KERNEL_WIDTH)];

  int height = TEST_IMG_COLS;
  int width = TEST_IMG_ROWS;

  int border_height = (KERNEL_HEIGHT - 1) / 2;
  int border_width = (KERNEL_WIDTH - 1) / 2;

#if DEBUG
  printf("boarder_height:%d border_width:%d\n", border_height, border_width);
#endif

  int padd_height = height + 2 * border_height;
  int padd_width = width + 2 * border_width;
#if DEBUG
  printf("width:%d height:%d padd_width:%d padd_height:\%d\n", width, height,
         padd_width, padd_height);
#endif

KERNEL_INIT: // initialize to identity matrix
  for (int i = 0; i < KERNEL_SIZE; i++) {
    kernel[i] = i == 4 ? 1 : 0;
  }

  ap_axis<32, 2, 5, 6> axis;
  int count = 0;

RECEIVING_INPUT_IMAGE: // receive image from input stream
  for (int i = 0; i < IMAGE_SIZE; i++) {
    A.read(axis);
    local_in_buffer[i] = axis.data.to_int();
  }

RECEIVING_INPUT_KERNEL: // receive kernel from input stream
  for (int i = 0; i < KERNEL_SIZE; i++) {
    A.read(axis);
    kernel[i] = axis.data.to_int();
  }
    /*
    if (axis.last == 1)
      break;
      */

  /*******************************************************/


  // Clear dst frame buffer
CLEAR_DST:
  for (int i = 0; i < height * width; i++) {
    local_out_buffer[i] = 0;
  }
CLEAR_PADDED:
  for (int i = 0; i < padd_height * padd_width; i++) {
    padded_dst[i] = 0;
  }
PADD_I:
  for (int i = 0; i < height; i++) {
  PADD_J:
    for (int j = 0; j < width; j++) {
      int pos = i * width + j;
      int new_pos = (i + border_height) * padd_width + (j + border_width);
      padded_dst[new_pos] = local_in_buffer[pos];

#if DEBUG
      printf("[%d] [%d] goes into [%d][%d], orig_pos:%d new_pos:%d \n", i, j,
             (i + border_height), (j + border_width), pos, new_pos);
#endif
    }
  }
  // pad images

  // Horizontal convolution pass - makes O(K*K) reads from input image
  // per output pixel
CONV_R:
  for (int row = border_height; row < height + border_height; row++) {
  CONV_C:
    for (int col = border_width; col < width + border_width; col++) {
      int pixel = (row - border_height) * width + (col - border_width);
#if DEBUG
      printf("col:%d row:%d output pixel loc is %d:\n ", col, row, pixel);
#endif

      data_t acc = 0;
    KERNEL_H:
      for (int i = 0; i < KERNEL_WIDTH; i++) {
      KERNEL_W:
        for (int j = 0; j < KERNEL_HEIGHT; j++) {

          int src_loc = (row - border_height) * padd_width +
                        (col - border_width) + j + (i)*padd_width;
          int kernel_loc = j + i * KERNEL_HEIGHT;

          acc += padded_dst[src_loc] * kernel[kernel_loc];
#if DEBUG
          printf(
              "output[%d]:%d += padded[%d]:%d * kernel[%d]:%d  src[%d]:%d \n",
              pixel, local_out_buffer[pixel], src_loc, padded_dst[src_loc], kernel_loc,
              kernel[kernel_loc], pixel, src[pixel]);
#endif
        }
      }
      local_out_buffer[pixel] = acc;
#if DEBUG
      printf("==============\n");
#endif
    }
  }

  axis.last = 0;
SENDING_OUTPUT:
  for (int i = 0; i < IMAGE_SIZE; i++) {
      axis.data = local_out_buffer[i];
      axis.last = i == (IMAGE_SIZE - 1);
      B.write(axis);
  }
}
