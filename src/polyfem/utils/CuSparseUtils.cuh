#pragma once
#include <cuda.h>
#include <cuda_runtime.h>
#include <stdio.h>
#include "cusparse.h"
#include "CUDA_utilities.cuh"

#include <igl/Timer.h>

using namespace std;
#include <vector>

#define DEBUG false

inline bool comparematrix(
    const double *value1, const int *outer1, const int *inner1, int N1, int nnz1,
    const double *value2, const int *outer2, const int *inner2, int N2, int nnz2)
{
    for (int i=0; i<nnz1; i++)
    {
        if(*(value1+i) != *(value2+i))
        {
            printf("NEQ at %d, v1= %lf, v2=%lf\n",i, *(value1+i), *(value2+i));
            return false;
        }
    }
    printf("EQ\n");
    return true;
}

inline void printCSRMatrix(const double *value, const int *outer, const int *inner, int N, int nnz)
{
    // printf("N: %d, nnz: %d\n",N,nnz);
    // if (N>20) N=20;
    // if (nnz>100) nnz=100;
    printf("\nouter: ");
    for (int i=0; i<N; i++)
    {
        printf("%d, ", *(outer+i));
    }
    printf("\ninner: ");
    for (int i=0; i<nnz; i++)
    {
        printf("%d, ", *(inner+i));
    }
    printf("\nvalue: ");
    for (int i=0; i<nnz; i++)
    {
        printf("%lf, ", *(value+i));
    }

    printf("\nmatrix: \n");
    int n=0;
    for (int i=0; i<N; i++)
    {
        for (int j=0; j<N; j++)
        {
            if (n<*(outer+i) && j==*(inner+n))
            {
                printf("%lf\t, ", *(value+n));
                n+=1;
            }
            else
            {
                printf("n\t, ");
            }
        }
        printf("\n");
    }
    printf("\n");
}

inline void printCSRMatrixGPU(const double *val, const int *row, const int *col, const int N, const int nnz)
{
    double *value = new double[nnz];
    int *outer = new int[N+1];
    int *inner = new int[nnz];

    cudaMemcpy(outer, row, sizeof(int) * (N + 1), cudaMemcpyDeviceToHost);
    cudaMemcpy(inner, col, sizeof(int) * nnz, cudaMemcpyDeviceToHost);
    cudaMemcpy(value, val, sizeof(double) * nnz, cudaMemcpyDeviceToHost);

    printCSRMatrix(value, outer, inner, N, nnz);
}

// Eigen's sparse matrix is in CSC format, whereas cuSparse is in CSR format. Therefore, need a transpose.
// https://stackoverflow.com/questions/57334742/convert-eigensparsematrix-to-cusparse-and-vice-versa
inline void EigenSparseToCuSparseTranspose(const Eigen::SparseMatrix<double> &mat, int *&row, int *&col, double *&val)
{
	// using namespace polyfem;
    igl::Timer timerg;

	int num_non0  = mat.nonZeros();
	int num_outer = mat.cols() + 1;

    timerg.start();
	row = ALLOCATE_GPU<int>(row, (mat.cols()+1)*sizeof(int));
	col = ALLOCATE_GPU<int>(col, mat.nonZeros()*sizeof(int));
	val = ALLOCATE_GPU<double>(val, mat.nonZeros()*sizeof(double));
    timerg.stop();
    // logger().trace("CUDA MALLOC TMP {}s", timerg.getElapsedTime());
    printf("[2022-11-30 04:53:24.274] [polyfem] [trace] [timing] CUDA MALLOC TMP %lfs\n", timerg.getElapsedTime());

    timerg.start();
    cudaMemcpy(row, mat.outerIndexPtr(), sizeof(int) * num_outer, cudaMemcpyHostToDevice);
	cudaMemcpy(col, mat.innerIndexPtr(), sizeof(int) * num_non0, cudaMemcpyHostToDevice);
	cudaMemcpy(val, mat.valuePtr(), sizeof(double) * num_non0, cudaMemcpyHostToDevice);
    timerg.stop();
    // logger().trace("DATA MOVING HTOD {}s", timerg.getElapsedTime());
    printf("[2022-11-30 04:53:24.274] [polyfem] [trace] [timing] DATA MOVING HTOD %lfs\n", timerg.getElapsedTime());
	printf("[2022-11-30 04:53:24.274] [polyfem] [trace] [timing] TMP NNZ %ds\n", mat.nonZeros());		
}

