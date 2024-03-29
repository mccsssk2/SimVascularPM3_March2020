!
! Copyright (c) Stanford University, The Regents of the University of
!               California, and others.
!
! All Rights Reserved.
!
! See Copyright-SimVascular.txt for additional details.
!
! Permission is hereby granted, free of charge, to any person obtaining
! a copy of this software and associated documentation files (the
! "Software"), to deal in the Software without restriction, including
! without limitation the rights to use, copy, modify, merge, publish,
! distribute, sublicense, and/or sell copies of the Software, and to
! permit persons to whom the Software is furnished to do so, subject
! to the following conditions:
!
! The above copyright notice and this permission notice shall be included
! in all copies or substantial portions of the Software.
!
! THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
! IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
! TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
! PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER
! OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
! EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
! PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
! PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
! LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
! NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
! SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
!
!--------------------------------------------------------------------
!
!     Any specific post processing before sending data to outputs is
!     done here.
!
!--------------------------------------------------------------------

!     This is a routine that performs POST/BPOST on all meshes
      SUBROUTINE ALLPOST(res, lY, lD, outGrp, iEq)
      USE COMMOD
      USE ALLFUN
      IMPLICIT NONE

      REAL(KIND=8), INTENT(OUT) :: res(maxnsd,tnNo)
      REAL(KIND=8), INTENT(IN) :: lY(tDof,tnNo), lD(tDof,tnNo)
      INTEGER, INTENT(IN) :: outGrp, iEq

      INTEGER a, Ac, iM
      REAL(KIND=8), ALLOCATABLE :: tmpV(:,:)

      DO iM=1, nMsh
         IF (ALLOCATED(tmpV)) DEALLOCATE(tmpV)
         ALLOCATE(tmpV(maxnsd,msh(iM)%nNo))
         IF (outGrp.EQ.outGrp_WSS .OR. outGrp.EQ.outGrp_trac) THEN
            CALL BPOST(msh(iM), tmpV, lY, lD, outGrp)
            DO a=1, msh(iM)%nNo
               Ac = msh(iM)%gN(a)
               res(:,Ac) = tmpV(:,a)
            END DO
         ELSE IF (outGrp .EQ. outGrp_J) THEN
            IF (ALLOCATED(tmpV)) DEALLOCATE(tmpV)
            ALLOCATE(tmpV(1,msh(iM)%nNo))
            tmpV = 0D0
            CALL TPOST(msh(iM), 1, tmpV, lD, iEq, outGrp)
            res  = 0D0
            DO a=1, msh(iM)%nNo
               Ac = msh(iM)%gN(a)
               res(1,Ac) = tmpV(1,a)
            END DO
            DEALLOCATE(tmpV)
            ALLOCATE(tmpV(maxnsd,msh(iM)%nNo))
         ELSE IF (outGrp .EQ. outGrp_divV) THEN
            IF (ALLOCATED(tmpV)) DEALLOCATE(tmpV)
            ALLOCATE(tmpV(1,msh(iM)%nNo))
            tmpV = 0D0
            CALL DIVPOST(msh(iM), tmpV, lY, lD, iEq)
            res  = 0D0
            DO a=1, msh(iM)%nNo
               Ac = msh(iM)%gN(a)
               res(1,Ac) = tmpV(1,a)
            END DO
            DEALLOCATE(tmpV)
            ALLOCATE(tmpV(maxnsd,msh(iM)%nNo))
         ELSE
            CALL POST(msh(iM), tmpV, lY, lD, outGrp, iEq)
            DO a=1, msh(iM)%nNo
               Ac = msh(iM)%gN(a)
               res(:,Ac) = tmpV(:,a)
            END DO
         END IF
      END DO

      RETURN
      END SUBROUTINE ALLPOST
!####################################################################
!     General purpose routine for post processing outputs.
      SUBROUTINE POST(lM, res, lY, lD, outGrp, iEq)
      USE COMMOD
      USE ALLFUN
      USE MATFUN
      IMPLICIT NONE

      TYPE(mshType), INTENT(INOUT) :: lM
      REAL(KIND=8), INTENT(OUT) :: res(maxnsd,lM%nNo)
      REAL(KIND=8), INTENT(IN) :: lY(tDof,tnNo), lD(tDof,tnNo)
      INTEGER, INTENT(IN) :: outGrp, iEq

      LOGICAL FSIeq
      INTEGER a, Ac, e, i, j, eNoN, g, insd
      REAL(KIND=8) rho, kappa, w, Jac, ksix(nsd,nsd), lRes(maxnsd),
     2   q(nsd), u(nsd), p, T, ux(nsd,nsd), gam, mu, mu_s
      COMPLEX*16 :: eig(nsd)

      REAL(KIND=8), ALLOCATABLE :: sA(:), sF(:,:), xl(:,:), yl(:,:),
     2   Nx(:,:), N(:)

      FSIeq = .FALSE.
      IF (eq(iEq)%phys .EQ. phys_FSI) FSIeq = .TRUE.

!     Since energy flux can be directly calculated from nodal values.
!     Note that if there are more than one domain, we need to rely on
!     element based calculations
      IF (outGrp.EQ.outGrp_eFlx .AND. .NOT.ALLOCATED(dmnId)) THEN
         rho = eq(iEq)%dmn(1)%prop(fluid_density)
         DO a=1, lM%nNo
            Ac = lM%gN(a)
            p  = lY(nsd+1,Ac)
            u  = lY(1:nsd,Ac)
            res(1:nsd,Ac) = (p + 5D-1*rho*NORM(u))*u
         END DO
         RETURN
      END IF

!     Other outputs require more calculations
      eNoN  = lM%eNoN
      ALLOCATE (sA(tnNo), sF(maxnsd,tnNo), xl(nsd,eNoN), yl(tDof,eNoN),
     2   Nx(nsd,eNoN), N(eNoN))
      sA   = 0D0
      sF   = 0D0
      lRes = 0D0
      eig  = (0D0, 0D0)
      insd = nsd
      IF (lM%lFib) insd = 1
      DO e=1, lM%nEl
         cDmn = DOMAIN(lM, iEq, e)
         IF (cDmn .EQ. 0) CYCLE
         IF (lM%eType .EQ. eType_NRB) CALL NRBNNX(lM, e)
