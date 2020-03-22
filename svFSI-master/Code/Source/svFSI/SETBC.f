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
!     Here Dirichlet, Neumann, Traction and Coupled BCs are applied on
!     the boundary faces.
!
!--------------------------------------------------------------------

      SUBROUTINE SETBCDIR(lA, lY, lD)
      USE COMMOD
      IMPLICIT NONE

      REAL(KIND=8), INTENT(INOUT) :: lA(tDof, tnNo), lY(tDof, tnNo),
     2   lD(tDof, tnNo)

      LOGICAL :: eDir(maxnsd)
      INTEGER iFa, a, Ac, iEq, iBc, s, e, iM, nNo, lDof, i, j
      REAL(KIND=8) :: c1, c1i, c2

      REAL(KIND=8), ALLOCATABLE :: tmpA(:,:), tmpY(:,:)

      DO iEq=1, nEq
         DO iBc=1, eq(iEq)%nBc
            IF(BTEST(eq(iEq)%bc(iBc)%bType,bType_CMM)) THEN
               s = eq(iEq)%s
               e = eq(iEq)%e
               IF (eq(iEq)%dof .EQ. nsd+1) e = e - 1
               iFa  = eq(iEq)%bc(iBc)%iFa
               iM   = eq(iEq)%bc(iBc)%iM
               DO a=1, msh(iM)%fa(iFa)%nNo
                  IF (ISZERO(eq(iEq)%bc(iBc)%gx(a))) THEN
                     Ac = msh(iM)%fa(iFa)%gN(a)
                     lA(s:e,Ac) = 0D0
                     lY(s:e,Ac) = 0D0
                  END IF
               END DO
            END IF ! END bType_CMM

            IF (.NOT.BTEST(eq(iEq)%bc(iBc)%bType,bType_Dir)) CYCLE
            IF (eq(iEq)%bc(iBc)%weakDir) CYCLE
            s = eq(iEq)%s
            e = eq(iEq)%e
            IF (eq(iEq)%dof .EQ. nsd+1) e = e - 1
            eDir = .FALSE.
            lDof = 0
            DO i=1, nsd
               IF (eq(iEq)%bc(iBc)%eDrn(i) .NE. 0) THEN
                  eDir(i) = .TRUE.
                  lDof = lDof + 1
               END IF
            END DO
            IF (lDof .EQ. 0) lDof = e - s + 1
            iFa  = eq(iEq)%bc(iBc)%iFa
            iM   = eq(iEq)%bc(iBc)%iM
            nNo  = msh(iM)%fa(iFa)%nNo
            IF (ALLOCATED(tmpA)) DEALLOCATE(tmpA, tmpY)
            ALLOCATE(tmpA(lDof,nNo), tmpY(lDof,nNo))
            CALL SETBCDIRL(eq(iEq)%bc(iBc), msh(iM)%fa(iFa), tmpA, tmpY,
     2         lDof)

            IF (ANY(eDir)) THEN
               IF (BTEST(eq(iEq)%bc(iBc)%bType,bType_impD)) THEN
                  DO a=1, msh(iM)%fa(iFa)%nNo
                     Ac = msh(iM)%fa(iFa)%gN(a)
                     lDof = 0
                     DO i=1, nsd
                        IF (eDir(i)) THEN
                           lDof = lDof + 1
                           lY(s+i-1,Ac) = tmpA(lDof,a)
                           lD(s+i-1,Ac) = tmpY(lDof,a)
                        END IF
                     END DO
                  END DO
               ELSE
                  DO a=1, msh(iM)%fa(iFa)%nNo
                     Ac = msh(iM)%fa(iFa)%gN(a)
                     lDof = 0
                     DO i=1, nsd
                        IF (eDir(i)) THEN
                           lDof = lDof + 1
                           lA(s+i-1,Ac) = tmpA(lDof,a)
                           lY(s+i-1,Ac) = tmpY(lDof,a)
                        END IF
                     END DO
                  END DO
               END IF
            ELSE
               IF (BTEST(eq(iEq)%bc(iBc)%bType,bType_impD)) THEN
                  DO a=1, msh(iM)%fa(iFa)%nNo
                     Ac = msh(iM)%fa(iFa)%gN(a)
                     lY(s:e,Ac) = tmpA(:,a)
                     lD(s:e,Ac) = tmpY(:,a)
                  END DO
               ELSE
                  DO a=1, msh(iM)%fa(iFa)%nNo
                     AC = msh(iM)%fa(iFa)%gN(a)
                     lA(s:e,Ac) = tmpA(:,a)
                     lY(s:e,Ac) = tmpY(:,a)
                  END DO
               END IF
            END IF

            IF ((eq(iEq)%phys .EQ. phys_FSI .AND. sstEq) .OR.
     2           eq(iEq)%phys .EQ. phys_vms_struct) THEN
               c1  = eq(iEq)%gam * dt
               c1i = 1.0D0 / c1
               c2  = (eq(iEq)%gam - 1.0D0)*dt
               IF (ANY(eDir)) THEN
                  IF (BTEST(eq(iEq)%bc(iBc)%bType,bType_impD)) THEN
                     DO a=1, msh(iM)%fa(iFa)%nNo
                        Ac = msh(iM)%fa(iFa)%gN(a)
                        DO i=1, nsd
                           IF (eDir(i)) THEN
                              j = s + i - 1
                              lA(j,Ac) = c1i*(lY(j,Ac) - Yo(j,Ac) +
     2                                    c2*Ao(j,Ac))
                              Ad(i,Ac) = c1i*(lD(j,Ac) - Do(j,Ac) +
     2                                    c2*Ad(i,Ac))
                           END IF
                        END DO
                     END DO
                  ELSE
                     DO a=1, msh(iM)%fa(iFa)%nNo
                        Ac = msh(iM)%fa(iFa)%gN(a)
                        DO i=1, nsd
                           IF (eDir(i)) THEN
                              j = s + i - 1
                              lD(j,Ac) = c1*lY(j,Ac) - c2*Ad(i,Ac) +
     2                                   Do(j,Ac)
                              Ad(i,Ac) = lY(j,Ac)
                           END IF
                        END DO
                     END DO
                  END IF
               ELSE
                  IF (BTEST(eq(iEq)%bc(iBc)%bType,bType_impD)) THEN
                     DO a=1, msh(iM)%fa(iFa)%nNo
                        Ac = msh(iM)%fa(iFa)%gN(a)
                        lA(s:e,Ac) = c1i*(lY(s:e,Ac) - Yo(s:e,Ac) +
     2                                c2*Ao(s:e,Ac))
                        Ad(:,Ac)   = c1i*(lD(s:e,Ac) - Do(s:e,Ac) +
     2                                c2*Ad(:,Ac))
                     END DO
                  ELSE
                     DO a=1, msh(iM)%fa(iFa)%nNo
                        Ac = msh(iM)%fa(iFa)%gN(a)
                        lD(s:e,Ac) = c1*lY(s:e,Ac) - c2*Ad(:,Ac) +
     2                               Do(s:e,Ac)
                        Ad(:,Ac)   = lY(s:e,Ac)
                     END DO
                  END IF
               END IF
            END IF
         END DO ! iBc
      END DO ! iEq

      IF (ibFlag) THEN
         IF (ib%mthd .EQ. ibMthd_SSM) THEN
            CALL IB_SETBCDIR(ib%Ao, ib%Yo, ib%Uo)
            CALL IB_SSMPRJCTU(lY, lD, ib%Yo)
         END IF
      END IF

      RETURN
      END SUBROUTINE SETBCDIR