inline void CuSparseTransposeToEigenSparse(
    const int *row,
    const int *col,
    const double *val,
    const int num_non0,
    const int mat_row,
    const int mat_col,
    Eigen::SparseMatrix<double> &mat)
{
	// using namespace polyfem;
    igl::Timer timerg;

    timerg.start();
    std::vector<int> outer(mat_col + 1);
    std::vector<int> inner(num_non0);
    std::vector<double> value(num_non0);
    timerg.stop();
    printf("[2022-11-30 04:53:24.274] [polyfem] [trace] [timing] STD VEC %lfs\n", timerg.getElapsedTime());

    timerg.start();
    cudaMemcpy(outer.data(), row, sizeof(int) * (mat_col + 1), cudaMemcpyDeviceToHost);
    cudaMemcpy(inner.data(), col, sizeof(int) * num_non0, cudaMemcpyDeviceToHost);
    cudaMemcpy(value.data(), val, sizeof(double) * num_non0, cudaMemcpyDeviceToHost);
    timerg.stop();
    printf("[2022-11-30 04:53:24.274] [polyfem] [trace] [timing] DATA MOVING DTOH %lfs\n", timerg.getElapsedTime());

    timerg.start();
    // mat = Eigen::Map<Eigen::SparseMatrix<double>>(mat_row, mat_col, num_non0, outer.data(), inner.data(), value.data());
    /// --USE EIGEN-- ///
    // Eigen::Map<Eigen::SparseMatrix<double>> mat_map(mat_row, mat_col, num_non0, outer.data(), inner.data(), value.data());
    /// --USE EIGEN-- ///
    timerg.stop();
    printf("[2022-11-30 04:53:24.274] [polyfem] [trace] [timing] EIGEN MAP %lfs\n", timerg.getElapsedTime());

    timerg.start();
    /// --USE EIGEN-- ///
    // mat = mat_map;
    /// --USE EIGEN-- ///
    // mat = mat_map.eval();

    /// --USE COPY-- ///
    // Eigen::Map<Eigen::SparseMatrix<double>> mat(mat_row, mat_col, num_non0, outer.data(), inner.data(), value.data());
    mat.reserve(num_non0);     
    memcpy(mat.outerIndexPtr(), outer.data(), sizeof(int) * (mat_col + 1));
    memcpy(mat.innerIndexPtr(), inner.data(), sizeof(int) * num_non0);
    memcpy(mat.valuePtr(), value.data(), sizeof(double) * num_non0);
    /// --USE COPY-- ///

    timerg.stop();
    printf("[2022-11-30 04:53:24.274] [polyfem] [trace] [timing] EIGEN COPY %lfs\n", timerg.getElapsedTime());
}

