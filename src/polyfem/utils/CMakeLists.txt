set(SOURCES
	autodiff.h
	AutodiffTypes.hpp
	base64Layer.cpp
	base64Layer.hpp
	Bessel.hpp
	BoundarySampler.cpp
	BoundarySampler.hpp
	CUDA_utilities.cuh
	ClipperUtils.cpp
	ClipperUtils.hpp
	CuSparseUtils.cuh
	DisableWarnings.hpp
	EdgeSampler.cpp
	EdgeSampler.hpp
	ElasticityUtils.cpp
	ElasticityUtils.hpp
	EnableWarnings.hpp
	ExpressionValue.cpp
	ExpressionValue.hpp
	GeometryUtils.cpp
	GeometryUtils.hpp
	getRSS.c
	HashUtils.hpp
	InterpolatedFunction.cpp
	InterpolatedFunction.hpp
	Interpolation.cpp
	Interpolation.hpp
	JSONUtils.cpp
	JSONUtils.hpp
	Logger.cpp
	Logger.hpp
	MatrixUtils.cpp
	MatrixUtils.hpp
	MaybeParallelFor.hpp
	MaybeParallelFor.tpp
	par_for.cpp
	par_for.hpp
	raster.cpp
	raster.hpp
	RBFInterpolation.cpp
	RBFInterpolation.hpp
	RefElementSampler.cpp
	RefElementSampler.hpp
	Selection.cpp
	Selection.hpp
	StringUtils.cpp
	StringUtils.hpp
	Timer.hpp
	Types.hpp
)

prepend_current_path(SOURCES)
polyfem_set_source_group(${SOURCES})
target_sources(polyfem PRIVATE ${SOURCES})