!     Finding the norm for all the nodes of this element, including
!     those that don't belong to this face, which will be interpolated
!     from the nodes of the face
         DO a=1, eNoN
            Ac      = lM%IEN(a,e)
            xl(:,a) = x(:,Ac)
            yl(:,a) = lY(:,Ac)
            IF (FSIeq) THEN
               xl(:,a)     = xl(:,a)     + lD(nsd+2:2*nsd+1,Ac)
               yl(1:nsd,a) = yl(1:nsd,a) - lY(nsd+2:2*nsd+1,Ac)
            END IF
         END DO

         DO g=1, lM%nG
            IF (g.EQ.1 .OR. .NOT.lM%lShpF) THEN
               CALL GNN(eNoN, insd, lM%Nx(:,:,g), xl, Nx, Jac, ksix)
            END IF
            w = lM%w(g)*Jac
            N = lM%N(:,g)

            lRes(:) = 0D0

!     Vorticity calculation   ---------------------------------------
            IF (outGrp .EQ. outGrp_vort) THEN
               DO a=1, eNoN
                  IF (nsd .EQ. 2) THEN
                     lRes(3) = lRes(3)+ Nx(1,a)*yl(2,a)- Nx(2,a)*yl(1,a)
                  ELSE
                     lRes(1) = lRes(1)+ Nx(2,a)*yl(3,a)- Nx(3,a)*yl(2,a)
                     lRes(2) = lRes(2)+ Nx(3,a)*yl(1,a)- Nx(1,a)*yl(3,a)
                     lRes(3) = lRes(3)+ Nx(1,a)*yl(2,a)- Nx(2,a)*yl(1,a)
                  END IF
               END DO
!     Vortex Identification Criterion (lamda_ci)
            ELSE IF (outGrp .EQ. outGrp_vortex) THEN
               ux   = 0D0
               DO a=1, eNoN
                  DO i=1, nsd
                     DO j=1, nsd
                        ux(i,j) = ux(i,j) + Nx(i,a)*yl(j,a)
                     END DO
                  END DO
               END DO
               eig = MAT_EIG(ux, nsd)
               lRes(1:nsd) = AIMAG(eig)
               lRes(1) = MAXVAL(lRes(1:nsd))
               lRes(2:maxnsd) = 0D0
!     Energy flux calculation   -------------------------------------
            ELSE IF (outGrp .EQ. outGrp_eFlx) THEN
               rho = eq(iEq)%dmn(cDmn)%prop(fluid_density)
               p   = 0D0
               u   = 0D0
               DO a=1, eNoN
                  p = p + N(a)*yl(nsd+1,a)
                  u = u + N(a)*yl(1:nsd,a)
               END DO
               lRes(1:nsd) = (p + 5D-1*rho*NORM(u))*u
!     Heat flux calculation   ---------------------------------------
            ELSE IF (outGrp .EQ. outGrp_hFlx) THEN
               kappa = eq(iEq)%dmn(cDmn)%prop(conductivity)
               i     = eq(iEq)%s
               DO a=1, eNoN
               END DO
               IF (eq(iEq)%phys .EQ. phys_heatF) THEN
                  u = 0D0
                  T = 0D0
                  q = 0D0
                  DO a=1, eNoN
                     q = q + Nx(:,a)*yl(i,a)
                     u = u + N(a)*yl(1:nsd,a)
                     T = T + N(a)*yl(i,a)
                  END DO
                  lRes(1:nsd) = u*T - kappa*q
               ELSE
                  q = 0D0
                  DO a=1, eNoN
                     q = q + Nx(:,a)*yl(i,a)
                  END DO
                  lRes(1:nsd) = -kappa*q
               END IF
!     Strain tensor invariants calculation   ------------------------
            ELSE IF (outGrp .EQ. outGrp_stInv) THEN
               ksix = 0D0
               DO a=1, eNoN
                  ksix(1,1) = ksix(1,1) + Nx(1,a)*yl(1,a)
                  ksix(2,1) = ksix(2,1) +(Nx(1,a)*yl(2,a)
     2                                  + Nx(2,a)*yl(1,a))/2D0
                  ksix(2,2) = ksix(2,2) + Nx(2,a)*yl(2,a)
                  IF (nsd .EQ. 3) THEN
                     ksix(3,1) = ksix(3,1) +(Nx(1,a)*yl(3,a)
     2                                     + Nx(3,a)*yl(1,a))/2D0
                     ksix(3,2) = ksix(3,2) +(Nx(2,a)*yl(3,a)
     2                                     + Nx(3,a)*yl(2,a))/2D0
                     ksix(3,3) = ksix(3,3) + Nx(3,a)*yl(3,a)
                  END IF
               END DO
               IF (nsd .EQ. 2) THEN
                  lRes(1) = ksix(1,1) + ksix(2,2)
                  lRes(2) = ksix(1,1)*ksix(2,2) - ksix(2,1)*ksix(2,1)
               ELSE
                  lRes(1) = ksix(1,1) + ksix(2,2) + ksix(3,3)
                  lRes(2) = ksix(1,1)*ksix(2,2) + ksix(2,2)*ksix(3,3)
     2                    + ksix(3,3)*ksix(1,1) - ksix(2,1)*ksix(2,1)
     3                    - ksix(3,1)*ksix(3,1) - ksix(3,2)*ksix(3,2)
                  lRes(3) = ksix(1,1)*ksix(2,2)*ksix(3,3)
     2                    + ksix(2,1)*ksix(3,2)*ksix(3,1)*2D0
     3                    - ksix(1,1)*ksix(3,2)*ksix(3,2)
     4                    - ksix(3,1)*ksix(2,2)*ksix(3,1)
     5                    - ksix(2,1)*ksix(2,1)*ksix(3,3)
               END IF
               lRes = ABS(lRes)
!     Viscosity
            ELSE IF (outGrp .EQ. outGrp_Visc) THEN
               ux = 0D0
               DO a=1, eNoN
                  DO i=1, nsd
                     DO j=1, nsd
                        ux(i,j) = ux(i,j) + Nx(i,a)*yl(j,a)
                     END DO
                  END DO
               END DO

!              Shear rate, gam := (2*e_ij*e_ij)^0.5
               gam = 0D0
               DO i=1, nsd
                  DO j=1, nsd
                     gam = gam + (ux(i,j)+ux(j,i))*(ux(i,j)+ux(j,i))
                  END DO
               END DO
               gam = SQRT(0.5D0*gam)
!              Compute viscosity
               CALL GETVISCOSITY(eq(iEq)%dmn(cDmn), gam, mu, mu_s, mu_s)
               lRes(1) = mu
            ELSE
               err = "Correction is required in POST"
            END IF

