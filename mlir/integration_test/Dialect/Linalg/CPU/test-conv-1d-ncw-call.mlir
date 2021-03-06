// RUN: mlir-opt %s -convert-linalg-to-loops -convert-linalg-to-llvm -convert-std-to-llvm | \
// RUN: mlir-cpu-runner -e main -entry-point-result=void \
// RUN:   -shared-libs=%mlir_integration_test_dir/libmlir_runner_utils%shlibext \
// RUN: | FileCheck %s

// RUN: mlir-opt %s -linalg-tile="linalg-tile-sizes=0,0,4" -convert-linalg-to-loops \
// RUN:   -convert-linalg-to-llvm -convert-std-to-llvm | \
// RUN: mlir-cpu-runner -e main -entry-point-result=void \
// RUN:   -shared-libs=%mlir_integration_test_dir/libmlir_runner_utils%shlibext \
// RUN: | FileCheck %s

// RUN: mlir-opt %s -test-conv-vectorization -convert-linalg-to-llvm | \
// RUN: mlir-cpu-runner -e main -entry-point-result=void \
// RUN:   -shared-libs=%mlir_integration_test_dir/libmlir_runner_utils%shlibext \
// RUN: | FileCheck %s

// RUN: mlir-opt %s -linalg-tile="linalg-tile-sizes=0,0,4" \
// RUN:   -test-conv-vectorization -convert-linalg-to-llvm | \
// RUN: mlir-cpu-runner -e main -entry-point-result=void \
// RUN:   -shared-libs=%mlir_integration_test_dir/libmlir_runner_utils%shlibext \
// RUN: | FileCheck %s

func @print_memref_f32(memref<*xf32>)

// Creates and returns 3-D buffer of size (%s1, %s2, %s3) filled with the value %f
func @alloc_3d_filled_f32(%s1 : index, %s2 : index, %s3 : index, %f : f32) -> memref<?x?x?xf32> {
  %buf = alloc(%s1, %s2, %s3) : memref<?x?x?xf32>
  linalg.fill(%buf, %f) : memref<?x?x?xf32>, f32
  return %buf : memref<?x?x?xf32>
}

func @conv_1d_ncw(%arg0: memref<?x?x?xf32>, %arg1: memref<?x?x?xf32>, %arg2: memref<?x?x?xf32>) {
  linalg.conv_1d_ncw ins (%arg0, %arg1: memref<?x?x?xf32>, memref<?x?x?xf32>)
                    outs (%arg2: memref<?x?x?xf32>)
  return
}

func @main() {
  %c0 = constant 0 : index
  %c1 = constant 1 : index
  %c3 = constant 3 : index
  %c6 = constant 6 : index
  %c8 = constant 8 : index
  %f10 = constant 10.00000e+00 : f32
  %val = constant 2.00000e+00 : f32
  %zero = constant 0.00000e+00 : f32

  %filter1D_ncw = call @alloc_3d_filled_f32(%c1, %c1, %c3, %val) : (index, index, index, f32) -> (memref<?x?x?xf32>)
  %in1D_ncw = call @alloc_3d_filled_f32(%c1, %c1, %c8, %val) : (index, index, index, f32) -> (memref<?x?x?xf32>)
  %out1D_ncw = call @alloc_3d_filled_f32(%c1, %c1, %c6, %zero) : (index, index, index, f32) -> (memref<?x?x?xf32>)

  store %f10, %in1D_ncw[%c0, %c0, %c3] : memref<?x?x?xf32>
  call @conv_1d_ncw(%in1D_ncw, %filter1D_ncw, %out1D_ncw) : (memref<?x?x?xf32>, memref<?x?x?xf32>, memref<?x?x?xf32>) -> ()
  %out1D_ncw_ = memref_cast %out1D_ncw : memref<?x?x?xf32> to memref<*xf32>
  call @print_memref_f32(%out1D_ncw_): (memref<*xf32>) -> ()

  dealloc %filter1D_ncw : memref<?x?x?xf32>
  dealloc %in1D_ncw : memref<?x?x?xf32>
  dealloc %out1D_ncw : memref<?x?x?xf32>
  return
}

// CHECK:       Unranked Memref {{.*}}
// CHECK-NEXT:  [
// CHECK-SAME:   [
// CHECK-SAME:    [12, 28, 28, 28, 12, 12]
// CHECK-SAME:   ]
// CHECK-SAME:  ]
