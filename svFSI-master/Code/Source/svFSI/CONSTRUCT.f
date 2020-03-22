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
!     This routine calculates the parameters that are required for
!     sub-equations and calculates them based on general variables.
!
!--------------------------------------------------------------------

      SUBROUTINE GLOBALEQASSEM(lM, Ag, Yg, Dg)
      USE COMMOD
      USE ALLFUN
      IMPLICIT NONE

      TYPE(mshType), INTENT(IN) :: lM
      REAL(KIND=8), INTENT(IN) :: Ag(tDof,tnNo), Yg(tDof,tnNo),
     2   Dg(tDof,tnNo)

      INTEGER a, b, e, i, j, k, Ac, ibl, eNoN, nFn

      INTEGER, ALLOCATABLE :: ptr(:)
      REAL(KIND=8), ALLOCATABLE :: xl(:,:), al(:,:), yl(:,:), dl(:,:),
     2   dol(:,:), fN(:,:), pS0l(:,:), bfl(:,:), ya_l(:), vwpl(:,:)

!     For shells, consider extended patch around an element
      IF (shlEq .AND. lM%eType.EQ.eType_TRI)THEN
         eNoN = 2*lM%eNoN
      ELSE
         eNoN = lM%eNoN
      END IF

      nFn = lM%nFn
      IF (nFn .EQ. 0) nFn = 1

      ALLOCATE(xl(nsd,eNoN), al(tDof,eNoN), yl(tDof,eNoN),dl(tDof,eNoN),
     2   dol(nsd,eNoN), bfl(nsd,eNoN), pS0l(nstd,eNoN), fN(nsd,nFn),
     3   vwpl(2,eNoN), ya_l(eNoN), ptr(eNoN))

      i = nsd + 2
      j = 2*nsd + 1
      DO e=1, lM%nEl
         xl   = 0D0
         al   = 0D0
         yl   = 0D0
         dl   = 0D0
         dol  = 0D0
         fN   = 0D0
         pS0l = 0D0
         bfl  = 0D0
         ya_l = 0D0
         ibl  = 0
         vwpl = 0D0
         DO a=1, eNoN
            IF (a .LE. lM%eNoN) THEN
               Ac     = lM%IEN(a,e)
               ptr(a) = Ac
               ibl    = ibl + iblank(Ac)
            ELSE
               b      = a - lM%eNoN
               Ac     = lM%eIEN(b,e)
               ptr(a) = Ac
               IF (Ac .EQ. 0) CYCLE
            END IF
            xl(:,a)  = x (:,Ac)
            al(:,a)  = Ag(:,Ac)
            yl(:,a)  = Yg(:,Ac)
            dl(:,a)  = Dg(:,Ac)
            bfl(:,a) = Bf(:,Ac)
            IF (mvMsh) dol(:,a) = Do(i:j,Ac)
            IF (ALLOCATED(lM%fN)) THEN
               DO k=1, nFn
                  fN(:,k) = lM%fN((k-1)*nsd+1:k*nsd,e)
               END DO
            END IF
            IF (ALLOCATED(pS0)) pS0l(:,a) = pS0(:,Ac)
            IF (cmmVarWall) vwpl(:,a) = varWallProps(:,Ac)
            IF (cem%cpld) ya_l(a) = cem%Ya(Ac)
         END DO
         IF (ibl .EQ. lM%eNoN) THEN
            IF (ib%mthd .NE. ibMthd_IFEM) CYCLE
         END IF

!     Add contribution of current equation to the LHS/RHS
         CALL CONSTRUCT(lM, e, eNoN, nFn, xl, al, yl, dl, dol, bfl, fN,
     2      pS0l, vwpl, ya_l, ptr)
      END DO

      DEALLOCATE(xl, al, yl, dl, dol, bfl, fN, pS0l, vwpl, ya_l, ptr)

      RETURN
      END SUBROUTINE GLOBALEQASSEM