!     Mapping Tau into the nodes by assembling it into a local vector
            DO a=1, eNoN
               Ac       = lM%IEN(a,e)
               sA(Ac)   = sA(Ac)   + w*N(a)
               sF(:,Ac) = sF(:,Ac) + w*N(a)*lRes
            END DO
         END DO
      END DO

      CALL COMMU(sF)
      CALL COMMU(sA)

      DO a=1, lM%nNo
         Ac       = lM%gN(a)
         res(:,a) = sF(:,Ac)/sA(Ac)
      END DO

      RETURN
      END SUBROUTINE POST
!####################################################################
!     General purpose routine for post processing outputs at the
!     faces. Currently this calculates WSS, which is t.n - (n.t.n)n
!     Here t is stress tensor: t = \mu (grad(u) + grad(u)^T)
      SUBROUTINE BPOST(lM, res, lY, lD, outGrp)
      USE COMMOD
      USE ALLFUN
      IMPLICIT NONE

      TYPE(mshType), INTENT(INOUT) :: lM
      REAL(KIND=8), INTENT(OUT) :: res(maxnsd,lM%nNo)
      REAL(KIND=8), INTENT(IN) :: lY(tDof,tnNo), lD(tDof,tnNo)
      INTEGER, INTENT(IN) :: outGrp

      LOGICAL FSIeq
      INTEGER a, Ac, e, Ec, i, j, iEq, iFa, eNoN, g
      REAL(KIND=8) Tdn(nsd), ndTdn, taue(nsd), ux(nsd,nsd), mu, w,
     2   nV(nsd), Jac, ks(nsd,nsd), lRes(maxnsd), p, gam, mu_s
      REAL(KIND=8), ALLOCATABLE :: sA(:), sF(:,:), gnV(:,:), lnV(:,:),
     2   xl(:,:), ul(:,:), Nx(:,:), N(:), pl(:)

      iEq   = 1
      eNoN  = lM%eNoN
      FSIeq = .FALSE.
      IF (eq(iEq)%phys .EQ. phys_FSI) FSIeq = .TRUE.

      ALLOCATE (sA(tnNo), sF(maxnsd,tnNo), gnV(nsd,tnNo),
     2   lnV(nsd,eNoN), xl(nsd,eNoN), ul(nsd,eNoN), Nx(nsd,eNoN),
     3   N(eNoN), pl(eNoN))
      sA   = 0D0
      sF   = 0D0
      gnV  = 0D0
      lRes = 0D0
!     First creating the norm field
      DO iFa=1, lM%nFa
         DO a=1, lM%fa(iFa)%nNo
            Ac        = lM%fa(iFa)%gN(a)
            gnV(:,Ac) = lM%fa(iFa)%nV(:,a)
         END DO
      END DO

      IF (outGrp.NE.outGrp_WSS .AND. outGrp.NE.outGrp_trac) err =
     2   "Invalid output group. Correction is required in BPOST"

      DO iFa=1, lM%nFa
         DO e=1, lM%fa(iFa)%nEl
            Ec = lM%fa(iFa)%gE(e)
            cDmn = DOMAIN(lM, iEq, Ec)
            IF (cDmn .EQ. 0) CYCLE
            IF (lM%eType .EQ. eType_NRB) CALL NRBNNX(lM, Ec)
!     Finding the norm for all the nodes of this element, including
!     those that don't belong to this face, which will be inerpolated
!     from the nodes of the face
            nV = 0D0
            DO a=1, eNoN
               Ac       = lM%IEN(a,Ec)
               lnV(:,a) = gnV(:,Ac)
               nV       = nV + lnV(:,a)
               xl(:,a)  = x(:,Ac)
               IF (FSIeq) THEN
                  xl(:,a) = xl(:,a)      + lD(nsd+2:2*nsd+1,Ac)
                  ul(:,a) = lY(1:nsd,Ac) - lY(nsd+2:2*nsd+1,Ac)
               ELSE
                  ul(:,a) = lY(1:nsd,Ac)
               END IF
               pl(a)    = lY(nsd+1,Ac)
            END DO
            nV = nV/lM%fa(iFa)%eNoN
            DO a=1, eNoN
               IF (ISZERO(NORM(lnV(:,a)))) lnV(:,a) = nV
            END DO
            DO g=1, lM%nG
               IF (g.EQ.1 .OR. .NOT.lM%lShpF) THEN
                  CALL GNN(eNoN, nsd, lM%Nx(:,:,g), xl, Nx, Jac, ks)
               END IF
               w = lM%w(g)*Jac
               N = lM%N(:,g)

!     Calculating ux = grad(u) and nV at a Gauss point
               ux = 0D0
               nV = 0D0
               p  = 0D0
               DO a=1, eNoN
                  nV = nV + N(a)*lnV(:,a)
                  p  = p  + N(a)*pl(a)
                  DO i=1, nsd
                     DO j=1, nsd
                        ux(i,j) = ux(i,j) + Nx(i,a)*ul(j,a)
                     END DO
                  END DO
               END DO

!              Shear rate, gam := (2*e_ij*e_ij)^0.5
               gam = 0D0
               DO i=1, nsd
                  DO j=1, nsd
                     gam = gam + (ux(i,j)+ux(j,i))*(ux(i,j)+ux(j,i))
                  END DO
               END DO
               gam = SQRT(0.5D0*gam)
!              Compute viscosity
               CALL GETVISCOSITY(eq(iEq)%dmn(cDmn), gam, mu, mu_s, mu_s)

!     Now finding grad(u).n and n.grad(u).n
               Tdn   = 0D0
               ndTdn = 0D0
               DO i=1,nsd
                  DO j=1, nsd
                     Tdn(i) = Tdn(i) + mu*(ux(i,j) + ux(j,i))*nV(j)
                  END DO
                  ndTdn = ndTdn + Tdn(i)*nV(i)
               END DO
               taue = Tdn - ndTdn*nV

               IF (outGrp .EQ. outGrp_WSS) THEN
                  lRes(1:nsd) = -taue
               ELSE IF (outGrp .EQ. outGrp_trac) THEN
                  lRes(1:nsd) = p*nV - Tdn
               END IF

!     Mapping Tau into the nodes by assembling it into a local vector
               DO a=1, eNoN
                  Ac       = lM%IEN(a,Ec)
                  sA(Ac)   = sA(Ac)   + w*N(a)
                  sF(:,Ac) = sF(:,Ac) + w*N(a)*lRes
               END DO
            END DO
         END DO
      END DO

      CALL COMMU(sF)
      CALL COMMU(sA)

      DO iFa=1, lM%nFa
         DO a=1, lM%fa(iFa)%nNo
            Ac = lM%fa(iFa)%gN(a)
            IF (.NOT.ISZERO(sA(Ac))) THEN
               sF(:,Ac) = sF(:,Ac)/sA(Ac)
               sA(Ac)   = 1D0
            END IF
         END DO
      END DO

      res = 0D0
      DO a=1, lM%nNo
         Ac       = lM%gN(a)
         res(:,a) = sF(:,Ac)
      END DO

      RETURN
      END SUBROUTINE BPOST
