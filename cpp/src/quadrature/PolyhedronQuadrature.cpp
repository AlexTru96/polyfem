////////////////////////////////////////////////////////////////////////////////
#include "PolyhedronQuadrature.hpp"
#include "TetQuadrature.hpp"
#include "MeshUtils.hpp"
#include "UIState.hpp"
#include <geogram/mesh/mesh_io.h>
#include <igl/copyleft/tetgen/tetrahedralize.h>
#include <igl/writeMESH.h>
#include <igl/readMESH.h>
#include <igl/write_triangle_mesh.h>
#include <vector>
#include <cassert>
#include <iostream>
////////////////////////////////////////////////////////////////////////////////

namespace poly_fem {

namespace {

template<class TriMat>
double transform_pts(const TriMat &tri, const Eigen::MatrixXd &pts, Eigen::MatrixXd &transformed) {
	Eigen::Matrix3d matrix;
	matrix.row(0) = tri.row(1) - tri.row(0);
	matrix.row(1) = tri.row(2) - tri.row(0);
	matrix.row(2) = tri.row(3) - tri.row(0);

	transformed = pts * matrix;

	transformed.col(0).array() += tri(0, 0);
	transformed.col(1).array() += tri(0, 1);
	transformed.col(2).array() += tri(0, 2);

	return matrix.determinant();
}

} // anonymous namespace

////////////////////////////////////////////////////////////////////////////////

void PolyhedronQuadrature::get_quadrature(const Eigen::MatrixXd &V, const Eigen::MatrixXi &F,
	const int order, Quadrature &quadr)
{
	std::string flags = "Qpq2.0";
	Eigen::MatrixXd TV;
	Eigen::MatrixXi TF, tets;
	// igl::write_triangle_mesh("poly_current.obj", V, F);
	// std::cout << "tetgen in" << std::endl;
	int res = igl::copyleft::tetgen::tetrahedralize(V, F, flags, TV, tets, TF);
	// std::cout << "tetgen out" << std::endl;
	assert(res == 0);

	// static int counter = 0;
	// std::stringstream ss;
	// ss << std::setw(6) << std::setfill('0') << counter++;
	// std::string s = ss.str();

	// if (res != 0) {
	// 	std::cerr << "Tetgen did not succeed. Returned code: " << res << std::endl;
	// 	igl::write_triangle_mesh("poly_" + s + ".obj", V, F);
	// } else {
	// 	igl::writeMESH("tet_" + s + ".mesh", TV, tets, TF);
	// }

	// GEO::Mesh M;
	// GEO::mesh_load("tet.o.mesh", M);
	// from_geogram_mesh(M, TV, TF, tets);
	// std::cout << tets.rows() << std::endl;

	// std::cout << "volume: " << volume(M) << std::endl;

	Quadrature tet_quadr_pts;
	TetQuadrature tet_quadr;
	tet_quadr.get_quadrature(4, tet_quadr_pts);

	const long offset = tet_quadr_pts.weights.rows();
	quadr.points.resize(tets.rows() * offset, 3);
	quadr.weights.resize(tets.rows() * offset, 1);

	Eigen::MatrixXd transformed_points;

	for (long i = 0; i < tets.rows(); ++i) {
		Eigen::Matrix<double, 4, 3> tetra;
		const auto &indices = tets.row(i);
		tetra.row(0) = TV.row(indices(0));
		tetra.row(1) = TV.row(indices(1));
		tetra.row(2) = TV.row(indices(2));
		tetra.row(3) = TV.row(indices(3));

		// viewer.data.add_edges(triangle.row(0), triangle.row(1), Eigen::Vector3d(1,0,0).transpose());
		// viewer.data.add_edges(triangle.row(0), triangle.row(2), Eigen::Vector3d(1,0,0).transpose());
		// viewer.data.add_edges(triangle.row(2), triangle.row(1), Eigen::Vector3d(1,0,0).transpose());

		const double det = transform_pts(tetra, tet_quadr_pts.points, transformed_points);

		quadr.points.block(i*offset, 0, transformed_points.rows(), transformed_points.cols()) = transformed_points;
		quadr.weights.block(i*offset, 0, tet_quadr_pts.weights.rows(), tet_quadr_pts.weights.cols()) = tet_quadr_pts.weights * det;
	}

	assert(quadr.weights.minCoeff() >= 0);
	std::cout<<"#quadrature points: " << quadr.weights.size()<<" "<<quadr.weights.sum()<<std::endl;
}

} // namespace poly_fem