!--------------------------------------------------------------------
      SUBROUTINE SETBCDIRL(lBc, lFa, lA, lY, lDof)
      USE COMMOD
      IMPLICIT NONE

      INTEGER, INTENT(IN) :: lDof
      TYPE(bcType), INTENT(IN) :: lBc
      TYPE(faceType), INTENT(IN) :: lFa
      REAL(KIND=8), INTENT(INOUT) :: lA(lDof,lFa%nNo), lY(lDof,lFa%nNo)

      INTEGER :: a, i
      REAL(KIND=8) :: dirY, dirA, nV(nsd)

      IF (BTEST(lBc%bType,bType_gen)) THEN
         IF (lDof .NE. lBc%gm%dof) err = "Inconsistent DOF"
         CALL IGBC(lBc%gm, lY, lA)
         RETURN
      ELSE IF (BTEST(lBc%bType,bType_ustd)) THEN
         CALL IFFT(lBc%gt, dirY, dirA)
      ELSE ! std / cpl
         dirA = 0D0
         dirY = lBc%g
      END IF
      IF (lDof .EQ. nsd) THEN
         DO a=1, lFa%nNo
            nV      = lFa%nV(:,a)
            lA(:,a) = dirA*lBc%gx(a)*nV
            lY(:,a) = dirY*lBc%gx(a)*nV
         END DO
      ELSE
         DO a=1, lFa%nNo
            DO i=1, lDof
               lA(i,a) = dirA*lBc%gx(a)
               lY(i,a) = dirY*lBc%gx(a)
            END DO
         END DO
      END IF

      RETURN
      END SUBROUTINE SETBCDIRL
!####################################################################
!     Here for the outlets
      SUBROUTINE SETBCNEU(Yg, Dg)
      USE COMMOD
      IMPLICIT NONE

      REAL(KIND=8), INTENT(IN) :: Yg(tDof,tnNo), Dg(tDof,tnNo)

      INTEGER iFa, iBc, iM

      DO iBc=1, eq(cEq)%nBc
         iFa = eq(cEq)%bc(iBc)%iFa
         iM  = eq(cEq)%bc(iBc)%iM
         IF (BTEST(eq(cEq)%bc(iBc)%bType,bType_Neu)) THEN
            CALL SETBCNEUL(eq(cEq)%bc(iBc), msh(iM)%fa(iFa), Yg, Dg)
         ELSE IF (BTEST(eq(cEq)%bc(iBc)%bType,bType_trac)) THEN
            CALL SETBCTRACL(eq(cEq)%bc(iBc), msh(iM)%fa(iFa))
         END IF
      END DO

      RETURN
      END SUBROUTINE SETBCNEU
!--------------------------------------------------------------------
!     Set Neumann BC
      SUBROUTINE SETBCNEUL(lBc, lFa, Yg, Dg)
      USE COMMOD
      USE ALLFUN
      IMPLICIT NONE

      TYPE(bcType), INTENT(IN) :: lBc
      TYPE(faceType), INTENT(IN) :: lFa
      REAL(KIND=8), INTENT(IN) :: Yg(tDof,tnNo), Dg(tDof,tnNo)

      INTEGER a, Ac, nNo
      REAL(KIND=8) h, rtmp

      REAL(KIND=8), ALLOCATABLE :: hg(:), tmpA(:)

      nNo  = lFa%nNo

!     Geting the contribution of Neu BC
      IF (BTEST(lBc%bType,bType_cpl) .OR.
     2    BTEST(lBc%bType,bType_RCR)) THEN
         h = lBc%g
      ELSE
         IF (BTEST(lBc%bType,bType_gen)) THEN
!     Using "hl" as a temporary variable here
            ALLOCATE(tmpA(nNo), hg(nNo))
            CALL IGBC(lBc%gm, tmpA, hg)
            DEALLOCATE(hg)
         ELSE IF (BTEST(lBc%bType,bType_res)) THEN
            h = lBc%r * Integ(lFa, Yn, eq(cEq)%s, eq(cEq)%s+nsd-1)
         ELSE IF (BTEST(lBc%bType,bType_std)) THEN
            h = lBc%g
         ELSE IF (BTEST(lBc%bType,bType_ustd)) THEN
            CALL IFFT(lBc%gt, h, rtmp)
         ELSE
            err = "Correction in SETBCNEU is needed"
         END IF
      END IF

      ALLOCATE(hg(tnNo))
      hg = 0D0

!     Transforming it to a unified format
      IF (BTEST(lBc%bType,bType_gen)) THEN
         DO a=1, nNo
            Ac     = lFa%gN(a)
            hg(Ac) = tmpA(a)
         END DO
      ELSE
         DO a=1, nNo
            Ac     = lFa%gN(a)
            hg(Ac) = -h*lBc%gx(a)
         END DO
      END IF

!     Add Neumann BCs contribution to the LHS/RHS
      CALL BCONSTRUCT(lFa, hg, Yg, Dg)

!     Now treat Robin BC (stiffness and damping) here
      IF (BTEST(lBc%bType,bType_Robin))
     2   CALL SETBCRBNL(lFa, lBc%k, lBc%c, Yg, Dg)

      RETURN
      END SUBROUTINE SETBCNEUL