!####################################################################
!     Routine for post processing stress tensor
      SUBROUTINE TPOST(lM, m, res, lD, iEq, outGrp)
      USE COMMOD
      USE ALLFUN
      USE MATFUN
      IMPLICIT NONE

      TYPE(mshType), INTENT(INOUT) :: lM
      INTEGER, INTENT(IN) :: m, iEq, outGrp
      REAL(KIND=8), INTENT(INOUT) :: res(m,lM%nNo)
      REAL(KIND=8), INTENT(IN) :: lD(tDof,tnNo)

      INTEGER a, e, g, Ac, eNoN, i, j, k, l, cPhys, insd, nFn
      REAL(KIND=8) w, Jac, detF, ya, Ja, elM, nu, lambda, mu,
     2   ksix(nsd,nsd), F(nsd,nsd), S(nsd,nsd), P(nsd,nsd),
     3   sigma(nsd,nsd), CC(nsd,nsd,nsd,nsd)
      REAL(KIND=8), ALLOCATABLE :: xl(:,:), dl(:,:), fN(:,:), pSl(:),
     2   ed(:), Nx(:,:), N(:), sA(:), sF(:,:)
      TYPE(stModelType) :: stModel

      eNoN = lM%eNoN
      dof  = eq(iEq)%dof
      i    = eq(iEq)%s
      j    = i + 1
      k    = j + 1
      nFn  = lM%nFn
      IF (nFn .EQ. 0) nFn = 1

      ALLOCATE (sA(tnNo), sF(m,tnNo), xl(nsd,eNoN), dl(tDof,eNoN),
     2   fN(nsd,nFn), pSl(m), ed(m), Nx(nsd,eNoN), N(eNoN))

      sA   = 0D0
      sF   = 0D0
      insd = nsd
      ya   = 0D0
      IF (lM%lFib) insd = 1
      DO e=1, lM%nEl
         cDmn  = DOMAIN(lM, iEq, e)
         cPhys = eq(iEq)%dmn(cDmn)%phys
         IF (cPhys .NE. phys_struct .AND.
     2       cPhys .NE. phys_vms_struct .AND.
     3       cPhys .NE. phys_lElas) CYCLE

         IF (cPhys .EQ. phys_lElas) THEN
            elM = eq(cEq)%dmn(cDmn)%prop(elasticity_modulus)
            nu  = eq(cEq)%dmn(cDmn)%prop(poisson_ratio)
            lambda = elM*nu/(1D0 + nu)/(1D0 - 2D0*nu)
            mu     = 0.5D0*elM/(1D0 + nu)
         END IF

         IF (lM%eType .EQ. eType_NRB) CALL NRBNNX(lM, e)

         fN = 0D0
         IF (ALLOCATED(lM%fN)) THEN
            DO l=1, nFn
               fN(:,l) = lM%fN((l-1)*nsd+1:l*nsd,e)
            END DO
         END IF

         DO a=1, eNoN
            Ac      = lM%IEN(a,e)
            xl(:,a) = x(:,Ac)
            dl(:,a) = lD(:,Ac)
         END DO

         stModel = eq(iEq)%dmn(cDmn)%stM
         DO g=1, lM%nG
            IF (g.EQ.1 .OR. .NOT.lM%lShpF) THEN
               CALL GNN(eNoN, insd, lM%Nx(:,:,g), xl, Nx, Jac, ksix)
            END IF
            w = lM%w(g)*Jac
            N = lM%N(:,g)

            ed = 0D0
            F  = MAT_ID(nsd)
            IF (cPhys .EQ. phys_lElas) THEN
               DO a=1, eNoN
                  IF (nsd .EQ. 3) THEN
                     ed(1) = ed(1) + Nx(1,a)*dl(i,a)
                     ed(2) = ed(2) + Nx(2,a)*dl(j,a)
                     ed(3) = ed(3) + Nx(3,a)*dl(k,a)
                     ed(4) = ed(4) + Nx(2,a)*dl(i,a) + Nx(1,a)*dl(j,a)
                     ed(5) = ed(5) + Nx(3,a)*dl(i,a) + Nx(1,a)*dl(k,a)
                     ed(6) = ed(6) + Nx(3,a)*dl(j,a) + Nx(2,a)*dl(k,a)
                  ELSE
                     ed(1) = ed(1) + Nx(1,a)*dl(i,a)
                     ed(2) = ed(2) + Nx(2,a)*dl(j,a)
                     ed(3) = ed(3) + Nx(2,a)*dl(i,a) + Nx(1,a)*dl(j,a)
                  END IF
               END DO
            ELSE
               DO a=1, eNoN
                  IF (nsd .EQ. 3) THEN
                     F(1,1) = F(1,1) + Nx(1,a)*dl(i,a)
                     F(1,2) = F(1,2) + Nx(2,a)*dl(i,a)
                     F(1,3) = F(1,3) + Nx(3,a)*dl(i,a)
                     F(2,1) = F(2,1) + Nx(1,a)*dl(j,a)
                     F(2,2) = F(2,2) + Nx(2,a)*dl(j,a)
                     F(2,3) = F(2,3) + Nx(3,a)*dl(j,a)
                     F(3,1) = F(3,1) + Nx(1,a)*dl(k,a)
                     F(3,2) = F(3,2) + Nx(2,a)*dl(k,a)
                     F(3,3) = F(3,3) + Nx(3,a)*dl(k,a)
                  ELSE
                     F(1,1) = F(1,1) + Nx(1,a)*dl(i,a)
                     F(1,2) = F(1,2) + Nx(2,a)*dl(i,a)
                     F(2,1) = F(2,1) + Nx(1,a)*dl(j,a)
                     F(2,2) = F(2,2) + Nx(2,a)*dl(j,a)
                  END IF
               END DO
            END IF
            detF = MAT_DET(F, nsd)

            IF (outGrp .EQ. outGrp_J) THEN
!           Jacobian := determinant of deformation gradient tensor
               DO a=1, eNoN
                  Ac       = lM%IEN(a,e)
                  sA(Ac)   = sA(Ac)   + w*N(a)
                  sF(1,Ac) = sF(1,Ac) + w*N(a)*detF
               END DO

            ELSE IF (outGrp .EQ. outGrp_stress) THEN