!####################################################################
      SUBROUTINE CONSTRUCT(lM, e, eNoN, nFn, xl, al, yl, dl, dol, bfl,
     2   fN, pS0l, vwpl, ya_l, ptr)
      USE COMMOD
      USE ALLFUN
      IMPLICIT NONE

      TYPE(mshType), INTENT(IN) :: lM
      INTEGER, INTENT(IN) :: e, eNoN, nFn, ptr(eNoN)
      REAL(KIND=8), INTENT(IN) :: al(tDof,eNoN), yl(tDof,eNoN),
     2   dl(tDof,eNoN), dol(nsd,eNoN), bfl(nsd,eNoN), fN(nsd,nFn),
     3   vwpl(2,eNoN), ya_l(eNoN)
      REAL(KIND=8), INTENT(INOUT) :: xl(nsd,eNoN), pS0l(nstd,eNoN)

      INTEGER a, g, Ac, cPhys, insd
      REAL(KIND=8) w, Jac, vwp(2), ksix(nsd,nsd)

      REAL(KIND=8), ALLOCATABLE :: lK(:,:,:), lR(:,:), N(:), Nx(:,:),
     2   dc(:,:), pSl(:), lKd(:,:,:)

      insd = nsd
      IF (lM%lFib) insd = 1

      ALLOCATE(lK(dof*dof,eNoN,eNoN), lR(dof,eNoN), Nx(insd,eNoN),
     2   N(eNoN), dc(tDof,eNoN), pSl(nstd))

!     Updating the current domain
      cDmn = DOMAIN(lM, cEq, e)

!     Updating the shape functions, if neccessary
      IF (lM%eType .EQ. eType_NRB) CALL NRBNNX(lM, e)

!     Setting intial values
      lK    = 0D0
      lR    = 0D0
      pSl   = 0D0
      cPhys = eq(cEq)%dmn(cDmn)%phys

      IF (cPhys .EQ. phys_vms_struct) THEN
         ALLOCATE(lKd(dof*nsd,eNoN,eNoN))
         lKd = 0D0
      END IF

!     If neccessary correct X, if mesh is moving
      IF (mvMsh) THEN
         IF (cPhys .EQ. phys_mesh) THEN
!     For mesh the reference configuration is the one at beginning of
!     the time step
            xl = xl + dol
         ELSE IF (cPhys .NE. phys_struct .AND.
     2            cPhys .NE. phys_vms_struct .AND.
     3            cPhys .NE. phys_lElas) THEN
!     Otherwise we use the most recent configuration
            xl = xl + dl(nsd+2:2*nsd+1,:)
         END IF
      END IF

!     Solve for shell dynamics
      IF (cPhys .EQ. phys_shell) THEN
         IF (lM%eType .EQ. eType_TRI) THEN
!        No need for numerical integration for constant strain triangles
            CALL SHELLTRI(lM, e, eNoN, al, yl, dl, xl, bfl, ptr)
            DEALLOCATE(lR, lK, N, Nx, dc, pSl)
            RETURN
         ELSE IF (lM%eType .EQ. eType_NRB) THEN
!        For NURBS, perform Gauss integration
            DO g=1, lM%nG
               CALL SHELLNRB(lM, g, eNoN, al, yl, dl, xl, bfl, lR, lK)
            END DO
!        Perform global assembly
#ifdef WITH_TRILINOS
            IF (eq(cEq)%assmTLS) THEN
               CALL TRILINOS_DOASSEM(eNoN, ptr, lK, lR)
            ELSE
#endif
               CALL DOASSEM(eNoN, ptr, lK, lR)
#ifdef WITH_TRILINOS
            END IF
#endif
            DEALLOCATE(lR, lK, N, Nx, dc, pSl)
            RETURN
         END IF
      END IF