!--------------------------------------------------------------------
!     Set Traction BC
      SUBROUTINE SETBCTRACL(lBc, lFa)
      USE COMMOD
      USE ALLFUN
      IMPLICIT NONE

      TYPE(bcType), INTENT(IN) :: lBc
      TYPE(faceType), INTENT(IN) :: lFa

      INTEGER :: a, e, g, Ac, iM, nNo, eNoN, cPhys
      REAL(KIND=8) :: w, Jac, nV(nsd), h(nsd)

      INTEGER, ALLOCATABLE :: ptr(:)
      REAL(KIND=8), ALLOCATABLE :: N(:), hl(:,:), hg(:,:), tmpA(:,:),
     2   lR(:,:), lK(:,:,:)

      iM   = lFa%iM
      nNo  = lFa%nNo
      eNoN = lFa%eNoN

!     Geting the contribution of traction BC
      ALLOCATE(hg(nsd,tnNo))
      IF (BTEST(lBc%bType,btype_gen)) THEN
!     Using "hl" as a temporary variable here
         ALLOCATE(tmpA(nsd,nNo), hl(nsd,nNo))
         CALL IGBC(lBc%gm, tmpA, hl)
         DO a=1, nNo
            Ac       = lFa%gN(a)
            hg(:,Ac) = tmpA(:,a)
         END DO
         DEALLOCATE(tmpA, hl)
      ELSE IF (BTEST(lBc%bType,bType_std)) THEN
         DO a=1, nNo
            Ac = lFa%gN(a)
            hg(:,Ac) = lBc%h(:)
         END DO
      ELSE
         err = "Undefined time dependence for traction BC on face <"//
     2      TRIM(lFa%name)//">"
      END IF

      ALLOCATE(N(eNoN), ptr(eNoN), hl(nsd,eNoN), lR(dof,eNoN),
     2   lK(dof*dof,eNoN,eNoN))

!     Constructing LHS/RHS contribution and assembiling them
      DO e=1, lFa%nEl
         cDmn  = DOMAIN(msh(iM), cEq, lFa%gE(e))
         cPhys = eq(cEq)%dmn(cDmn)%phys
         IF (lFa%eType .EQ. eType_NRB) CALL NRBNNXB(msh(iM), lFa, e)

         DO a=1, eNoN
            Ac      = lFa%IEN(a,e)
            ptr(a)  = Ac
            hl(:,a) = hg(:,Ac)
         END DO

         lK = 0D0
         lR = 0D0
         DO g=1, lFa%nG
            CALL GNNB(lFa, e, g, nV)
            Jac = SQRT(NORM(nV))
            w   = lFa%w(g)*Jac
            N   = lFa%N(:,g)

            h = 0D0
            DO a=1, eNoN
               h(:) = h(:) + N(a)*hl(:,a)
            END DO

            DO a=1, eNoN
               lR(1:nsd,a) = lR(1:nsd,a) - w*N(a)*h(:)
            END DO
         END DO

#ifdef WITH_TRILINOS
         IF (eq(cEq)%assmTLS) THEN
            CALL TRILINOS_DOASSEM(eNoN, ptr, lK, lR)
         ELSE
#endif
            CALL DOASSEM(eNoN, ptr, lK, lR)
#ifdef WITH_TRILINOS
         END IF
#endif
      END DO

      DEALLOCATE(N, ptr, hl, lR, lK)

      RETURN
      END SUBROUTINE SETBCTRACL
!--------------------------------------------------------------------
!     Set Robin BC
      SUBROUTINE SETBCRBNL(lFa, ks, cs, Yg, Dg)
      USE COMMOD
      USE ALLFUN
      IMPLICIT NONE

      TYPE(faceType), INTENT(IN) :: lFa
      REAL(KIND=8), INTENT(IN) :: ks, cs, Yg(tDof,tnNo), Dg(tDof,tnNo)

      INTEGER :: a, b, e, g, s, Ac, iM, eNoN, cPhys
      REAL(KIND=8) :: af, am, afm, w, wl, T1, T2, nV(nsd), u(nsd),
     2   ud(nsd), h(nsd)

      INTEGER, ALLOCATABLE :: ptr(:)
      REAL(KIND=8), ALLOCATABLE :: N(:), xl(:,:), yl(:,:), dl(:,:),
     2   lR(:,:), lK(:,:,:), lKd(:,:,:)

      s   = eq(cEq)%s
      am  = eq(cEq)%af*eq(cEq)%gam*dt
      af  = eq(cEq)%af*eq(cEq)%beta*dt*dt
      afm = am/eq(cEq)%am

      iM   = lFa%iM
      eNoN = lFa%eNoN

      ALLOCATE(N(eNoN), xl(nsd,eNoN), yl(nsd,eNoN), dl(nsd,eNoN),
     2   lR(dof,eNoN), lK(dof*dof,eNoN,eNoN), lKd(nsd*dof,eNoN,eNoN),
     3   ptr(eNoN))

      DO e=1, lFa%nEl
         cDmn  = DOMAIN(msh(iM), cEq, lFa%gE(e))
         cPhys = eq(cEq)%dmn(cDmn)%phys

         DO a=1, eNoN
            Ac      = lFa%IEN(a,e)
            ptr(a)  = Ac
            xl(:,a) =  x(:,Ac)
            yl(:,a) = Yg(s:s+nsd-1,Ac)
            dl(:,a) = Dg(s:s+nsd-1,Ac)
         END DO
         IF (lFa%eType .EQ. eType_NRB) CALL NRBNNXB(msh(iM), lFa, e)

         lK  = 0D0
         lR  = 0D0
         lKd = 0D0
         DO g=1, lFa%nG
            CALL GNNB(lFa, e, g, nV)
            w  = lFa%w(g) * SQRT(NORM(nV))
            N  = lFa%N(:,g)

            u  = 0D0
            ud = 0D0
            DO a=1, eNoN
               u(:)  = u(:)  + N(a)*dl(:,a)
               ud(:) = ud(:) + N(a)*yl(:,a)
            END DO
            h(:) = ks*u(:) + cs*ud(:)

            IF (nsd .EQ. 3) THEN
               DO a=1, eNoN
                  lR(1,a) = lR(1,a) - w*N(a)*h(1)
                  lR(2,a) = lR(2,a) - w*N(a)*h(2)
                  lR(3,a) = lR(3,a) - w*N(a)*h(3)
               END DO

               IF (cPhys .EQ. phys_vms_struct) THEN
                  wl = w*af
                  DO a=1, eNoN
                     DO b=1, eNoN
                        T1 = wl*N(a)*N(b)
                        T2 = (afm*ks + cs)*T1
                        T1 = T1*ks

!                       dM_1/dV_1 + af/am*dM_1/dU_1
                        lKd(1,a,b) = lKd(1,a,b) + T1
                        lK(1,a,b)  = lK(1,a,b)  + T2