inline void CuSparseMatrixAdd(
    int m, int n,
    int nnzA, const double *csrValA, const int *csrRowPtrA, const int *csrColIndA,     
    int nnzB, const double *csrValB, const int *csrRowPtrB, const int *csrColIndB,     
    int &nnzCret, double *&csrValC, int *&csrRowPtrC, int *&csrColIndC     
)
{
	cusparseStatus_t status;
	cusparseHandle_t handle=0;
	cusparseMatDescr_t descr=0;
    status= cusparseCreate(&handle);
	status= cusparseCreateMatDescr(&descr);
	cusparseSetMatType(descr, CUSPARSE_MATRIX_TYPE_GENERAL);
	cusparseSetMatIndexBase(descr, CUSPARSE_INDEX_BASE_ZERO); 	
    const double a = 1.0;
    const double b = 1.0;
	const double *alpha = &a;
	const double *beta = &b;
    int baseC, nnzC;
    /* alpha, nnzTotalDevHostPtr points to host memory */
    int *nnzTotalDevHostPtr = &nnzC;
    cusparseSetPointerMode(handle, CUSPARSE_POINTER_MODE_HOST);
    cudaMalloc((void**)&csrRowPtrC, sizeof(int)*(m+1));

    double *buffer;
	buffer = ALLOCATE_GPU<double>(buffer, 4*(nnzA+nnzB)*sizeof(double));    

    cusparseXcsrgeam2Nnz(handle, m, n,
            descr, /*descrA*/ nnzA, csrRowPtrA, csrColIndA,
            descr, /*descrB*/ nnzB, csrRowPtrB, csrColIndB,
            descr, /*descrC*/ csrRowPtrC, nnzTotalDevHostPtr,
            buffer);
    if (NULL != nnzTotalDevHostPtr){
        nnzC = *nnzTotalDevHostPtr;
    }else{
        cudaMemcpy(&nnzC, csrRowPtrC+m, sizeof(int), cudaMemcpyDeviceToHost);
        cudaMemcpy(&baseC, csrRowPtrC, sizeof(int), cudaMemcpyDeviceToHost);
        nnzC -= baseC;
    }
    cudaMalloc((void**)&csrColIndC, sizeof(int)*nnzC);
    cudaMalloc((void**)&csrValC, sizeof(double)*nnzC);
    cusparseDcsrgeam2(handle, m, n,
            alpha,
            descr, /*descrA*/ nnzA,
            csrValA, csrRowPtrA, csrColIndA,
            beta,
            descr, /*descrB*/ nnzB,
            csrValB, csrRowPtrB, csrColIndB,
            descr, /*descrC*/
            csrValC, csrRowPtrC, csrColIndC,
            buffer);

	cusparseDestroyMatDescr(descr);
	cusparseDestroy(handle); 
	cudaFree(buffer);

    nnzCret = nnzC;

    if (DEBUG)
    {
        printf("\nnnzC: %d, nnzCret: %d", nnzC, nnzCret);
        printf("\nnew_hessian dev matrix in CuSparseMatrixAdd:");
        printCSRMatrixGPU(csrValC, csrRowPtrC, csrColIndC, n, nnzC);
    }
}

inline void CuSparseHessianSum1(
    const Eigen::SparseMatrix<double> &tmp, 
    Eigen::SparseMatrix<double> &hessian)
{
	// using namespace polyfem;
    igl::Timer timerg;

    double *tmp_val;
    int *tmp_row, *tmp_col;
    EigenSparseToCuSparseTranspose(tmp, tmp_row, tmp_col, tmp_val);

    if(DEBUG)
    {
        printf("\ntmp eigen matrix:");
        printCSRMatrix(tmp.valuePtr(), tmp.outerIndexPtr(), tmp.innerIndexPtr(), tmp.cols(), tmp.nonZeros());
        printf("\ntmp dev matrix:");
        printCSRMatrixGPU(tmp_val, tmp_row, tmp_col, tmp.cols(), tmp.nonZeros());
    }

    double *hessian_val;
    int *hessian_row, *hessian_col;
    EigenSparseToCuSparseTranspose(hessian, hessian_row, hessian_col, hessian_val);

    if(DEBUG)
    {   
        printf("\nhessian eigen matrix:");
        printCSRMatrix(hessian.valuePtr(), hessian.outerIndexPtr(), hessian.innerIndexPtr(), hessian.cols(), hessian.nonZeros());
        printf("\nhessian dev matrix:");
        printCSRMatrixGPU(hessian_val, hessian_row, hessian_col, hessian.cols(), hessian.nonZeros());
    }

    double *new_hessian_val;
    int *new_hessian_row;
    int *new_hessian_col;
    int new_hessian_nnz;

    timerg.start();
    CuSparseMatrixAdd(
        tmp.cols(), tmp.cols(),
        tmp.nonZeros(), tmp_val, tmp_row, tmp_col, 
        hessian.nonZeros(), hessian_val, hessian_row, hessian_col,
        new_hessian_nnz, new_hessian_val, new_hessian_row, new_hessian_col);
    timerg.stop();
    // logger().trace("CUSPARSE ADD {}s", timerg.getElapsedTime());

    hessian_val = new_hessian_val;
    hessian_row = new_hessian_row;
    hessian_col = new_hessian_col;

    if(DEBUG)
    {
        printf("\nnew_hessian dev matrix:");
        printCSRMatrixGPU(new_hessian_val, new_hessian_row, new_hessian_col, tmp.cols(), new_hessian_nnz);
    }

    CuSparseTransposeToEigenSparse(new_hessian_row, new_hessian_col, new_hessian_val, new_hessian_nnz, hessian.rows(), hessian.cols(), hessian);
    if (DEBUG)
    {
        printf("\nnew_hessian eigen matrix:");
        printCSRMatrix(hessian.valuePtr(), hessian.outerIndexPtr(), hessian.innerIndexPtr(), hessian.cols(), hessian.nonZeros());
    }
    cudaFree(new_hessian_val);
    cudaFree(new_hessian_row);
    cudaFree(new_hessian_col);
    cudaFree(hessian_val);
    cudaFree(hessian_row);
    cudaFree(hessian_col);
    cudaFree(tmp_val);
    cudaFree(tmp_row);
    cudaFree(tmp_col);
}