!           2nd Piola-Kirchhoff (S) and material stiffness (CC) tensors
               sigma = 0D0
               IF (cPhys .EQ. phys_lElas) THEN
                  IF (nsd .EQ. 3) THEN
                     detF = lambda*(ed(1) + ed(2) + ed(3))
                     sigma(1,1) = detF + 2D0*mu*ed(1)
                     sigma(2,2) = detF + 2D0*mu*ed(2)
                     sigma(3,3) = detF + 2D0*mu*ed(3)
                     sigma(1,2) = mu*ed(4)
                     sigma(1,3) = mu*ed(5)
                     sigma(2,3) = mu*ed(6)
                  ELSE
                     detF = lambda*(ed(1) + ed(2))
                     sigma(1,1) = detF + 2D0*mu*ed(1)
                     sigma(2,2) = detF + 2D0*mu*ed(2)
                     sigma(1,2) = mu*ed(3)
                  END IF
               ELSE IF (cPhys .EQ. phys_vms_struct) THEN
                  CALL GETPK2CCdev(stModel, F, nFn, fN, ya, S, CC, Ja)
                  P = MATMUL(F, S)
                  sigma = MATMUL(P, TRANSPOSE(F))
                  IF (.NOT.ISZERO(detF)) sigma(:,:) = sigma(:,:) / detF
               ELSE IF (cPhys .EQ. phys_struct) THEN
                  CALL GETPK2CC(stModel, F, nFn, fN, ya, S, CC)
                  sigma = S
               END IF

               IF (nsd .EQ. 3) THEN
                  pSl(1) = sigma(1,1)
                  pSl(2) = sigma(2,2)
                  pSl(3) = sigma(3,3)
                  pSl(4) = sigma(1,2)
                  pSl(5) = sigma(1,3)
                  pSl(6) = sigma(2,3)
               ELSE
                  pSl(1) = sigma(1,1)
                  pSl(2) = sigma(2,2)
                  pSl(3) = sigma(1,2)
               END IF

               DO a=1, eNoN
                  Ac       = lM%IEN(a,e)
                  sA(Ac)   = sA(Ac)   + w*N(a)
                  sF(:,Ac) = sF(:,Ac) + w*N(a)*pSl(:)
               END DO

            ELSE IF (outGrp .EQ. outGrp_F) THEN
!           Deformation gradient tensor (F)
               ! pSl is used to remap F
               IF (nsd .EQ. 3) THEN
                  pSl(1) = F(1,1)
                  pSl(2) = F(1,2)
                  pSl(3) = F(1,3)
                  pSl(4) = F(2,1)
                  pSl(5) = F(2,2)
                  pSl(6) = F(2,3)
                  pSl(7) = F(3,1)
                  pSl(8) = F(3,2)
                  pSl(9) = F(3,3)
               ELSE
                  pSl(1) = F(1,1)
                  pSl(2) = F(1,2)
                  pSl(3) = F(2,1)
                  pSl(4) = F(2,2)
               END IF

               DO a=1, eNoN
                  Ac       = lM%IEN(a,e)
                  sA(Ac)   = sA(Ac)   + w*N(a)
                  sF(:,Ac) = sF(:,Ac) + w*N(a)*pSl(:)
               END DO
            END IF
         END DO
      END DO

      CALL COMMU(sF)
      CALL COMMU(sA)

      DO a=1, lM%nNo
         Ac = lM%gN(a)
         IF (.NOT. iszero(sA(Ac))) THEN
           res(:,a) = res(:,a) + sF(:,Ac)/sA(Ac)
         ENDIF
      END DO

      DEALLOCATE (sA, sF, xl, dl, fN, pSl, N, Nx)

      RETURN
      END SUBROUTINE TPOST
!####################################################################
!     Routine for post processing fiber directions
      SUBROUTINE FIBDIRPOST(lM, nFn, res, lD, iEq)
      USE COMMOD
      USE ALLFUN
      USE MATFUN
      IMPLICIT NONE

      INTEGER, INTENT(IN) :: iEq, nFn
      TYPE(mshType), INTENT(INOUT) :: lM
      REAL(KIND=8), INTENT(INOUT) :: res(nFn*nsd,lM%nNo)
      REAL(KIND=8), INTENT(IN) :: lD(tDof,tnNo)

      INTEGER a, b, e, g, Ac, eNoN, i, j, k, l, iFn, cPhys
      REAL(KIND=8) w, Jac, F(nsd,nsd)
      REAL(KIND=8), ALLOCATABLE :: xl(:,:), dl(:,:), fN(:,:), fl(:,:),
     2   Nx(:,:), N(:), sA(:), sF(:,:)

      eNoN = lM%eNoN
      dof  = eq(iEq)%dof
      i    = eq(iEq)%s
      j    = i + 1
      k    = j + 1

      ALLOCATE (sA(tnNo), sF(nFn*nsd,tnNo), xl(nsd,eNoN), dl(tDof,eNoN),
     2   fN(nsd,lM%nFn), fl(nsd,lM%nFn), Nx(nsd,eNoN), N(eNoN))

      sA = 0D0
      sF = 0D0
      DO e=1, lM%nEl
         cDmn  = DOMAIN(lM, iEq, e)
         cPhys = eq(iEq)%dmn(cDmn)%phys
         IF (lM%eType .EQ. eType_NRB) CALL NRBNNX(lM, e)

         DO a=1, eNoN
            Ac       = lM%IEN(a,e)
            xl(:,a)  = x(:,Ac)
            dl(:,a)  = lD(:,Ac)
         END DO

         DO iFn=1, lM%nFn
            fN(:,iFn) = lM%fN((iFn-1)*nsd+1:iFn*nsd,e)
         END DO

         DO g=1, lM%nG
            IF (g.EQ.1 .OR. .NOT.lM%lShpF) THEN
               CALL GNN(eNoN, nsd, lM%Nx(:,:,g), xl, Nx, Jac, F)
            END IF
            w = lM%w(g)*Jac
            N = lM%N(:,g)

            F  = MAT_ID(nsd)
            DO a=1, eNoN
               IF (nsd .EQ. 3) THEN
                  F(1,1) = F(1,1) + Nx(1,a)*dl(i,a)
                  F(1,2) = F(1,2) + Nx(2,a)*dl(i,a)
                  F(1,3) = F(1,3) + Nx(3,a)*dl(i,a)
                  F(2,1) = F(2,1) + Nx(1,a)*dl(j,a)
                  F(2,2) = F(2,2) + Nx(2,a)*dl(j,a)
                  F(2,3) = F(2,3) + Nx(3,a)*dl(j,a)
                  F(3,1) = F(3,1) + Nx(1,a)*dl(k,a)
                  F(3,2) = F(3,2) + Nx(2,a)*dl(k,a)
                  F(3,3) = F(3,3) + Nx(3,a)*dl(k,a)
               ELSE
                  F(1,1) = F(1,1) + Nx(1,a)*dl(i,a)
                  F(1,2) = F(1,2) + Nx(2,a)*dl(i,a)
                  F(2,1) = F(2,1) + Nx(1,a)*dl(j,a)
                  F(2,2) = F(2,2) + Nx(2,a)*dl(j,a)
               END IF
            END DO

            DO iFn=1, lM%nFn
               fl(:,iFn) = MATMUL(F, fN(:,iFn))
               fl(:,iFn) = fl(:,iFn)/SQRT(NORM(fl(:,iFn)))
            END DO

            DO a=1, eNoN
               Ac     = lM%IEN(a,e)
               sA(Ac) = sA(Ac) + w*N(a)
               DO iFn=1, lM%nFn
                  b = (iFn-1)*nsd
                  DO l=1, nsd
                     sF(b+l,Ac) = sF(b+l,Ac) + w*N(a)*fl(l,iFn)
                  END DO
               END DO
            END DO
         END DO
      END DO

      CALL COMMU(sF)
      CALL COMMU(sA)

      DO a=1, lM%nNo
         Ac = lM%gN(a)
         IF (.NOT.ISZERO(sA(Ac))) THEN
            res(:,a) = res(:,a) + sF(:,Ac)/sA(Ac)
         ENDIF
      END DO

      DEALLOCATE (sA, sF, xl, dl, fN, fl, N, Nx)

      RETURN
      END SUBROUTINE FIBDIRPOST