!                       dM_2/dV_2 + af/am*dM_2/dU_2
                        lKd(5,a,b) = lKd(5,a,b) + T1
                        lK(6,a,b)  = lK(6,a,b)  + T2

!                       dM_3/dV_3 + af/am*dM_3/dU_3
                        lKd(9,a,b) = lKd(9,a,b) + T1
                        lK(11,a,b) = lK(11,a,b) + T2
                     END DO
                  END DO
               ELSE
                 wl = w*(ks*af + cs*am)
                  DO  a=1, eNoN
                     DO b=1, eNoN
                        T1 = N(a)*N(b)
                        lK(1,a,b) = lK(1,a,b) - wl*T1
                        lK(dof+2,a,b) = lK(dof+2,a,b) - wl*T1
                        lK(2*dof+3,a,b) = lK(2*dof+3,a,b) - wl*T1
                     END DO
                  END DO
               END IF
            ELSE IF (nsd .EQ. 2) THEN
               DO a=1, eNoN
                  lR(1,a) = lR(1,a) - w*N(a)*h(1)
                  lR(2,a) = lR(2,a) - w*N(a)*h(2)
               END DO

               IF (cPhys .EQ. phys_vms_struct) THEN
                  wl = w*af
                  DO a=1, eNoN
                     DO b=1, eNoN
                        T1 = wl*N(a)*N(b)
                        T2 = (afm*ks + cs)*T1
                        T1 = T1*ks

!                       dM_1/dV_1 + af/am*dM_1/dU_1
                        lKd(1,a,b) = lKd(1,a,b) + T1
                        lK(1,a,b)  = lK(1,a,b)  + T2

!                       dM_2/dV_2 + af/am*dM_2/dU_2
                        lKd(4,a,b) = lKd(4,a,b) + T1
                        lK(5,a,b)  = lK(5,a,b)  + T2
                     END DO
                  END DO
               ELSE
                  wl = w*(ks*af + cs*am)
                  DO a=1, eNoN
                     DO b=1, eNoN
                        T1 = N(a)*N(b)
                        lK(1,a,b) = lK(1,a,b) - wl*T1
                        lK(dof+1,a,b) = lK(dof+1,a,b) - wl*T1
                     END DO
                  END DO
               END IF
            END IF
         END DO

#ifdef WITH_TRILINOS
         IF (eq(cEq)%assmTLS) THEN
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
      END DO

      DEALLOCATE(N, xl, yl, dl, lR, lK, lKd, ptr)

      RETURN
      END SUBROUTINE SETBCRBNL
!####################################################################
!     Treat Neumann boundaries that are not deforming.
!     Leave the row corresponding to the master node of the owner
!     process in the LHS matrix and the residue vector untouched. For
!     all the other nodes of the face, set the residue to be 0 for
!     velocity dofs. Zero out all the elements of corresponding rows of
!     the LHS matrix. Make the diagonal elements of the LHS matrix equal
!     to 1 and the column entry corresponding to the master node, -1
      SUBROUTINE SETBCUNDEFNEU
      USE COMMOD
      IMPLICIT NONE

      INTEGER iFa, iBc, iM

      DO iBc=1, eq(cEq)%nBc
         iFa = eq(cEq)%bc(iBc)%iFa
         iM  = eq(cEq)%bc(iBc)%iM
         IF (BTEST(eq(cEq)%bc(iBc)%bType,bType_undefNeu)) THEN
            CALL SETBCUNDEFNEUL(eq(cEq)%bc(iBc), msh(iM)%fa(iFa))
         END IF
      END DO

      RETURN
      END SUBROUTINE SETBCUNDEFNEU
!--------------------------------------------------------------------
      SUBROUTINE SETBCUNDEFNEUL(lBc, lFa)
      USE COMMOD
      USE ALLFUN
      IMPLICIT NONE

      TYPE(bcType), INTENT(IN) :: lBc
      TYPE(faceType), INTENT(IN) :: lFa

      INTEGER a, i, masN, rowN, colN

      masN = lBc%masN
      IF (lFa%nNo.EQ.0 .OR. masN.EQ.0) RETURN

      IF (nsd .EQ. 2) THEN
         DO a=1, lFa%nNo
            rowN = lFa%gN(a)
            IF (rowN .EQ. masN) CYCLE
            R (1:2,rowN) = 0D0

!           Diagonalize the stiffness matrix (A)
            DO i=rowPtr(rowN), rowPtr(rowN+1)-1
               colN = colPtr(i)
               IF (colN .EQ. rowN) THEN
                  Val(1,i) = 1D0
                  Val(5,i) = 1D0
               ELSE IF (colN .EQ. masN) THEN
                  Val(1,i) = -1D0
                  Val(5,i) = -1D0
               END IF
            END DO
         END DO

      ELSE IF (nsd .EQ. 3) THEN
         DO a=1, lFa%nNo
            rowN = lFa%gN(a)
            IF (rowN .EQ. masN) CYCLE
            R (1:3,rowN) = 0D0

!           Diagonalize the stiffness matrix (A)
            DO i=rowPtr(rowN), rowPtr(rowN+1)-1
               colN = colPtr(i)
               IF (colN .EQ. rowN) THEN
                  Val(1, i) = 1D0
                  Val(6, i) = 1D0
                  Val(11,i) = 1D0
               ELSE IF (colN .EQ. masN) THEN
                  Val(1, i) = -1D0
                  Val(6, i) = -1D0
                  Val(11,i) = -1D0
               END IF
            END DO
         END DO
      END IF

      RETURN
      END SUBROUTINE SETBCUNDEFNEUL
!####################################################################
!     Weak treatment of Dirichlet boundary conditions
      SUBROUTINE SETBCDIRW(Yg, Dg)
      USE COMMOD
      USE ALLFUN
      IMPLICIT NONE

      REAL(KIND=8), INTENT(IN) :: Yg(tDof,tnNo), Dg(tDof,tnNo)

      INTEGER :: iBc, iFa, iM

      DO iBc=1, eq(cEq)%nBc
         iM  = eq(cEq)%bc(iBc)%iM
         iFa = eq(cEq)%bc(iBc)%iFa
         IF (.NOT.eq(cEq)%bc(iBc)%weakDir) CYCLE
         CALL SETBCDIRWL(eq(cEq)%bc(iBc), msh(iM), msh(iM)%fa(iFa), Yg,
     2      Dg)
      END DO

      RETURN
      END SUBROUTINE SETBCDIRW
