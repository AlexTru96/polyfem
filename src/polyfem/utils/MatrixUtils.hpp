#pragma once

#include <polyfem/Common.hpp>
#include <polyfem/utils/Types.hpp>

#include <Eigen/Dense>
#include <Eigen/Sparse>

namespace polyfem
{
	namespace utils
	{
		// Show some stats about the matrix M: det, singular values, condition number, etc
		void show_matrix_stats(const Eigen::MatrixXd &M);

		template <typename T>
		T determinant(const Eigen::Matrix<T, Eigen::Dynamic, Eigen::Dynamic, 0, 3, 3> &mat)
		{
			assert(mat.rows() == mat.cols());

			if (mat.rows() == 1)
				return mat(0);
			else if (mat.rows() == 2)
				return mat(0, 0) * mat(1, 1) - mat(0, 1) * mat(1, 0);
			else if (mat.rows() == 3)
				return mat(0, 0) * (mat(1, 1) * mat(2, 2) - mat(1, 2) * mat(2, 1)) - mat(0, 1) * (mat(1, 0) * mat(2, 2) - mat(1, 2) * mat(2, 0)) + mat(0, 2) * (mat(1, 0) * mat(2, 1) - mat(1, 1) * mat(2, 0));

			assert(false);
			return T(0);
		}

		inline Eigen::SparseMatrix<double> sparse_identity(int rows, int cols)
		{
			Eigen::SparseMatrix<double> I(rows, cols);
			I.setIdentity();
			return I;
		}

		class SpareMatrixCache
		{
		public:
			SpareMatrixCache() {}
			SpareMatrixCache(const size_t size);
			SpareMatrixCache(const size_t rows, const size_t cols);
			SpareMatrixCache(const SpareMatrixCache &other);

			void init(const size_t size);
			void init(const size_t rows, const size_t cols);
			void init(const SpareMatrixCache &other);

			void set_zero();
			void moving_values(std::vector<double> &new_values);

			inline void reserve(const size_t size) { entries_.reserve(size); }
			inline size_t entries_size() const { return entries_.size(); }
			inline size_t capacity() const { return entries_.capacity(); }
			inline size_t non_zeros() const { return mapping_.empty() ? mat_.nonZeros() : values_.size(); }
			inline size_t mapping_size() const { return mapping_.size(); }

			void add_value(const int e, const int i, const int j, const double value);

			StiffnessMatrix get_matrix(const bool compute_mapping = true);
			void prune();

			SpareMatrixCache operator+(const SpareMatrixCache &a) const;
			void operator+=(const SpareMatrixCache &o);

			const StiffnessMatrix &mat() const { return mat_; }
			const std::vector<Eigen::Triplet<double>> &entries() const { return entries_; }

			const std::vector<int> &inner_index_to_gpu() const { return inner_index_; }
			const std::vector<int> &outer_index_to_gpu() const { return outer_index_; }
			//	const std::vector<std::vector<std::pair<int, size_t>>> &mapping_to_gpu() const { return mapping_; }
			const std::vector<std::vector<int>> &second_cache_to_gpu() const { return second_cache_; }

		private:
			size_t size_;
			StiffnessMatrix tmp_, mat_;
			std::vector<Eigen::Triplet<double>> entries_;              // ONLY EXISTS FOR ONE TIME AND BELONGS HERE NOT TO THE MAIN CACHE
			std::vector<std::vector<std::pair<int, size_t>>> mapping_; // NOT aVAILABLE 1 TIME, MAPPING BELONGS TO MAT_CACHE (MAIN_CACHE)
			std::vector<int> inner_index_, outer_index_;               // NOT AVAILABLE 1 TIME, OUTER AND INnER INDEX BELONGS TO MAT_CACHE (MAIN_CACHE)
			std::vector<double> values_;                               // NOT AVAILABLE 1 TIME, VALUES BELONGS TO LOCAL_STORAGE.CACHE
			const SpareMatrixCache *main_cache_ = nullptr;