!--------------------------------------------------------------------
!     Routine for post processing fiber alignment
      SUBROUTINE FIBALGNPOST(lM, res, lD, iEq)
      USE COMMOD
      USE ALLFUN
      USE MATFUN
      IMPLICIT NONE

      INTEGER, INTENT(IN) :: iEq
      TYPE(mshType), INTENT(INOUT) :: lM
      REAL(KIND=8), INTENT(INOUT) :: res(1,lM%nNo)
      REAL(KIND=8), INTENT(IN) :: lD(tDof,tnNo)

      INTEGER a, e, g, Ac, eNoN, i, j, k, iFn, cPhys
      REAL(KIND=8) w, Jac, sHat, F(nsd,nsd)
      REAL(KIND=8), ALLOCATABLE :: xl(:,:), dl(:,:), fN(:,:), fl(:,:),
     2   Nx(:,:), N(:), sA(:), sF(:)

      eNoN = lM%eNoN
      dof  = eq(iEq)%dof
      i    = eq(iEq)%s
      j    = i + 1
      k    = j + 1

      ALLOCATE (sA(tnNo), sF(tnNo), xl(nsd,eNoN), dl(tDof,eNoN),
     2   fN(nsd,2), fl(nsd,2), Nx(nsd,eNoN), N(eNoN))

      sA = 0D0
      sF = 0D0
      DO e=1, lM%nEl
         cDmn  = DOMAIN(lM, iEq, e)
         cPhys = eq(iEq)%dmn(cDmn)%phys
         IF (cPhys .NE. phys_struct .AND.
     2       cPhys .NE. phys_vms_struct) CYCLE
         IF (lM%eType .EQ. eType_NRB) CALL NRBNNX(lM, e)

         DO a=1, eNoN
            Ac       = lM%IEN(a,e)
            xl(:,a)  = x(:,Ac)
            dl(:,a)  = lD(:,Ac)
         END DO

         fN(:,1) = lM%fN(1:nsd,e)
         fN(:,2) = lM%fN(nsd+1:2*nsd,e)

         DO g=1, lM%nG
            IF (g.EQ.1 .OR. .NOT.lM%lShpF) THEN
               CALL GNN(eNoN, nsd, lM%Nx(:,:,g), xl, Nx, Jac, F)
            END IF
            w = lM%w(g)*Jac
            N = lM%N(:,g)

            F  = MAT_ID(nsd)
            DO a=1, eNoN
               IF (nsd .EQ. 3) THEN
                  F(1,1) = F(1,1) + Nx(1,a)*dl(i,a)
                  F(1,2) = F(1,2) + Nx(2,a)*dl(i,a)
                  F(1,3) = F(1,3) + Nx(3,a)*dl(i,a)
                  F(2,1) = F(2,1) + Nx(1,a)*dl(j,a)
                  F(2,2) = F(2,2) + Nx(2,a)*dl(j,a)
                  F(2,3) = F(2,3) + Nx(3,a)*dl(j,a)
                  F(3,1) = F(3,1) + Nx(1,a)*dl(k,a)
                  F(3,2) = F(3,2) + Nx(2,a)*dl(k,a)
                  F(3,3) = F(3,3) + Nx(3,a)*dl(k,a)
               ELSE
                  F(1,1) = F(1,1) + Nx(1,a)*dl(i,a)
                  F(1,2) = F(1,2) + Nx(2,a)*dl(i,a)
                  F(2,1) = F(2,1) + Nx(1,a)*dl(j,a)
                  F(2,2) = F(2,2) + Nx(2,a)*dl(j,a)
               END IF
            END DO

            DO iFn=1, 2
               fl(:,iFn) = MATMUL(F, fN(:,iFn))
               fl(:,iFn) = fl(:,iFn)/SQRT(NORM(fl(:,iFn)))
            END DO
            sHat = NORM(fl(:,1), fl(:,2))

            DO a=1, eNoN
               Ac     = lM%IEN(a,e)
               sA(Ac) = sA(Ac) + w*N(a)
               sF(Ac) = sF(Ac) + w*N(a)*sHat
            END DO
         END DO
      END DO

      CALL COMMU(sF)
      CALL COMMU(sA)

      DO a=1, lM%nNo
         Ac = lM%gN(a)
         IF (.NOT.ISZERO(sA(Ac))) THEN
           res(1,a) = res(1,a) + sF(Ac)/sA(Ac)
         ENDIF
      END DO

      DEALLOCATE (sA, sF, xl, dl, fN, fl, N, Nx)

      RETURN
      END SUBROUTINE FIBALGNPOST