!--------------------------------------------------------------------
      SUBROUTINE SETBCDIRWL(lBc, lM, lFa, Yg, Dg)
      USE COMMOD
      USE ALLFUN
      IMPLICIT NONE

      TYPE(bcType), INTENT(IN) :: lBc
      TYPE(mshType), INTENT(IN) :: lM
      TYPE(faceType), INTENT(IN) :: lFa
      REAL(KIND=8), INTENT(IN) :: Yg(tDof,tnNo), Dg(tDof,tnNo)

      LOGICAL :: eDir(maxnsd), l1, l2, l3, l4
      INTEGER :: a, e, i, g, Ac, Ec, ss, ee, lDof, nNo, nEl, nG, eNoN,
     2   eNoNb, cPhys
      REAL(KIND=8) :: w, Jac, xp(nsd), xi(nsd), xi0(nsd), nV(nsd),
     2   ub(nsd), tauB(2), Ks(nsd,nsd), rt, xiL(2), Nl(2)

      INTEGER, ALLOCATABLE :: ptr(:)
      REAL(KIND=8), ALLOCATABLE :: N(:), Nb(:), Nxi(:,:), Nx(:,:),
     2   xl(:,:), xbl(:,:), yl(:,:), ubl(:,:), ubg(:,:), tmpA(:,:),
     3   tmpY(:,:), lR(:,:), lK(:,:,:)

      nNo   = lFa%nNo
      nEl   = lFa%nEl
      nG    = lFa%nG
      eNoNb = lFa%eNoN
      eNoN  = lM%eNoN

      tauB  = lBc%tauB

      ss    = eq(cEq)%s
      ee    = eq(cEq)%e
      IF (eq(cEq)%dof .EQ. nsd+1) ee = ee - 1
      eDir  = .FALSE.
      lDof  = 0
      DO i=1, nsd
         IF (lBc%eDrn(i) .NE. 0) THEN
            eDir(i) = .TRUE.
            lDof = lDof + 1
         END IF
      END DO
      IF (lDof .EQ. 0) lDof = ee - ss + 1

      ALLOCATE(tmpA(lDof,nNo), tmpY(lDof,nNo))
      CALL SETBCDIRL(lBc, lFa, tmpA, tmpY, lDof)
      IF (BTEST(lBc%bType,bType_impD)) tmpY(:,:) = tmpA(:,:)

      ALLOCATE(ubg(nsd,tnNo))
      ubg = 0D0
      IF (ANY(eDir)) THEN
         DO a=1, nNo
            Ac = lFa%gN(a)
            DO i=1, nsd
               lDof = 0
               IF (eDir(i)) THEN
                  lDof = lDof + 1
                  ubg(i,Ac) = tmpY(lDof,a)
               END IF
            END DO
         END DO
      ELSE
         DO a=1, nNo
            Ac = lFa%gN(a)
            ubg(:,Ac) = tmpY(:,a)
         END DO
      END IF
      DEALLOCATE(tmpA, tmpY)

      ALLOCATE(Nb(eNoNb), xbl(nsd,eNoNb), ubl(nsd,eNoNb))

      ALLOCATE(N(eNoN), Nxi(nsd,eNoN), Nx(nsd,eNoN), xl(nsd,eNoN),
     2   yl(tDof,eNoN), ptr(eNoN), lR(dof,eNoN), lK(dof*dof,eNoN,eNoN))

!     Initialize parameteric coordinate for Newton's iterations
      xi0 = 0D0
      DO g=1, lM%nG
         xi0 = xi0 + lM%xi(:,g)
      END DO
      xi0 = xi0 / REAL(lM%nG,KIND=8)

!     Set bounds on the parameteric coordinates
      xiL(1) = -1.0001D0
      xiL(2) =  1.0001D0
      IF (lM%eType.EQ.eType_TRI .OR. lM%eType.EQ.eType_TET) THEN
         xiL(1) = -0.0001D0
      END IF

!     Set bounds on shape functions
      Nl(1) = -0.0001D0
      Nl(2) =  1.0001d0
      IF (lM%eType.EQ.eType_QUD .OR. lM%eType.EQ.eType_BIQ) THEN
         Nl(1) = -0.1251D0
         Nl(2) =  1.0001D0
      END IF

      DO e=1, nEl
         Ec = lFa%gE(e)
         cDmn  = DOMAIN(lM, cEq, Ec)
         cPhys = eq(cEq)%dmn(cDmn)%phys

         IF (cPhys .NE. phys_fluid) err =
     2      " Weak Dirichlet BC formulated for fluid phys only"

         DO a=1, eNoN
            Ac = lM%IEN(a,Ec)
            ptr(a)  = Ac
            xl(:,a) = x(:,Ac)
            IF (mvMsh) xl(:,a) = xl(:,a) + Dg(nsd+2:2*nsd+1,Ac)
            yl(:,a) = Yg(:,Ac)
         END DO

         DO a=1, eNoNb
            Ac = lFa%IEN(a,e)
            xbl(:,a) = x(:,Ac)
            ubl(:,a) = ubg(:,Ac)
            IF (mvMsh) xbl(:,a) = xbl(:,a) + Dg(nsd+2:2*nsd+1,Ac)
         END DO

         lK = 0D0
         lR = 0D0
         DO g=1, nG
            CALL GNNB(lFa, e, g, nV)
            Jac = SQRT(NORM(nV))
            nV  = nV/Jac
            w   = lFa%w(g) * Jac
            Nb  = lFa%N(:,g)

            xp = 0D0
            ub = 0D0
            DO a=1, eNoNb
               xp = xp + xbl(:,a)*Nb(a)
               ub = ub + ubl(:,a)*Nb(a)
            END DO

            xi = xi0
            CALL GETXI(lM%eType, eNoN, xl, xp, xi, l1)

!           Check if parameteric coordinate is within bounds
            a = 0
            DO i=1, nsd
               IF (xi(i).GE.xiL(1) .AND. xi(i).LE.xiL(2)) a = a + 1
            END DO
            l2 = a .EQ. nsd

            CALL GETGNN(nsd, lM%eType, eNoN, xi, N, Nxi)

!           Check if shape functions are within bounds and sum to unity
            i  = 0
            rt = 0D0
            DO a=1, eNoN
               rt = rt + N(a)
               IF (N(a).GT.Nl(1) .AND. N(a).LT.Nl(2)) i = i + 1
            END DO
            l3 = i .EQ. eNoN
            l4 = rt.GE.0.9999D0 .AND. rt.LE.1.0001D0

            l1 = ALL((/l1, l2, l3, l4/))
            IF (.NOT.l1) err = " Error in computing face shape function"

            IF (g.EQ.1 .OR. .NOT.lM%lShpF)
     2         CALL GNN(eNoN, nsd, Nxi, xl, Nx, Jac, Ks)

            IF (nsd .EQ. 3) THEN
               CALL BWFLUID3D(eNoN, w, N, Nx, yl, ub, nV, tauB, lR, lK)
            ELSE
               CALL BWFLUID2D(eNoN, w, N, Nx, yl, ub, nV, tauB, lR, lK)
            END IF
         END DO