!     CMM initialization
      IF (cmmInit) THEN
         pSl(:) = 0D0
         vwp(:) = 0D0
         DO a=1, eNoN
            pSl(:) = pSl(:) + pS0l(:,a)
            vwp(:) = vwp(:) + vwpl(:,a)
         END DO
         pSl(:) = pSl(:)/REAL(eNoN,KIND=8)
         vwp(:) = vwp(:)/REAL(eNoN,KIND=8)
         CALL CMMi(lM, eNoN, al, dl, xl, bfl, pSl, vwp, ptr)
         DEALLOCATE(lR, lK, N, Nx, dc, pSl)
         RETURN
      END IF

      DO g=1, lM%nG
         IF (g.EQ.1 .OR. .NOT.lM%lShpF) THEN
            CALL GNN(eNoN, insd, lM%Nx(:,:,g), xl, Nx, Jac, ksix)
         END IF
         IF (ISZERO(Jac)) err = "Jac < 0 @ element "//e
         w = lM%w(g)*Jac
         N = lM%N(:,g)

         SELECT CASE (cPhys)
         CASE (phys_fluid)
            IF (nsd .EQ. 3) THEN
               CALL FLUID3D(eNoN, w, N, Nx, al, yl, bfl, ksix, lR, lK)
            ELSE
               CALL FLUID2D(eNoN, w, N, Nx, al, yl, bfl, ksix, lR, lK)
            END IF

         CASE (phys_CMM)
            CALL CMM3D(eNoN, w, N, Nx, al, yl, bfl, ksix, ptr, lR, lK)

         CASE (phys_heatS)
            IF (nsd .EQ. 3) THEN
               CALL HEATS3D(eNoN, w, N, Nx, al, yl, lR, lK)
            ELSE
               CALL HEATS2D(eNoN, w, N, Nx, al, yl, lR, lK)
            END IF

         CASE (phys_heatF)
            IF (nsd .EQ. 3) THEN
               CALL HEATF3D(eNoN, w, N, Nx, al, yl, ksix, lR, lK)
            ELSE
               CALL HEATF2D(eNoN, w, N, Nx, al, yl, ksix, lR, lK)
            END IF

         CASE (phys_lElas)
            IF (nsd .EQ. 3) THEN
               CALL LELAS3D(eNoN, w, N, Nx, al, dl, bfl, pS0l, pSl, lR,
     2            lK)
            ELSE
               CALL LELAS2D(eNoN, w, N, Nx, al, dl, bfl, pS0l, pSl, lR,
     2            lK)
            END IF

         CASE (phys_struct)
            IF (nsd .EQ. 3) THEN
               CALL STRUCT3D(eNoN, nFn, w, N, Nx, al, yl, dl, bfl, fN,
     2            pS0l, pSl, ya_l, lR, lK)
            ELSE
               CALL STRUCT2D(eNoN, nFn, w, N, Nx, al, yl, dl, bfl, fN,
     2            pS0l, pSl, ya_l, lR, lK)
            END IF

         CASE (phys_vms_struct)
            IF (nsd .EQ. 3) THEN
               CALL VMS_STRUCT3D(eNoN, nFn, w, Jac, N, Nx, al, yl, dl,
     2            bfl, fN, ya_l, lR, lK, lKd)
            ELSE
               CALL VMS_STRUCT2D(eNoN, nFn, w, Jac, N, Nx, al, yl, dl,
     2            bfl, fN, ya_l, lR, lK, lKd)
            END IF

         CASE (phys_mesh)
            w = w/Jac
            pS0l = 0D0
            IF (nsd .EQ. 3) THEN
               dc(5:7,:) = dl(5:7,:) - dol
               CALL LELAS3D(eNoN, w, N, Nx, al, dc, bfl, pS0l, pSl, lR,
     2            lK)
            ELSE
               dc(4:5,:) = dl(4:5,:) - dol
               CALL LELAS2D(eNoN, w, N, Nx, al, dc, bfl, pS0l, pSl, lR,
     2            lK)
            END IF
            pSl = 0D0

         CASE (phys_CEP)
            IF (insd .EQ. 3) THEN
               CALL CEP3D(eNoN, nFn, w, N, Nx, al, yl, dl, fN, lR, lK)

            ELSE IF (insd .EQ. 2) THEN
               CALL CEP2D(eNoN, nFn, w, N, Nx, al, yl, dl, fN, lR, lK)

            ELSE IF (insd .EQ. 1) THEN
               CALL CEP1D(eNoN, insd, w, N, Nx, al, yl, lR, lK)
            END IF

         CASE DEFAULT
            err = "Undefined phys in CONSTRUCT"
         END SELECT

!      For prestress, map pSl values to global nodal vector
         IF (pstEq .AND. cPhys.NE.phys_mesh) THEN
            DO a=1, eNoN
               Ac = ptr(a)
               pSn(:,Ac) = pSn(:,Ac) + w*N(a)*pSl(:)
               pSa(Ac)   = pSa(Ac)   + w*N(a)
            END DO
         END IF
      END DO

!     Now doing the assembly part
#ifdef WITH_TRILINOS
      IF (eq(cEq)%assmTLS) THEN
         IF (cPhys .EQ. phys_vms_struct) err = " VMS_STRUCT cannot be"//
     2      " assembled using Trilinos yet. Use local assembly."
         CALL TRILINOS_DOASSEM(eNoN, ptr, lK, lR)
      ELSE
#endif
         IF (cPhys .EQ. phys_vms_struct) THEN
            CALL VMS_STRUCT_DOASSEM(eNoN, ptr, lKd, lK, lR)
         ELSE
            CALL DOASSEM(eNoN, ptr, lK, lR)
         END IF
#ifdef WITH_TRILINOS
      END IF
#endif

      DEALLOCATE(lR, lK, N, Nx, dc, pSl)

      RETURN
      END SUBROUTINE CONSTRUCT