!####################################################################
!     Compute fiber stretch based on 4th invariant: I_{4,f}
      SUBROUTINE FIBSTRETCH(iEq, lM, lD, res)
      USE COMMOD
      USE ALLFUN
      IMPLICIT NONE

      INTEGER, INTENT(IN) :: iEq
      TYPE(mshType), INTENT(IN) :: lM
      REAL(KIND=8), INTENT(IN) :: lD(tDof,tnNo)
      REAL(KIND=8), INTENT(INOUT) :: res(lM%nNo)

      INTEGER a, e, g, Ac, eNoN, i, j, k, cPhys
      REAL(KIND=8) w, Jac, I4f, fl(nsd), F(nsd,nsd)
      REAL(KIND=8), ALLOCATABLE :: xl(:,:), dl(:,:), Nx(:,:), N(:),
     2   sA(:), sF(:)

      eNoN = lM%eNoN
      dof  = eq(iEq)%dof
      i    = eq(iEq)%s
      j    = i + 1
      k    = j + 1

      ALLOCATE (sA(tnNo), sF(tnNo), xl(nsd,eNoN), dl(tDof,eNoN),
     2   Nx(nsd,eNoN), N(eNoN))

      sA = 0D0
      sF = 0D0
      DO e=1, lM%nEl
         cDmn  = DOMAIN(lM, iEq, e)
         cPhys = eq(iEq)%dmn(cDmn)%phys
         IF (lM%eType .EQ. eType_NRB) CALL NRBNNX(lM, e)

         DO a=1, eNoN
            Ac       = lM%IEN(a,e)
            xl(:,a)  = x(:,Ac)
            dl(:,a)  = lD(:,Ac)
         END DO

         DO g=1, lM%nG
            IF (g.EQ.1 .OR. .NOT.lM%lShpF) THEN
               CALL GNN(eNoN, nsd, lM%Nx(:,:,g), xl, Nx, Jac, F)
            END IF
            w = lM%w(g)*Jac
            N = lM%N(:,g)

            F  = MAT_ID(nsd)
            DO a=1, eNoN
               IF (nsd .EQ. 3) THEN
                  F(1,1) = F(1,1) + Nx(1,a)*dl(i,a)
                  F(1,2) = F(1,2) + Nx(2,a)*dl(i,a)
                  F(1,3) = F(1,3) + Nx(3,a)*dl(i,a)
                  F(2,1) = F(2,1) + Nx(1,a)*dl(j,a)
                  F(2,2) = F(2,2) + Nx(2,a)*dl(j,a)
                  F(2,3) = F(2,3) + Nx(3,a)*dl(j,a)
                  F(3,1) = F(3,1) + Nx(1,a)*dl(k,a)
                  F(3,2) = F(3,2) + Nx(2,a)*dl(k,a)
                  F(3,3) = F(3,3) + Nx(3,a)*dl(k,a)
               ELSE
                  F(1,1) = F(1,1) + Nx(1,a)*dl(i,a)
                  F(1,2) = F(1,2) + Nx(2,a)*dl(i,a)
                  F(2,1) = F(2,1) + Nx(1,a)*dl(j,a)
                  F(2,2) = F(2,2) + Nx(2,a)*dl(j,a)
               END IF
            END DO

            fl  = MATMUL(F, lM%fN(1:nsd,e))
            I4f = NORM(fl)
            DO a=1, eNoN
               Ac     = lM%IEN(a,e)
               sA(Ac) = sA(Ac) + w*N(a)
               sF(Ac) = sF(Ac) + w*N(a)*I4f
            END DO
         END DO
      END DO

      CALL COMMU(sF)
      CALL COMMU(sA)

      res = 0D0
      DO a=1, lM%nNo
         Ac = lM%gN(a)
         IF (.NOT.ISZERO(sA(Ac))) THEN
            res(a) = res(a) + sF(Ac)/sA(Ac)
         ENDIF
      END DO

      DEALLOCATE (sA, sF, xl, dl, N, Nx)

      RETURN
      END SUBROUTINE FIBSTRETCH