!     Now doing the assembly part
#ifdef WITH_TRILINOS
         IF (eq(cEq)%assmTLS) THEN
            CALL TRILINOS_DOASSEM(eNoN, ptr, lK, lR)
         ELSE
#endif
            CALL DOASSEM(eNoN, ptr, lK, lR)
#ifdef WITH_TRILINOS
         END IF
#endif
      END DO

      RETURN
      END SUBROUTINE SETBCDIRWL
!####################################################################
!     cplBC is set here
      SUBROUTINE SETBCCPL
      USE COMMOD
      USE ALLFUN
      IMPLICIT NONE

      INTEGER, PARAMETER :: iEq = 1

      LOGICAL RCRflag
      INTEGER iFa, ptr, iBc, iM
      REAL(KIND=8) tmp

      IF (cplBC%schm .EQ. cplBC_I) THEN
         CALL CALCDERCPLBC
      ELSE
         RCRflag = .FALSE.
         DO iBc=1, eq(iEq)%nBc
            iFa = eq(iEq)%bc(iBc)%iFa
            iM  = eq(iEq)%bc(iBc)%iM
            ptr = eq(iEq)%bc(iBc)%cplBCptr
            IF (BTEST(eq(iEq)%bc(iBc)%bType,bType_RCR)) THEN
               IF (.NOT.RCRflag) RCRflag = .TRUE.
            END IF
            IF (ptr .NE. 0) THEN
               IF (BTEST(eq(iEq)%bc(iBc)%bType,bType_Neu)) THEN
                  cplBC%fa(ptr)%Qo = Integ(msh(iM)%fa(iFa),Yo,1,nsd)
                  cplBC%fa(ptr)%Qn = Integ(msh(iM)%fa(iFa),Yn,1,nsd)
                  cplBC%fa(ptr)%Po = 0D0
                  cplBC%fa(ptr)%Pn = 0D0
               ELSE IF (BTEST(eq(iEq)%bc(iBc)%bType,bType_Dir)) THEN
                  tmp = msh(iM)%fa(iFa)%area
                  cplBC%fa(ptr)%Po = Integ(msh(iM)%fa(iFa),Yo,nsd+1)/tmp
                  cplBC%fa(ptr)%Pn = Integ(msh(iM)%fa(iFa),Yn,nsd+1)/tmp
                  cplBC%fa(ptr)%Qo = 0D0
                  cplBC%fa(ptr)%Qn = 0D0
               END IF
            END IF
         END DO
         IF (cplBC%useGenBC) THEN
            CALL genBC_Integ_X('T')
         ELSE
            CALL cplBC_Integ_X(RCRflag)
         END IF
      END IF

      DO iBc=1, eq(iEq)%nBc
         iFa = eq(iEq)%bc(iBc)%iFa
         ptr = eq(iEq)%bc(iBc)%cplBCptr
         IF (ptr .NE. 0) eq(iEq)%bc(iBc)%g = cplBC%fa(ptr)%y
      END DO

      RETURN
      END SUBROUTINE SETBCCPL
!--------------------------------------------------------------------
!     cplBC derivative is calculated here
      SUBROUTINE CALCDERCPLBC
      USE COMMOD
      USE ALLFUN
      IMPLICIT NONE

      INTEGER, PARAMETER :: iEq = 1
      REAL(KIND=8), PARAMETER :: absTol = 1D-8, relTol = 1D-5

      LOGICAL RCRflag
      INTEGER iFa, i, j, ptr, iBc, iM
      REAL(KIND=8) orgQ, orgY, diff, area

      IF (ALL(cplBC%fa%bGrp.EQ.cplBC_Dir)) RETURN

      RCRflag = .FALSE.
      DO iBc=1, eq(iEq)%nBc
         iFa = eq(iEq)%bc(iBc)%iFa
         iM  = eq(iEq)%bc(iBc)%iM
         ptr = eq(iEq)%bc(iBc)%cplBCptr
         IF (BTEST(eq(iEq)%bc(iBc)%bType,bType_RCR)) THEN
            IF (.NOT.RCRflag) RCRflag = .TRUE.
         END IF
         IF (ptr .NE. 0) THEN
            IF (BTEST(eq(iEq)%bc(iBc)%bType,bType_Neu)) THEN
               cplBC%fa(ptr)%Qo = Integ(msh(iM)%fa(iFa),Yo,1,nsd)
               cplBC%fa(ptr)%Qn = Integ(msh(iM)%fa(iFa),Yn,1,nsd)
               cplBC%fa(ptr)%Po = 0D0
               cplBC%fa(ptr)%Pn = 0D0
            ELSE IF (BTEST(eq(iEq)%bc(iBc)%bType,bType_Dir)) THEN
               area = msh(iM)%fa(iFa)%area
               cplBC%fa(ptr)%Po = Integ(msh(iM)%fa(iFa),Yo,nsd+1)/area
               cplBC%fa(ptr)%Pn = Integ(msh(iM)%fa(iFa),Yn,nsd+1)/area
               cplBC%fa(ptr)%Qo = 0D0
               cplBC%fa(ptr)%Qn = 0D0
            END IF
         END IF
      END DO

      IF (cplBC%useGenBC) THEN
         CALL genBC_Integ_X('D')
      ELSE
         CALL cplBC_Integ_X(RCRflag)
      END IF

      j    = 0
      diff = 0D0
      DO iBc=1, eq(iEq)%nBc
         i = eq(iEq)%bc(iBc)%cplBCptr
         IF (i.NE.0 .AND. BTEST(eq(iEq)%bc(iBc)%bType,bType_Neu)) THEN
            diff = diff + cplBC%fa(i)%Qo**2D0
            j = j + 1
         END IF
      END DO
      diff = SQRT(diff/REAL(j,8))
      IF (diff*relTol .LT. absTol) THEN
         diff = absTol
      ELSE
         diff = diff*relTol
      END IF

      DO iBc=1, eq(iEq)%nBc
         i = eq(iEq)%bc(iBc)%cplBCptr
         IF (i.NE.0 .AND. BTEST(eq(iEq)%bc(iBc)%bType,bType_Neu)) THEN
            orgY = cplBC%fa(i)%y
            orgQ = cplBC%fa(i)%Qn
            cplBC%fa(i)%Qn = cplBC%fa(i)%Qn + diff

            IF (cplBC%useGenBC) THEN
               CALL genBC_Integ_X('D')
            ELSE
               CALL cplBC_Integ_X(RCRflag)
            END IF

            eq(iEq)%bc(iBc)%r = (cplBC%fa(i)%y - orgY)/diff

            cplBC%fa(i)%y  = orgY
            cplBC%fa(i)%Qn = orgQ
         END IF
      END DO

      RETURN
      END SUBROUTINE CALCDERCPLBC
