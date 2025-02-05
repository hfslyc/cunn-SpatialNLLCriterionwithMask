#ifndef THC_GENERIC_FILE
#define THC_GENERIC_FILE "generic/SpatialNLLCriterionWithMask.cu"
#else

void THNN_(SpatialNLLCriterionWithMask_updateOutput)(
           THCState *state,
           THCTensor *input,
           THCIndexTensor *target,
           THCTensor *valid_mask,
           THCTensor *output,
           bool sizeAverage,
           THCTensor *weights,
           THCTensor *total_weight)
{
  THArgCheck(THCIndexTensor_(nDimension)(state, target) == 3, 1,
             "only batches of spatial targets supported (3D tensors)" \
             " but got targets of dimension: %d",
             THCIndexTensor_(nDimension)(state, target));
  THArgCheck(THCTensor_(nDimension)(state, input) == 4, 2,
             "only batches of spatial inputs supported (4D tensors), "      \
             "but got input of dimension: %d", THCTensor_(nDimension)(state, input));

  if (weights && THCTensor_(nElement)(state, weights) != THCTensor_(size)(state, input, 1)) {
    THError("weight tensor should be defined either for all or no classes");
  }

  if (weights)
    THCUNN_assertSameGPU(state, 5, input, target, weights, output, total_weight);
  else
    THCUNN_assertSameGPU(state, 4, input, target, output, total_weight);

  input = THCTensor_(newContiguous)(state, input);
  weights = weights ? THCTensor_(newContiguous)(state, weights) : NULL;
  target = THCIndexTensor_(newContiguous)(state, target);
  valid_mask = THCTensor_(newContiguous)(state, valid_mask);

  real *input_data = THCTensor_(data)(state, input);
  real *weights_data = weights ? THCTensor_(data)(state, weights) : NULL;
  THCIndex_t  *target_data = THCIndexTensor_(data)(state, target);
  real *valid_mask_data = THCTensor_(data)(state, valid_mask);
  real *output_data = THCTensor_(data)(state, output);
  real *total_weight_data = THCTensor_(data)(state, total_weight);

  THCIndex_t batch_size = THCIndexTensor_(size)(state, target, 0);
  THCIndex_t map_nelem = THCIndexTensor_(nElement)(state, target) / batch_size;
  int blocks_per_sample = GET_BLOCKS(map_nelem) / 128;
  blocks_per_sample = (blocks_per_sample == 0) ? 1 : blocks_per_sample;
  int total_blocks = blocks_per_sample * batch_size;

  THCTensor_(fill)(state, output, ScalarConvert<int, real>::to(0));
  THCTensor_(fill)(state, total_weight, ScalarConvert<int, real>::to(0));

  cunn_SpatialNLLCriterionWithMask_updateOutput_kernel<real, accreal>
    <<<total_blocks, CUDA_NUM_THREADS, 0, THCState_getCurrentStream(state)>>>(
      output_data,
      total_weight_data,
      input_data,
      target_data,
      valid_mask_data,
      weights_data,
      sizeAverage,
      THCTensor_(size)(state, input, 0),
      THCTensor_(size)(state, input, 1),
      THCTensor_(size)(state, input, 2) * THCTensor_(size)(state, input, 3),
      blocks_per_sample
  );
  THCudaCheck(cudaGetLastError());

  if (weights)
    THCTensor_(free)(state, weights);
  THCIndexTensor_(free)(state, target);
  THCTensor_(free)(state, input);
  THCTensor_(free)(state, valid_mask);
}

void THNN_(SpatialNLLCriterionWithMask_updateGradInput)(
           THCState *state,
           THCTensor *input,
           THCIndexTensor *target,
           THCTensor *valid_mask,
           THCTensor *gradInput,
           bool sizeAverage,
           THCTensor *weights,
           THCTensor *total_weight)
{
  THArgCheck(THCIndexTensor_(nDimension)(state, target) == 3, 1,
             "only batches of spatial targets supported (3D tensors)");
  THArgCheck(THCTensor_(nDimension)(state, input) == 4, 2,
             "only batches of spatial inputs supported (4D tensors)");
  THArgCheck(THCTensor_(isContiguous)(state, gradInput), 4,
             "gradInput must be contiguous");
  if (weights && THCTensor_(nElement)(state, weights) != THCTensor_(size)(state, input, 1)) {
    THError("weight tensor should be defined either for all or no classes");
  }

  if (weights)
    THCUNN_assertSameGPU(state, 5, weights, input, target, gradInput, total_weight);
  else
    THCUNN_assertSameGPU(state, 4, input, target, gradInput, total_weight);

  input = THCTensor_(newContiguous)(state, input);
  weights = weights ? THCTensor_(newContiguous)(state, weights) : NULL;
  target = THCIndexTensor_(newContiguous)(state, target);
  valid_mask = THCTensor_(newContiguous)(state, valid_mask);

  real *weights_data = weights ? THCTensor_(data)(state, weights) : NULL;
  real *gradInput_data = THCTensor_(data)(state, gradInput);
  THCIndex_t *target_data = THCIndexTensor_(data)(state, target);
  real *valid_mask_data = THCTensor_(data)(state, valid_mask);
  real *total_weight_data = THCTensor_(data)(state, total_weight);

  THCIndex_t batch_size = THCIndexTensor_(size)(state, target, 0);
  THCIndex_t map_nelem = THCIndexTensor_(nElement)(state, target) / batch_size;
  int blocks_per_sample = GET_BLOCKS(map_nelem) / 128;
  blocks_per_sample = (blocks_per_sample == 0) ? 1 : blocks_per_sample;
  int total_blocks = blocks_per_sample * batch_size;

  cunn_SpatialNLLCriterionWithMask_updateGradInput_kernel
    <<<total_blocks, CUDA_NUM_THREADS, 0, THCState_getCurrentStream(state)>>>(
      gradInput_data,
      target_data,
      valid_mask_data,
      weights_data,
      total_weight_data,
      sizeAverage,
      THCTensor_(size)(state, input, 0),
      THCTensor_(size)(state, input, 1),
      THCTensor_(size)(state, input, 2) *THCTensor_(size)(state, input, 3),
      blocks_per_sample
  );
  THCudaCheck(cudaGetLastError());

  if (weights)
    THCTensor_(free)(state, weights);
  THCIndexTensor_(free)(state, target);
  THCTensor_(free)(state, input);
  THCTensor_(free)(state, valid_mask);
}

#endif