inline void CuSparseHessianSum2(
    const Eigen::SparseMatrix<double> &tmp, 
    int &hessian_nnz, double *&hessian_val, int *&hessian_row, int *&hessian_col)
{
	// using namespace polyfem;
    igl::Timer timerg;

    double *tmp_val;
    int *tmp_row, *tmp_col;
    EigenSparseToCuSparseTranspose(tmp, tmp_row, tmp_col, tmp_val);

    if(DEBUG)
    {
        printf("\ntmp eigen matrix:");
        printCSRMatrix(tmp.valuePtr(), tmp.outerIndexPtr(), tmp.innerIndexPtr(), tmp.cols(), tmp.nonZeros());
        printf("\ntmp dev matrix:");
        printCSRMatrixGPU(tmp_val, tmp_row, tmp_col, tmp.cols(), tmp.nonZeros());
    }

    if(DEBUG)
    {   
        printf("\nhessian dev matrix:");
        printCSRMatrixGPU(hessian_val, hessian_row, hessian_col, tmp.cols(), hessian_nnz);
    }

    double *new_hessian_val;
    int *new_hessian_row;
    int *new_hessian_col;
    int new_hessian_nnz;

    timerg.start();
    CuSparseMatrixAdd(
        tmp.cols(), tmp.cols(),
        tmp.nonZeros(), tmp_val, tmp_row, tmp_col, 
        hessian_nnz, hessian_val, hessian_row, hessian_col,
        new_hessian_nnz, new_hessian_val, new_hessian_row, new_hessian_col);
    timerg.stop();
    // logger().trace("CUSPARSE ADD {}s", timerg.getElapsedTime());

    if(DEBUG)
    {
        printf("\nUpdated new hessian dev matrix:");
        printCSRMatrixGPU(new_hessian_val, new_hessian_row, new_hessian_col, tmp.cols(), new_hessian_nnz);
    }

    hessian_nnz = new_hessian_nnz;

    timerg.start();
    cudaFree(hessian_row);
    cudaFree(hessian_col);
    cudaFree(hessian_val);
    timerg.stop();
    // logger().trace("FREE HESSIAN(EVERY) {}s", timerg.getElapsedTime());
    timerg.start();
	hessian_row = ALLOCATE_GPU<int>(hessian_row, (tmp.cols()+1)*sizeof(int));
	hessian_col = ALLOCATE_GPU<int>(hessian_col, hessian_nnz*sizeof(int));
	hessian_val = ALLOCATE_GPU<double>(hessian_val, hessian_nnz*sizeof(double));
    timerg.stop();
    // logger().trace("CUDA MALLOC HESSIAN {}s", timerg.getElapsedTime());

    timerg.start();
    cudaMemcpy(hessian_row, new_hessian_row, sizeof(int)*(tmp.cols()+1), cudaMemcpyDeviceToDevice);    
    cudaMemcpy(hessian_col, new_hessian_col, sizeof(int)*hessian_nnz, cudaMemcpyDeviceToDevice);    
    cudaMemcpy(hessian_val, new_hessian_val, sizeof(double)*hessian_nnz, cudaMemcpyDeviceToDevice);    
    timerg.stop();
    // logger().trace("DATA MOVING DTOD {}s", timerg.getElapsedTime());

    if(DEBUG)
    {
        printf("\nUpdated hessian dev matrix:");
        printCSRMatrixGPU(hessian_val, hessian_row, hessian_col, tmp.cols(), hessian_nnz);
    }

    timerg.start();
    cudaFree(new_hessian_val);
    cudaFree(new_hessian_row);
    cudaFree(new_hessian_col);
    timerg.stop();
    // logger().trace("FREE NEW HESSIAN {}s", timerg.getElapsedTime());
    timerg.start();
    cudaFree(tmp_val);
    cudaFree(tmp_row);
    cudaFree(tmp_col);
    timerg.stop();
    // logger().trace("FREE TMP {}s", timerg.getElapsedTime());
}