!--------------------------------------------------------------------
!     Interface to call 0D code (genBC/gcode)
      SUBROUTINE genBC_Integ_X(genFlag)
      USE COMMOD
      USE ALLFUN
      IMPLICIT NONE
      CHARACTER, INTENT(IN) :: genFlag

      INTEGER fid, iFa, nDir, nNeu
      REAL(KIND=8), ALLOCATABLE :: y(:)

      nDir  = 0
      nNeu  = 0
      IF (cm%mas()) THEN
         DO iFa=1, cplBC%nFa
            IF (cplBC%fa(iFa)%bGrp .EQ. cplBC_Dir) THEN
               nDir = nDir + 1
            ELSE IF (cplBC%fa(iFa)%bGrp .EQ. cplBC_Neu) THEN
               nNeu = nNeu + 1
            END IF
         END DO
         fid = 1
         OPEN(fid, FILE=cplBC%commuName, FORM='UNFORMATTED')
         WRITE(fid) genFlag
         WRITE(fid) dt
         WRITE(fid) nDir
         WRITE(fid) nNeu
         DO iFa=1, cplBC%nFa
            IF (cplBC%fa(iFa)%bGrp .EQ. cplBC_Dir) THEN
               WRITE(fid) cplBC%fa(iFa)%Po, cplBC%fa(iFa)%Pn
            END IF
         END DO
         DO iFa=1, cplBC%nFa
            IF (cplBC%fa(iFa)%bGrp .EQ. cplBC_Neu) THEN
               WRITE(fid) cplBC%fa(iFa)%Qo, cplBC%fa(iFa)%Qn
            END IF
         END DO
         CLOSE(fid)

         CALL SYSTEM(TRIM(cplBC%binPath)//" "//TRIM(cplBC%commuName))

         OPEN(fid,FILE=cplBC%commuName,STATUS='OLD',FORM='UNFORMATTED')
         DO iFa=1, cplBC%nFa
            IF (cplBC%fa(iFa)%bGrp .EQ. cplBC_Dir) THEN
               READ(fid) cplBC%fa(iFa)%y
            END IF
         END DO
         DO iFa=1, cplBC%nFa
            IF (cplBC%fa(iFa)%bGrp .EQ. cplBC_Neu) THEN
               READ(fid) cplBC%fa(iFa)%y
            END IF
         END DO
         CLOSE(fid)
      END IF

      IF (.NOT.cm%seq()) THEN
         ALLOCATE(y(cplBC%nFa))
         IF (cm%mas()) y = cplBC%fa%y
         CALL cm%bcast(y)
         IF (cm%slv()) cplBC%fa%y = y
         DEALLOCATE(y)
      END IF

      RETURN
      END SUBROUTINE genBC_Integ_X
!--------------------------------------------------------------------
!     Interface to call 0D code (cplBC)
      SUBROUTINE cplBC_Integ_X(RCRflag)
      USE COMMOD
      USE ALLFUN
      IMPLICIT NONE

      LOGICAL, INTENT(IN) :: RCRflag

      INTEGER fid, iFa, istat
      REAL(KIND=8), ALLOCATABLE :: y(:)

      IF (cm%mas()) THEN
         istat = 0
         IF (RCRflag) THEN
            CALL RCR_Integ_X(istat)
         ELSE
            fid = 1
            OPEN(fid, FILE=cplBC%commuName, FORM='UNFORMATTED')
            WRITE(fid) cplBC%nFa
            WRITE(fid) cplBC%nX
            WRITE(fid) cplBC%nXp
            WRITE(fid) dt
            WRITE(fid) MAX(time-dt, 0D0)
            WRITE(fid) cplBC%xo
            DO iFa=1, cplBC%nFa
               WRITE(fid) cplBC%fa(iFa)%bGrp
               WRITE(fid) cplBC%fa(iFa)%Qo
               WRITE(fid) cplBC%fa(iFa)%Qn
               WRITE(fid) cplBC%fa(iFa)%Po
               WRITE(fid) cplBC%fa(iFa)%Pn
               WRITE(fid) cplBC%fa(iFa)%name
            END DO
            CLOSE(fid)

            CALL SYSTEM(TRIM(cplBC%binPath)//" "//TRIM(cplBC%commuName))

            OPEN(fid,FILE=TRIM(cplBC%commuName),STATUS='OLD',
     2         FORM='UNFORMATTED')
            READ(fid) istat
            READ(fid) cplBC%xn
            READ(fid) cplBC%xp
            DO iFa=1, cplBC%nFa
               READ(fid) cplBC%fa(iFa)%y
            END DO
            CLOSE(fid)
         END IF
      END IF

      CALL cm%bcast(istat)
      IF (istat .NE. 0) THEN
         IF (RCRflag) THEN
            std = "RCR integration error detected, Aborting!"
         ELSE
            std = "CPLBC Error detected, Aborting!"
         END IF
         CALL STOPSIM()
      END IF

      IF (.NOT.cm%seq()) THEN
         ALLOCATE(y(cplBC%nFa))
         IF (cm%mas()) y = cplBC%fa%y
         CALL cm%bcast(cplBC%xn)
         CALL cm%bcast(y)
         IF (cm%slv()) cplBC%fa%y = y
         DEALLOCATE(y)
      END IF

      RETURN
      END SUBROUTINE cplBC_Integ_X
!--------------------------------------------------------------------
      SUBROUTINE RCR_Integ_X(istat)
      USE COMMOD, ONLY : dt, time, cplBC
      IMPLICIT NONE
      INTEGER, INTENT(INOUT) :: istat

      INTEGER, PARAMETER :: nTS = 100
      INTEGER i, n, nX
      REAL(KIND=8) r, tt, dtt, trk

      REAL(KIND=8), ALLOCATABLE :: Rp(:), C(:), Rd(:), Pd(:), X(:),
     2   Xrk(:), frk(:,:), Qrk(:,:)

      tt  = MAX(time-dt, 0D0)
      dtt = dt/REAL(nTS, KIND=8)

      nX  = cplBC%nFa
      ALLOCATE(Rp(nX), C(nX), Rd(nX), Pd(nX), X(nX), Xrk(nX), frk(nX,4),
     2   Qrk(nX,4))

      DO i=1, nX
         Rp(i) = cplBC%fa(i)%RCR%Rp
         C (i) = cplBC%fa(i)%RCR%C
         Rd(i) = cplBC%fa(i)%RCR%Rd
         Pd(i) = cplBC%fa(i)%RCR%Pd
      END DO
      X = cplBC%xo

      DO n=1, nTS
         DO i=1, 4
            r = REAL(i-1,KIND=8)/3.0D0
            r = (REAL(n-1,KIND=8) + r)/REAL(nTS,KIND=8)
            Qrk(:,i) = cplBC%fa(:)%Qo +
     2         (cplBC%fa(:)%Qn - cplBC%fa(:)%Qo)*r
         END DO

!        RK-4 1st pass
         trk = tt
         Xrk = X
         frk(:,1) = (Qrk(:,1) - (Xrk-Pd(:))/Rd(:))/C(:)

!        RK-4 2nd pass
         trk = tt + dtt/3.0D0
         Xrk = X  + dtt*frk(:,1)/3.0D0
         frk(:,2) = (Qrk(:,2) - (Xrk-Pd(:))/Rd(:))/C(:)

!        RK-4 3rd pass
         trk = tt + 2.0D0*dtt/3.0D0
         Xrk = X  - dtt*frk(:,1)/3.0D0 + dtt*frk(:,2)
         frk(:,3) = (Qrk(:,3) - (Xrk-Pd(:))/Rd(:))/C(:)

!        RK-4 4th pass
         trk = tt + dtt
         Xrk = X  + dtt*frk(:,1) - dtt*frk(:,2) + dtt*frk(:,3)
         frk(:,4) = (Qrk(:,4) - (Xrk-Pd(:))/Rd(:))/C(:)

         r  = dtt/8.0D0
         X  = X + r*(frk(:,1) + 3.0D0*(frk(:,2) + frk(:,3)) + frk(:,4))
         tt = tt + dtt

         DO i=1, nX
            IF (ISNAN(X(i))) THEN
               PRINT*, "ERROR: NaN detected in RCR integration"
               istat = -1
               RETURN
            END IF
         END DO
      END DO

      cplBC%xn = X
      cplBC%xp(1) = tt
      DO i=1, nX
         cplBC%xp(i+1) = Qrk(i,4) !cplBC%fa(i)%Qn
         cplBC%fa(i)%y = X(i) + (cplBC%fa(i)%Qn * Rp(i))
      END DO

      DEALLOCATE(Rp, C, Rd, Pd, X, Xrk, frk, Qrk)

      RETURN
      END SUBROUTINE RCR_Integ_X
!####################################################################
! Below defines the SET_BC methods for the Coupled Momentum Method (CMM)
      SUBROUTINE SETBCCMM(Ag, Dg)
      USE COMMOD
      IMPLICIT NONE

      REAL(KIND=8), INTENT(IN) :: Ag(tDof,tnNo), Dg(tDof,tnNo)

      INTEGER iFa, iBc, iM

      DO iBc=1, eq(cEq)%nBc
          IF(.NOT.BTEST(eq(cEq)%bc(iBc)%bType,bType_CMM)) CYCLE
          iFa = eq(cEq)%bc(iBc)%iFa
          iM = eq(cEq)%bc(iBc)%iM
          IF (msh(iM)%eType .NE. eType_TET .AND.
     2        msh(iM)%fa(iFa)%eType .NE. eType_TRI) THEN
              err = "CMM equation is formulated for tetrahedral "//
     2           "elements (volume) and triangular (surface) elements"
          END IF
          CALL SETBCCMML(msh(iM)%fa(iFa), Ag, Dg)
      END DO

      RETURN
      END SUBROUTINE SETBCCMM
!--------------------------------------------------------------------
!     This defines the pseudo-structural equations to solve on the
!     boundaries of the lateral surfaces for the CMM method. It
!     borrows heavily from the current implementation of the 2D
!     linear elasticity equations, modified for the CMM method
!     It then will add the contributions to the LHS and RHS matrices
      SUBROUTINE SETBCCMML(lFa, Ag, Dg)
      USE COMMOD
      USE ALLFUN
      IMPLICIT NONE

      TYPE(faceType), INTENT(IN) :: lFa
      REAL(KIND=8), INTENT(IN) :: Ag(tDof,tnNo), Dg(tDof,tnNo)

      INTEGER a, e, Ac, iM, eNoN
      REAL(KIND=8) :: pSl(6), vwp(2)

      INTEGER, ALLOCATABLE :: ptr(:)
      REAL(KIND=8), ALLOCATABLE :: al(:,:), dl(:,:), xl(:,:), bfl(:,:)

      iM   = lFa%iM
      eNoN = lFa%eNoN
      ALLOCATE(al(tDof,eNoN), dl(tDof,eNoN), xl(3,eNoN), bfl(3,eNoN),
     2   ptr(eNoN))

!     Constructing the CMM contributions to the LHS/RHS and
!     assembling them
      DO e=1, lFa%nEl
         cDmn = DOMAIN(msh(iM), cEq, lFa%gE(e))
         IF (eq(cEq)%dmn(cDmn)%phys .NE. phys_CMM) CYCLE

         pSl = 0D0
         vwp = 0D0
         DO a=1, eNoN
            Ac = lFa%IEN(a,e)
            ptr(a)   = Ac
            xl(:,a)  = x(:,Ac)
            al(:,a)  = Ag(:,Ac)
            dl(:,a)  = Dg(:,Ac)
            bfl(:,a) = Bf(:,Ac)
            IF(ALLOCATED(pS0)) THEN
               pSl(:) = pSl(:) + pS0(:,Ac)
            END IF
            IF (cmmVarWall) THEN
               vwp(:) = vwp(:) + varWallProps(:,Ac)
            END IF
         END DO
         pSl(:) = pSl(:) / REAL(eNoN,KIND=8)
         vwp(:) = vwp(:) / REAL(eNoN,KIND=8)

!     Add CMM BCs contributions to the LHS/RHS
         CALL CMMb(lFa, e, eNoN, al, dl, xl, bfl, pSl, vwp, ptr)
      END DO

      DEALLOCATE(al, dl, xl, bfl, ptr)

      RETURN
      END SUBROUTINE SETBCCMML
!####################################################################
