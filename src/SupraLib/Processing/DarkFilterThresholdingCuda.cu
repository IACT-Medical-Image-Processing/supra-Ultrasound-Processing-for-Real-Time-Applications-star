// ================================================================================================
// 
// If not explicitly stated: Copyright (C) 2019, all rights reserved,
//      Rüdiger Göbl 
//		Email r.goebl@tum.de
//      Chair for Computer Aided Medical Procedures
//      Technische Universität München
//      Boltzmannstr. 3, 85748 Garching b. München, Germany
// 
// ================================================================================================

#include "DarkFilterThresholdingCuda.h"
#include "utilities/Buffer.h"

#include <thrust/transform.h>
#include <thrust/execution_policy.h>

using namespace std;

namespace supra
{
	namespace DarkFilterThresholdingCudaInternal
	{
		typedef DarkFilterThresholdingCuda::WorkType WorkType;

		// here the actual processing happens!

		template <typename InputType, typename OutputType>
		__global__ void processKernel(const InputType* inputImage, vec3s size, WorkType threshold, OutputType* outputImage)
		{
			size_t x = blockDim.x*blockIdx.x + threadIdx.x;
			size_t y = blockDim.y*blockIdx.y + threadIdx.y;
			size_t z = blockDim.z*blockIdx.z + threadIdx.z;

			extern __shared__ uint8_t smem[];
			CachedBuffer3<const InputType*, size_t> inputBuffer{
				inputImage, size, reinterpret_cast<InputType*>(smem), vec3s{blockDim.x, blockDim.y, blockDim.z},
				vec3s{blockDim.x*blockIdx.x, blockDim.y*blockIdx.y, blockDim.z*blockIdx.z } };
			Buffer3<OutputType*, size_t> outputBuffer{ outputImage, size };
			
			size_t width = size.x;
			size_t height = size.y;
			size_t depth = size.z;

			if (x < width && y < height && z < depth)
			{
				// Perform a pixel-wise operation on the image

				// Get the input pixel value and cast it to out working type.
				// As this should in general be a type with wider range / precision, this cast does not loose anything.
				WorkType inPixel = inputBuffer[{x, y, z}];

				// Perform the thresholding
				WorkType value;
				if (abs(inPixel) >= threshold)
				{
					value = inPixel;
				}
				else {
					value = (WorkType)0;
				}

				// Store the output pixel value.
				// Because this is templated, we need to cast from "WorkType" to "OutputType".
				// This should happen in a sane way, that is with clamping. There is a helper for that!
				outputBuffer[{x, y, z}] = clampCast<OutputType>(value);
			}
		}
	}

	template <typename InputType, typename OutputType>
	shared_ptr<Container<OutputType> > DarkFilterThresholdingCuda::process(
		const shared_ptr<const Container<InputType>>& imageData, 
		vec3s size, double threshold)
	{
		// here we prepare the buffers and call the cuda kernel

		size_t width = size.x;
		size_t height = size.y;
		size_t depth = size.z;

		// make sure the data is in cpu memory
		auto inImageData = imageData;
		if (!inImageData->isGPU() && !inImageData->isBoth())
		{
			inImageData = make_shared<Container<InputType> >(LocationGpu, *inImageData);
		}
		
		// prepare the output memory
		auto outImageData = make_shared<Container<OutputType> >(LocationGpu, inImageData->getStream(), width*height*depth);
		
		// call the kernel for the heavy-lifting
		dim3 blockSize(32, 4, 1);
		dim3 gridSize(
			static_cast<unsigned int>((size.x + blockSize.x - 1) / blockSize.x),
			static_cast<unsigned int>((size.y + blockSize.y - 1) / blockSize.y),
			static_cast<unsigned int>((size.z + blockSize.z - 1) / blockSize.z));
		size_t sharedMemorySize = blockSize.x * blockSize.y * blockSize.z * sizeof(InputType);
		DarkFilterThresholdingCudaInternal::processKernel <<<gridSize, blockSize, sharedMemorySize, inImageData->getStream() >>> (
			inImageData->get(),
			size,
			static_cast<WorkType>(threshold),
			outImageData->get());
		// check for cuda launch errors
		cudaSafeCall(cudaPeekAtLastError());
		// You should NOT synchronize the device or the stream we are working on!!

		// return the result!
		return outImageData;
	}

	// We don't wish to have the template implementation in the header, to make compilation easier.
	// Because of this, we need to explicity instantiate the methods we will need.
	template
	shared_ptr<Container<uint8_t> > DarkFilterThresholdingCuda::process<int16_t, uint8_t>(const shared_ptr<const Container<int16_t> >& inImageData, vec3s size, double threshold);
	template
	shared_ptr<Container<uint8_t> > DarkFilterThresholdingCuda::process<float, uint8_t>(const shared_ptr<const Container<float> >& inImageData, vec3s size, double threshold);
	template
	shared_ptr<Container<uint8_t> > DarkFilterThresholdingCuda::process<uint8_t, uint8_t>(const shared_ptr<const Container<uint8_t> >& inImageData, vec3s size, double threshold);
	template
	shared_ptr<Container<float> > DarkFilterThresholdingCuda::process<int16_t, float>(const shared_ptr<const Container<int16_t> >& inImageData, vec3s size, double threshold);
	template
	shared_ptr<Container<float> > DarkFilterThresholdingCuda::process<float, float>(const shared_ptr<const Container<float> >& inImageData, vec3s size, double threshold);
	template
	shared_ptr<Container<float> > DarkFilterThresholdingCuda::process<uint8_t, float>(const shared_ptr<const Container<uint8_t> >& inImageData, vec3s size, double threshold);
	template
	shared_ptr<Container<int16_t> > DarkFilterThresholdingCuda::process<int16_t, int16_t>(const shared_ptr<const Container<int16_t> >& inImageData, vec3s size, double threshold);
	template
	shared_ptr<Container<int16_t> > DarkFilterThresholdingCuda::process<float, int16_t>(const shared_ptr<const Container<float> >& inImageData, vec3s size, double threshold);
	template
	shared_ptr<Container<int16_t> > DarkFilterThresholdingCuda::process<uint8_t, int16_t>(const shared_ptr<const Container<uint8_t> >& inImageData, vec3s size, double threshold);
}