!####################################################################
!     Routine for post processing divergence of velocity
      SUBROUTINE DIVPOST(lM, res, lY, lD, iEq)
      USE COMMOD
      USE ALLFUN
      USE MATFUN
      IMPLICIT NONE

      TYPE(mshType), INTENT(INOUT) :: lM
      INTEGER, INTENT(IN) :: iEq
      REAL(KIND=8), INTENT(INOUT) :: res(1,lM%nNo)
      REAL(KIND=8), INTENT(IN) :: lY(tDof,tnNo), lD(tDof,tnNo)

      INTEGER a, e, g, Ac, eNoN, i, j, k, cPhys
      REAL(KIND=8) w, Jac, divV, vx(nsd,nsd), ksix(nsd,nsd), F(nsd,nsd),
     2   Fi(nsd,nsd), VxFi(nsd)
      REAL(KIND=8), ALLOCATABLE :: xl(:,:), yl(:,:), dl(:,:), N(:),
     2   Nx(:,:), sA(:), sF(:)

      eNoN = lM%eNoN
      dof  = eq(iEq)%dof
      i    = eq(iEq)%s
      j    = i + 1
      k    = j + 1

      ALLOCATE (sA(tnNo), sF(tnNo), xl(nsd,eNoN), yl(tDof,eNoN),
     2   dl(tDof,eNoN), N(eNoN), Nx(nsd,eNoN))

      sA   = 0D0
      sF   = 0D0
      DO e=1, lM%nEl
         IF (lM%eType .EQ. eType_NRB) CALL NRBNNX(lM, e)
         cDmn  = DOMAIN(lM, iEq, e)
         cPhys = eq(iEq)%dmn(cDmn)%phys

         DO a=1, eNoN
            Ac      = lM%IEN(a,e)
            xl(:,a) = x(:,Ac)
            yl(:,a) = lY(:,Ac)
            dl(:,a) = lD(:,Ac)
         END DO

         DO g=1, lM%nG
            IF (g.EQ.1 .OR. .NOT.lM%lShpF) THEN
               CALL GNN(eNoN, nsd, lM%Nx(:,:,g), xl, Nx, Jac, ksix)
            END IF
            w = lM%w(g)*Jac
            N = lM%N(:,g)

            IF ((cPhys.EQ.phys_fluid) .OR. (cPhys.EQ.phys_CMM)) THEN
               vx = 0D0
               IF (nsd .EQ. 3) THEN
                  DO a=1, eNoN
                     vx(1,1) = vx(1,1) + Nx(1,a)*yl(1,a)
                     vx(2,2) = vx(2,2) + Nx(2,a)*yl(2,a)
                     vx(3,3) = vx(3,3) + Nx(3,a)*yl(3,a)
                  END DO
                  divV = vx(1,1) + vx(2,2) + vx(3,3)
               ELSE
                  DO a=1, eNoN
                     vx(1,1) = vx(1,1) + Nx(1,a)*yl(1,a)
                     vx(2,2) = vx(2,2) + Nx(2,a)*yl(2,a)
                  END DO
                  divV = vx(1,1) + vx(2,2)
               END IF

            ELSE IF (cPhys .EQ. phys_vms_struct) THEN
               vx = 0D0
               F  = MAT_ID(nsd)
               IF (nsd .EQ. 3) THEN
                  DO a=1, eNoN
                     vx(1,1) = vx(1,1) + Nx(1,a)*yl(i,a)
                     vx(1,2) = vx(1,2) + Nx(2,a)*yl(i,a)
                     vx(1,3) = vx(1,3) + Nx(3,a)*yl(i,a)
                     vx(2,1) = vx(2,1) + Nx(1,a)*yl(j,a)
                     vx(2,2) = vx(2,2) + Nx(2,a)*yl(j,a)
                     vx(2,3) = vx(2,3) + Nx(3,a)*yl(j,a)
                     vx(3,1) = vx(3,1) + Nx(1,a)*yl(k,a)
                     vx(3,2) = vx(3,2) + Nx(2,a)*yl(k,a)
                     vx(3,3) = vx(3,3) + Nx(3,a)*yl(k,a)

                     F(1,1) = F(1,1) + Nx(1,a)*dl(i,a)
                     F(1,2) = F(1,2) + Nx(2,a)*dl(i,a)
                     F(1,3) = F(1,3) + Nx(3,a)*dl(i,a)
                     F(2,1) = F(2,1) + Nx(1,a)*dl(j,a)
                     F(2,2) = F(2,2) + Nx(2,a)*dl(j,a)
                     F(2,3) = F(2,3) + Nx(3,a)*dl(j,a)
                     F(3,1) = F(3,1) + Nx(1,a)*dl(k,a)
                     F(3,2) = F(3,2) + Nx(2,a)*dl(k,a)
                     F(3,3) = F(3,3) + Nx(3,a)*dl(k,a)
                  END DO
                  Fi = MAT_INV(F,3)

                  VxFi(1) = vx(1,1)*Fi(1,1) + vx(1,2)*Fi(2,1) +
     2               vx(1,3)*Fi(3,1)
                  VxFi(2) = vx(2,1)*Fi(1,2) + vx(2,2)*Fi(2,2) +
     2               vx(2,3)*Fi(3,2)
                  VxFi(3) = vx(3,1)*Fi(1,3) + vx(3,2)*Fi(2,3) +
     2               vx(3,3)*Fi(3,3)

                  divV = VxFi(1) + VxFi(2) + VxFi(3)
               ELSE
                  DO a=1, eNoN
                     vx(1,1) = vx(1,1) + Nx(1,a)*yl(i,a)
                     vx(1,2) = vx(1,2) + Nx(2,a)*yl(i,a)
                     vx(2,1) = vx(2,1) + Nx(1,a)*yl(j,a)
                     vx(2,2) = vx(2,2) + Nx(2,a)*yl(j,a)

                     F(1,1) = F(1,1) + Nx(1,a)*dl(i,a)
                     F(1,2) = F(1,2) + Nx(2,a)*dl(i,a)
                     F(2,1) = F(2,1) + Nx(1,a)*dl(j,a)
                     F(2,2) = F(2,2) + Nx(2,a)*dl(j,a)
                  END DO
                  Fi = MAT_INV(F,2)

                  VxFi(1) = vx(1,1)*Fi(1,1) + vx(1,2)*Fi(2,1)
                  VxFi(2) = vx(2,1)*Fi(1,2) + vx(2,2)*Fi(2,2)

                  divV = VxFi(1) + VxFi(2)
               END IF
            END IF

            DO a=1, eNoN
               Ac     = lM%IEN(a,e)
               sA(Ac) = sA(Ac) + w*N(a)
               sF(Ac) = sF(Ac) + w*N(a)*divV
            END DO
         END DO
      END DO

      CALL COMMU(sF)
      CALL COMMU(sA)

      DO a=1, lM%nNo
         Ac = lM%gN(a)
         IF (.NOT. iszero(sA(Ac))) THEN
           res(1,a) = res(1,a) + sF(Ac)/sA(Ac)
         ENDIF
      END DO

      DEALLOCATE (sA, sF, xl, yl, dl, N, Nx)

      RETURN
      END SUBROUTINE DIVPOST
!####################################################################
!     Postprocessing function - used to convert restart bin files
!     into VTK format.
      SUBROUTINE PPBIN2VTK()
      USE COMMOD
      IMPLICIT NONE

      LOGICAL :: flag
      INTEGER :: iTS, ierr
      REAL(KIND=8) :: rtmp(3)
      CHARACTER(LEN=stdL) :: stmp, fName, sepLine

      sepLine = REPEAT("-", 50)
      std  = TRIM(sepLine)
      std  = CLR(" Post-process conversion from bin to vtk files",3)

      DO iTS=1, nTS
         IF (MOD(iTS,stFileIncr) .EQ. 0) THEN
            WRITE(stmp,'(I3.3)') iTS
            IF (iTS .GE. 1000) stmp = STR(iTS)

!           Ignore if vtu file already exists
            IF (cm%mas()) THEN
               fName = TRIM(saveName)//"_"//TRIM(ADJUSTL(stmp))//".vtu"
               INQUIRE(FILE=TRIM(fName), EXIST=flag)
            END IF
            CALL cm%bcast(flag)
            IF (flag) CYCLE

!           Ignore if bin file does not exist
            fName = TRIM(stFileName)//"_"//TRIM(ADJUSTL(stmp))//".bin"
            INQUIRE(FILE=TRIM(fName), EXIST=flag)
            IF (.NOT.flag) CYCLE

            std = TRIM(sepLine)
            std = " "//CLR("<< BIN ---> VTK >>")//"    "//TRIM(fName)
            CALL INITFROMBIN(fName, rtmp)
            CALL WRITEVTUS(Ao, Yo, Do)
         END IF
      END DO
      std = TRIM(sepLine)

      CALL FINALIZE
      CALL MPI_FINALIZE(ierr)
      STOP

      END SUBROUTINE PPBIN2VTK
!####################################################################