!####################################################################
      SUBROUTINE BCONSTRUCT(lFa, hg, Yg, Dg)
      USE COMMOD
      USE ALLFUN
      IMPLICIT NONE

      TYPE(faceType), INTENT(IN) :: lFa
      REAL(KIND=8), INTENT(IN) :: hg(tnNo), Yg(tDof,tnNo), Dg(tDof,tnNo)

      INTEGER a, e, g, Ac, Ec, iM, cPhys, eNoN
      REAL(KIND=8) w, h, nV(nsd), y(tDof), Jac

      INTEGER, ALLOCATABLE :: ptr(:)
      REAL(KIND=8), ALLOCATABLE :: N(:), hl(:), xl(:,:), yl(:,:),
     2   dl(:,:), lR(:,:), lK(:,:,:), lKd(:,:,:)

      iM = lFa%iM
      DO e=1, lFa%nEl
         Ec    = lFa%gE(e)
         cDmn  = DOMAIN(msh(iM), cEq, Ec)
         cPhys = eq(cEq)%dmn(cDmn)%phys

         IF (cPhys .EQ. phys_vms_struct) THEN
!           We use Nanson's formula to take change in normal direction
!           with deformation into account. Additional calculations based
!           on mesh element need to be performed.
            eNoN = msh(iM)%eNoN

            ALLOCATE(ptr(eNoN), hl(eNoN), xl(nsd,eNoN), dl(tDof,eNoN),
     2         lR(dof,eNoN), lK(dof*dof,eNoN,eNoN),
     3         lKd(dof*nsd,eNoN,eNoN))
            lR  = 0D0
            lK  = 0D0
            lKd = 0D0
            DO a=1, msh(iM)%eNoN
               Ac      = msh(iM)%IEN(a,Ec)
               ptr(a)  = Ac
               xl(:,a) = x(:,Ac)
               dl(:,a) = Dg(:,Ac)
               hl(a)   = hg(Ac)
            END DO

            CALL BVMS_STRUCT(lFa, eNoN, e, ptr, xl, dl, hl, lR, lK, lKd)

            DEALLOCATE(ptr, hl, xl, dl, lR, lK, lKd)
         ELSE
            eNoN = lFa%eNoN

            ALLOCATE(ptr(eNoN), N(eNoN), hl(eNoN), yl(tDof,eNoN),
     2         lR(dof,eNoN), lK(dof*dof,eNoN,eNoN))
            lK = 0D0
            lR = 0D0
            DO a=1, eNoN
               Ac      = lFa%IEN(a,e)
               ptr(a)  = Ac
               yl(:,a) = Yg(:,Ac)
               hl(a)   = hg(Ac)
            END DO

!           Updating the shape functions, if neccessary
            IF (lFa%eType .EQ. eType_NRB) CALL NRBNNXB(msh(iM), lFa, e)

            DO g=1, lFa%nG
               CALL GNNB(lFa, e, g, nV)
               Jac = SQRT(NORM(nV))
               nV  = nV/Jac
               w   = lFa%w(g)*Jac
               N   = lFa%N(:,g)

               h = 0D0
               y = 0D0
               DO a=1, eNoN
                  h = h + N(a)*hl(a)
                  y = y + N(a)*yl(:,a)
               END DO

               SELECT CASE (cPhys)
               CASE (phys_fluid)
                  CALL BFLUID(eNoN, w, N, y, h, nV, lR, lK)

               CASE (phys_CMM)
                  CALL BFLUID(eNoN, w, N, y, h, nV, lR, lK)

               CASE (phys_heatS)
                  CALL BHEATS(eNoN, w, N, h, lR)

               CASE (phys_heatF)
                  CALL BHEATF(eNoN, w, N, y, h, nV, lR, lK)

               CASE (phys_lElas)
                  CALL BLELAS(eNoN, w, N, h, nV, lR)

               CASE (phys_struct)
                  CALL BLELAS(eNoN, w, N, h, nV, lR)

               CASE (phys_CEP)
                  CALL BCEP(eNoN, w, N, h, lR)

               CASE (phys_shell)
                  CALL BLELAS(eNoN, w, N, h, nV, lR)

               CASE DEFAULT
                  err = "Undefined phys in BCONSTRUCT"
               END SELECT
            END DO

!           Now doing the assembly part
#ifdef WITH_TRILINOS
            IF (eq(cEq)%assmTLS) THEN
               CALL TRILINOS_DOASSEM(eNoN, ptr, lK, lR)
            ELSE
#endif
               CALL DOASSEM(eNoN, ptr, lK, lR)
#ifdef WITH_TRILINOS
            END IF
#endif
            DEALLOCATE(ptr, N, hl, yl, lR, lK)
         END IF
      END DO

      RETURN
      END SUBROUTINE BCONSTRUCT
!####################################################################
