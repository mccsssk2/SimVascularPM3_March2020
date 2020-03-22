/* Copyright (c) Stanford University, The Regents of the University of
 *               California, and others.
 *
 * All Rights Reserved.
 *
 * See Copyright-SimVascular.txt for additional details.
 *
 * Permission is hereby granted, free of charge, to any person obtaining
 * a copy of this software and associated documentation files (the
 * "Software"), to deal in the Software without restriction, including
 * without limitation the rights to use, copy, modify, merge, publish,
 * distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so, subject
 * to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included
 * in all copies or substantial portions of the Software.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
 * IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 * TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
 * PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER
 * OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 * LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 * NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

/**
 * \class vtkSVPlanarMapper
 *
 * \brief This is a filter to map a polydata with a boundary defined to the
 * plane!
 *
 * \author Adam Updegrove
 * \author updega2@gmail.com
 * \author UC Berkeley
 * \author shaddenlab.berkeley.edu
 */

#ifndef vtkSVPlanarMapper_h
#define vtkSVPlanarMapper_h

#include "vtkSVParameterizationModule.h" // For exports

#include "vtkEdgeTable.h"
#include "vtkFloatArray.h"
#include "vtkPolyData.h"
#include "vtkPolyDataAlgorithm.h"

#include "vtkSVBoundaryMapper.h"
#include "vtkSVSparseMatrix.h"

class VTKSVPARAMETERIZATION_EXPORT vtkSVPlanarMapper : public vtkPolyDataAlgorithm
{
public:
  static vtkSVPlanarMapper* New();
  vtkTypeMacro(vtkSVPlanarMapper, vtkPolyDataAlgorithm);
  void PrintSelf(ostream& os, vtkIndent indent) override;

  //@{
  /// \brief Get/Set for the boundary mapper object
  vtkGetObjectMacro(BoundaryMapper, vtkSVBoundaryMapper);
  vtkSetObjectMacro(BoundaryMapper, vtkSVBoundaryMapper);
  //@}

  //@{
  /// \brief Get/Set Internal ids array name, generated by GenerateIdFilter
  vtkGetStringMacro(InternalIdsArrayName);
  vtkSetStringMacro(InternalIdsArrayName);
  //@}

  //@{
  /// \brief Indicate which two coordinates to parameterize. Dir2 is stationary dir
  vtkGetMacro(Dir0, int);
  vtkSetMacro(Dir0, int);
  vtkGetMacro(Dir1, int);
  vtkSetMacro(Dir1, int);
  vtkGetMacro(Dir2, int);
  vtkSetMacro(Dir2, int);
  //@}

  //@{
  /// \details has not effect currently, something to change in future
  enum WEIGHT_TYPE
  {
    HARMONIC = 0,
    MEAN_VALUE,
    TUTTE
  };
  //@}

  //@{
  /// \brief inverst a system that is a multi-dimensional stl vector
  static int InvertSystem(std::vector<std::vector<double> > &mat,
                          std::vector<std::vector<double> > &invMat);

protected:
  vtkSVPlanarMapper();
  ~vtkSVPlanarMapper();

  // Usual data generation method
  int RequestData(vtkInformation *vtkNotUsed(request),
		  vtkInformationVector **inputVector,
		  vtkInformationVector *outputVector) override;

  // Main functions in filter
  int PrepFilter(); // Prep work
  int RunFilter(); // Run operation
  int SetBoundaries(); // Sets the boundaries
  int SetInternalNodes(); // Sets the internal nodes after boundaries are done
  int SolveSystem(); // Solve the system

  // Point and edge wise functions using discrete laplace-beltrami

private:
  vtkSVPlanarMapper(const vtkSVPlanarMapper&);  // Not implemented.
  void operator=(const vtkSVPlanarMapper&);  // Not implemented.

  char *InternalIdsArrayName;

  vtkPolyData   *InitialPd;
  vtkPolyData   *WorkPd;
  vtkPolyData   *PlanarPd;
  vtkEdgeTable  *EdgeTable;
  vtkFloatArray *EdgeWeights;
  vtkIntArray   *EdgeNeighbors;
  vtkIntArray   *IsBoundary;
  vtkPolyData   *Boundaries;
  vtkPolyData   *BoundaryLoop;

  // Filter to set the boundary!
  vtkSVBoundaryMapper *BoundaryMapper;

  vtkSVSparseMatrix *ATutte;
  vtkSVSparseMatrix *AHarm;
  std::vector<double> Xu;
  std::vector<double> Xv;
  std::vector<double> Bu;
  std::vector<double> Bv;

  int RemoveInternalIds;
  double Lambda;
  double Mu;

  int Dir0;
  int Dir1;
  int Dir2;
};

#endif