inline void CuSparseHessianSum(
    const Eigen::SparseMatrix<double> &tmp, 
    int &hessian_nnz, double **hessian_val, int **hessian_row, int **hessian_col)
{
	// using namespace polyfem;
    igl::Timer timerg;

    double *tmp_val;
    int *tmp_row, *tmp_col;
    timerg.start();
    EigenSparseToCuSparseTranspose(tmp, tmp_row, tmp_col, tmp_val);
    timerg.stop();
    printf("[2022-11-30 04:53:24.274] [polyfem] [trace] [timing] EIGEN TO CUSPARSE %lfs\n", timerg.getElapsedTime());

    if(DEBUG)
    {
        printf("\ntmp eigen matrix:");
        printCSRMatrix(tmp.valuePtr(), tmp.outerIndexPtr(), tmp.innerIndexPtr(), tmp.cols(), tmp.nonZeros());
        printf("\ntmp dev matrix:");
        printCSRMatrixGPU(tmp_val, tmp_row, tmp_col, tmp.cols(), tmp.nonZeros());
    }

    if(DEBUG)
    {   
        printf("\nhessian dev matrix:");
        printCSRMatrixGPU(*hessian_val, *hessian_row, *hessian_col, tmp.cols(), hessian_nnz);
    }

    double *new_hessian_val;
    int *new_hessian_row;
    int *new_hessian_col;
    int new_hessian_nnz;

    timerg.start();
    CuSparseMatrixAdd(
        tmp.cols(), tmp.cols(),
        tmp.nonZeros(), tmp_val, tmp_row, tmp_col, 
        hessian_nnz, *hessian_val, *hessian_row, *hessian_col,
        new_hessian_nnz, new_hessian_val, new_hessian_row, new_hessian_col);
    timerg.stop();
    // logger().trace("CUSPARSE ADD {}s", timerg.getElapsedTime());
    printf("[2022-11-30 04:53:24.274] [polyfem] [trace] [timing] CUSPARSE ADD %lfs\n", timerg.getElapsedTime());

    if(DEBUG)
    {
        printf("\nUpdated new hessian dev matrix:");
        printCSRMatrixGPU(new_hessian_val, new_hessian_row, new_hessian_col, tmp.cols(), new_hessian_nnz);
    }

    hessian_nnz = new_hessian_nnz;

    timerg.start();
    cudaMemcpy(*hessian_row, new_hessian_row, sizeof(int)*(tmp.cols()+1), cudaMemcpyDeviceToDevice);    
    cudaMemcpy(*hessian_col, new_hessian_col, sizeof(int)*hessian_nnz, cudaMemcpyDeviceToDevice);    
    cudaMemcpy(*hessian_val, new_hessian_val, sizeof(double)*hessian_nnz, cudaMemcpyDeviceToDevice);      
    timerg.stop();
    // logger().trace("DATA MOVING DTOD {}s", timerg.getElapsedTime());
    printf("[2022-11-30 04:53:24.274] [polyfem] [trace] [timing] DATA MOVING DTOD %lfs\n", timerg.getElapsedTime());

    if(DEBUG)
    {
        printf("\nUpdated hessian dev matrix:");
        printCSRMatrixGPU(*hessian_val, *hessian_row, *hessian_col, tmp.cols(), hessian_nnz);
    }

    timerg.start();
    cudaFree(new_hessian_val);
    cudaFree(new_hessian_row);
    cudaFree(new_hessian_col);
    timerg.stop();
    // logger().trace("FREE NEW HESSIAN {}s", timerg.getElapsedTime());
    printf("[2022-11-30 04:53:24.274] [polyfem] [trace] [timing] FREE NEW HESSIAN %lfs\n", timerg.getElapsedTime());

    timerg.start();
    cudaFree(tmp_val);
    cudaFree(tmp_row);
    cudaFree(tmp_col);
    timerg.stop();
    // logger().trace("FREE TMP {}s", timerg.getElapsedTime());
    printf("[2022-11-30 04:53:24.274] [polyfem] [trace] [timing] FREE TMP %lfs\n", timerg.getElapsedTime());
}