			std::vector<std::vector<int>> second_cache_;                         // NOT AVAILABLE 1 TIME, BUT THEN EXISTS ON THE MAIN CACHE
			std::vector<std::vector<std::pair<int, int>>> second_cache_entries_; // ONLY EXISTS FOR ONE TIME AND BELONGS HERE NOT TO THE MAIN CACHE
			bool use_second_cache_ = true;
			int current_e_ = -1;
			int current_e_index_ = -1;

			inline const std::vector<std::vector<std::pair<int, size_t>>> &mapping() const
			{
				return main_cache_ == nullptr ? mapping_ : main_cache_->mapping_;
			}

			inline const std::vector<std::vector<int>> &second_cache() const
			{
				return main_cache_ == nullptr ? second_cache_ : main_cache_->second_cache_;
			}
		};

		/// Flatten rowwises
		Eigen::VectorXd flatten(const Eigen::MatrixXd &X);

		/// Unflatten rowwises, so every dim elements in x become a row.
		Eigen::MatrixXd unflatten(const Eigen::VectorXd &x, int dim);

		/// @brief Lump each row of a matrix into the diagonal.
		/// @param M Matrix to lump.
		/// @return Lumped matrix.
		Eigen::SparseMatrix<double> lump_matrix(const Eigen::SparseMatrix<double> &M);

		/// @brief Map a full size matrix to a reduced one by dropping rows and columns.
		/// @param[in] full_size Number of variables in the full system.
		/// @param[in] reduced_size Number of variables in the reduced system.
		/// @param[in] removed_vars Indices of the variables (rows and columns of full) to remove.
		/// @param[in] full Full size matrix.
		/// @param[out] reduced Output reduced size matrix.
		void full_to_reduced_matrix(
			const int full_size,
			const int reduced_size,
			const std::vector<int> &removed_vars,
			const StiffnessMatrix &full,
			StiffnessMatrix &reduced);

		/// @brief Reorder row blocks in a matrix.
		/// @param in Input matrix.
		/// @param in_to_out Mapping from input blocks to output blocks.
		/// @param out_blocks Number of blocks in the output matrix.
		/// @param block_size Size of each block.
		/// @return Reordered matrix.
		Eigen::MatrixXd reorder_matrix(
			const Eigen::MatrixXd &in,
			const Eigen::VectorXi &in_to_out,
			int out_blocks = -1,
			const int block_size = 1);

		/// @brief Undo the reordering of row blocks in a matrix.
		/// @param out Reordered matrix.
		/// @param in_to_out Mapping from input blocks to output blocks.
		/// @param in_blocks Number of blocks in the input matrix.
		/// @param block_size Size of each block.
		/// @return Unreordered matrix.
		Eigen::MatrixXd unreorder_matrix(
			const Eigen::MatrixXd &out,
			const Eigen::VectorXi &in_to_out,
			int in_blocks = -1,
			const int block_size = 1);

		/// @brief Map the entrys of an index matrix to new indices.
		/// @param in Input index matrix.
		/// @param index_mapping Mapping from old to new indices.
		/// @return Mapped index matrix.
		Eigen::MatrixXi map_index_matrix(
			const Eigen::MatrixXi &in,
			const Eigen::VectorXi &index_mapping);

		template <typename DstMat, typename SrcMat>
		void append_rows(DstMat &dst, const SrcMat &src)
		{
			if (src.rows() == 0)
				return;
			if (dst.cols() == 0)
				dst.resize(dst.rows(), src.cols());
			assert(dst.cols() == src.cols());
			dst.conservativeResize(dst.rows() + src.rows(), dst.cols());
			dst.bottomRows(src.rows()) = src;
		}

		template <typename DstMat>
		void append_zero_rows(DstMat &dst, const size_t n_zero_rows)
		{
			assert(dst.cols() > 0);
			if (n_zero_rows == 0)
				return;
			dst.conservativeResize(dst.rows() + n_zero_rows, dst.cols());
			dst.bottomRows(n_zero_rows).setZero();
		}
	} // namespace utils
} // namespace polyfem
