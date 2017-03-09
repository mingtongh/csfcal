module convertharmonics
      !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
      !Step 1: create new basis list, with 2 coef columns for each csf
      !Step 2: calculate coefs for each csf
      !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
 use, intrinsic :: iso_fortran_env, only: rk => real64
 use prep, only: i16b, ARRAY_START_LENGTljd
 !, neact TODO for testing purposed this is not imported, will need to afterwards
 use detgen, only: locate_det, delocate
    implicit none
    contains

     subroutine init_Ztable(ynbasis, ncsf, zbasis, zcoeftable, znbasis)
          integer, intent(in) :: ynbasis, ncsf
          integer(i16b), allocatable :: zbasis(:, :)
          real(rk), allocatable :: zcoeftable(:, :)
          integer :: znbasis, nrows
          integer :: neact 

          znbasis = 0
          nrows = 2**neact * ynbasis
          if(.not.allocated(zbasis)) then
              allocate(zbasis(nrows, 2))
          endif
          if(.not.allocated(zcoeftable)) then
              allocate(zcoeftable(nrows, ncsf*2))
          endif
      end subroutine init_Ztable

      !subroutine Y2Z_det(det, nshell_1config, econfigs, coef, allzbasislist, allzcoefs, nzbasis)
      !    integer(i16b), intent(in) :: det(:)
      !    integer, intent(in) :: nshell_1config, econfigs(:, :)
      !    real(rk), intent(in):: coef
      !    integer(i16b)

      integer function sign_ordets(ldet, rdet)
          integer(i16b), intent(in) :: ldet, rdet !single det same spin, not a pair
          !ldet is the newcomer that should be bigger, to be inserted to rdet from the left side
          integer :: ltail, rhead
          !In later use, as a convention, should put det already process at rdet, 
          !but new single det to be incorporated at ldet
          integer(i16b) ::tpl, subbit

          if(iand(ldet, rdet).ne.0) then 
              sign_ordets = 0
          else
              !position of the leading 1 in rdet
              rhead = leadz(0_i16b) - leadz(rdet) - 1 !position in bit starts from 0
              write(*, *) "rhead pos = ", rhead
              sign_ordets = 1
              tpl = ldet

              ltail = trailz(tpl)
              do while(ltail.lt.rhead.AND.tpl.ne.0)
                  subbit = ibits(rdet, ltail, rhead - ltail + 1)
                  write(*, '(1B16)') subbit
                  if(poppar(subbit).eq.1) then 
                      sign_ordets = - sign_ordets
                  endif
                  tpl = ibclr(tpl, ltail)
                  ltail = trailz(tpl)
              enddo
          endif

      end function sign_ordets

      !TODO subroutine Y2Z_det not naive - implement algo on notebook
      subroutine Y2Z_singledet(det, coef, zbasislist, zcoefs, nzbasis)
          integer(i16b), intent(in) :: det(:)
          real(rk), intent(in) :: coef
          integer(i16b) :: zbasislist(:, :) ! Append to this list
          real(rk) :: zcoefs(:, :) !two columnsn real, imag
          integer :: nzbasis ! number of rows already in zbasislist
          integer(i16b), allocatable :: singledets(:, :) !four columns up dn for |m|, -|m| 
                                                         !             det = 0, m = 0
          real(rk), allocatable :: singlecoefs(:, :) ! four columns real, imag for each det
          integer(i16b) :: tpup, tpdn, tpplus, tpminus
          integer :: nelec, pos, pos2, msign, i, istart, tpsign

           write(*, *) 'Entering Y2Z_singledet, input det pair is '
           write(*, '(2B16)') det(1:2)
           tpup = det(1)
           tpdn = det(2)
           allocate(singledets(nelec, 4))
           allocate(singlecoefs(nelec, 4))
           write(*, *) 'Generating single electron det list'

           i = 1
           !generate single dets from det up
           do while(tpup.ne.0)
               pos = trailz(tpup)
               msign = sign_m(pos, pos2, tpplus, tpminus)
               singledets(i, 1:4) = (/tpplus, 0_i16b, tpminus, 0_i16b/)
               singlecoefs(i, 1:4) = (/1._rk, 0._rk, 0._rk, msign*1._rk/)
               write(*, '(4B16)') singledets(i, 1:4)
               write(*, *) singlecoefs(i, 1:4)
               i = i + 1
               tpup = ibclr(tpup, pos) !not labeling m, -m coexistance, may need to later
           end do
           do while(tpdn.ne.0)
               pos = trailz(tpdn)
               msign = sign_m(pos, pos2, tpplus, tpminus)
               singledets(i, 1:4) = (/ 0_i16b,tpplus, 0_i16b, tpminus/)
               singlecoefs(i, 1:4) = (/1._rk, 0._rk, 0._rk, msign*1._rk/)
               write(*, '(4B16)') singledets(i, 1:4)
               write(*, *) singlecoefs(i, 1:4)
               i = i + 1
               tpdn = ibclr(tpdn, pos) !not labeling m, -m coexistance, may need to later
           end do
           !now i is index for next row
           nelec = i - 1
           write(*, *) 'total number of electrons = ', nelec

           !code above this line tested, all correct 
           if(.not.allocated(zbasislist)) then
               allocate(zbasislist(ARRAY_START_LENGTH, 2))
           endif

           if(.not.allocated(zbasislist)) then
               allocate(zcoefs(ARRAY_START_LENGTH, 2))
               nzbasis = 0
           endif
           istart = nzbasis + 1
           zbasislist(istart, 1:2) = (/0_i16b, 0_i16b/)
           zcoefs(istart, 1:2) = (/1._rk, 0._rk/)
           iend = istart !range to do ior
           i = istart !
           do j = 1, nelec ! index for processing singledets
               do i = istart, iend
                     !case m == 0 
                     if(singledets(j, 3).eq.0.AND.singledets(j, 4).eq.0) then
                         zbasislist(i, 1) = ior(singledets(j, 1), zbasislist(i, 1))
                         zbasislist(i, 2) = ior(singledets(j, 2), zbasislist(i, 2))
                         tpsign = sign_ordets(singledets(j, 1), zbasislist(i, 1)) * &
                             &sign_ordets(singledets(j, 2), zbasislist(i, 2))
                         call product_cmplx(singlecoefs(j, 1:2), zbasislist(i, 1:2), &
                             &zbasislist(i, 1:2))
                     elseif !TODO case det j not already set
                            !TODO case det j already set
                     endif

               enddo
           enddo
           deallocate(singlecoefs)
           deallocate(singledets)

       end subroutine Y2Z_singledet




      subroutine Y2Z_det_incomplete(det, coef, zbasislist, zcoefs, nzbasis)
          integer(i16b), intent(in) :: det(:)
          real(rk), intent(in):: coef
          integer(i16b) ::  tpup, tpdn, tpplus, tpminus
          integer(i16b), allocatable :: singledets(:, :), zbasislist(:, :)
          real(rk), allocatable :: singlecoefs(:, :), zcoefs(:, :)
          integer :: pos, pos2, i, j,msign, k, nbasis0, npairnot0, nzbasis, nznot0
          !number of dets with m == 0, or m!= 0
          !zbasislist and zcoefs have to be allocated already
         
          integer :: neact !TODO for testing convenience, delete later
          neact = 2
    
          write(*, *) 'Entering Y2Z_det, input det pair is '
          write(*, '(2B16)') det(1:2)
          tpup = det(1)
          tpdn = det(2)
          allocate(singledets(3*neact, 2))
          allocate(singlecoefs(3*neact, 2))
          i = 0
          j = neact
          k = 2*neact

          write(*, *) 'Generating single electron det list'
          write(*, *) 'neact = ', neact
          do while(tpup.ne.0)
            pos = trailz(tpup)
            msign = sign_m(pos, pos2, tpplus, tpminus)
            
            if(msign.eq.0) then
                k = k + 1
                singledets(k, 1) = tpplus !spin up
                singledets(k, 2) = 0_i16b
                singlecoefs(k, 1:2) = (/sqrt(2.), 0./)
                write(*, *)  'm = 0   This index ( 2*neact + ) = ', k
                write(*, '(2B16)') singledets(k, 1:2)
                write(*, *) singlecoefs(k, 1:2)
                tpup = ibclr(tpup, pos)


            elseif(BTEST(tpup, pos2)) then !msign not 0 and -m is set
                k = k + 1
                singledets(k, 1) = ior(tpplus, tpminus) 
                singledets(k, 2) = 0_i16b
                singlecoefs(k, 1:2) = (/0., -2./) ! -2i
                write(*, *) 'm, -m together This index ( 2*neact + ) = ', k
                write(*, '(2B16)') singledets(k, 1:2)
                write(*, *) singlecoefs(k, 1:2)
                tpup = ibclr(tpup, pos)
                tpup = ibclr(tpup, pos2)
            else

                i = i + 1
                j = j + 1
                singledets(i, 1) = tpplus
                singledets(i, 2) = 0_i16b
                singledets(j, 1) = tpminus
                singledets(j, 2) = 0_i16b
                singlecoefs(i, 1:2) =(/1.,0./)
                singlecoefs(j, 1:2) = (/0., msign*1. /)
                write(*, *) 'm != 0', '|m| index = ', i, '-|m| index = ', j
                write(*, '(4B16)') singledets(i, 1:2), singledets(j, 1:2)
                write(*, *) singlecoefs(i, 1:2), singlecoefs(j, 1:2)
                tpup = ibclr(tpup, pos)

            endif

          enddo
           
          do while(tpdn.ne.0)
             pos = trailz(tpdn)
             msign = sign_m(pos, pos2, tpplus, tpminus)
 
             if(msign.eq.0) then
                 k = k + 1
                 singledets(k, 2) = tpplus !spin dn
                 singledets(k, 1) = 0_i16b
                 singlecoefs(k, 1:2) = (/sqrt(2.), 0./)
                 write(*, *)  'm = 0   This index ( 2*neact + ) = ', k
                 write(*, '(2B16)') singledets(k, 1:2) 
                 write(*, *) singlecoefs(k, 1:2)
                 tpdn = ibclr(tpdn, pos)
               

            elseif(BTEST(tpdn, pos2)) then !msign not 0 and -m is set
                k = k + 1
                singledets(k, 2) = ior(tpplus, tpminus) 
                singledets(k, 1) = 0_i16b
                singlecoefs(k, 1:2) = (/0., -2./) ! -2i
                write(*, *) 'm, -m together This index ( 2*neact + ) = ', k
                write(*, '(2B16)') singledets(k, 1:2)
                write(*, *) singlecoefs(k, 1:2)
                tpdn = ibclr(tpdn, pos)
                tpdn = ibclr(tpdn, pos2)
 

             else
 
                 i = i + 1
                 j = j + 1
                 singledets(i, 2) = tpplus
                 singledets(i, 1) = 0_i16b
                 singledets(j, 2) = tpminus
                 singledets(j, 1) = 0_i16b
                 singlecoefs(i, 1:2) =(/1.,0./)
                 singlecoefs(j, 1:2) = (/0., msign*1. /)
 
                 write(*, *) 'm != 0', '|m| index = ', i, '-|m| index = ', j
                 write(*, '(4B16)') singledets(i, 1:2), singledets(j, 1:2)
                 write(*, *) singlecoefs(i, 1:2), singlecoefs(j, 1:2)
                 tpdn = ibclr(tpdn, pos)
     
             endif
          enddo
          nbasis0 = k - 2*neact !number of dets that are real
          npairnot0 = i ! number of |m|, -|m| pairs
          nznot0 = 2**npairnot0
          !nadd = max(1, nznot0)   ! number of zdet pairs to generate

          allocate(zbasislist(nznot0, 2))
          allocate(zcoefs(nznot0, 2))
          !Now fill zbasislist and zcoefs
          if(npairnot0.gt.0) then
              do i = 1, nznot0/2
                  zbasislist(i, 1:2) = singledets(1, 1:2)
                  zcoefs(i, 1:2) = singlecoefs(1, 1:2)
                  j = i + nznot0/2
                  zbasislist(j, 1:2) = singledets(neact + 1, 1:2) 
                  zcoefs(j, 1:2) = singlecoefs(neact + 1, 1:2)
              enddo

              do k = 2, npairnot0
                  i = 0
                  do while(i.lt.(npairnot0-1))
                      !fill in det plus
                      do j = 1, 2**(npairnot0 - k)
                            i = i + 1
                            call product_cmplx(zcoefs(i, 1:2), singlecoefs(k, 1:2), zcoefs(i, 1:2))
                            !if the det to be combined is smaller, there will be a minus sign 
                            if(zbasislist(i, 1).gt.singledets(k, 1)) then
                                zcoefs(i, 1) = - zcoefs(i, 1)
                                zcoefs(i, 2) = - zcoefs(i, 2)
                            endif
                            if(zbasislist(i, 2).gt.singledets(k, 2)) then
                                zcoefs(i, 1) = -zcoefs(i, 1) 
                                zcoefs(i, 2) = -zcoefs(i, 1) 
                            endif
                            zbasislist(i, 1) = ior(zbasislist(i, 1), singledets(k, 1)) 
                            zbasislist(i, 2) = ior(zbasislist(i, 2), singledets(k, 2))
 
                      end do
                      !fill in det minus
                      do j = 1, 2**(npairnot0 - k)
                            i = i + 1
                            call product_cmplx(zcoefs(i, 1:2), singlecoefs(k+neact, 1:2), &
                                & zcoefs(i, 1:2))
                            if(zbasislist(i, 1).gt.singledets(k + neact, 1)) then
                                zcoefs(i, 1) = - zcoefs(i, 1)
                                zcoefs(i, 2) = - zcoefs(i, 2)
                            endif
                            if(zbasislist(i, 2).gt.singledets(k, 2)) then
                                zcoefs(i, 1) = -zcoefs(i, 1) 
                                zcoefs(i, 2) = -zcoefs(i, 1) 
                            endif
 
                            zbasislist(i, 1) = ior(zbasislist(i, 1), singledets(k+neact, 1))
                            zbasislist(i, 2) = ior(zbasislist(i, 2), singledets(k+neact, 2))
 
                       enddo
                   enddo!end while
                   write(*, *) 'For k =', k, 'last i =', i
              enddo

              if(nbasis0.ne.0) then
                  do i = 1, nznot0
                      do j = 1, nbasis0
                          zbasislist(i, 1) = ior(zbasislist(i, 1), singledets(j + neact*2, 1))
                          zbasislist(i, 2) = ior(zbasislist(i, 2), singledets(j + neact*2, 2))
                          call product_cmplx(zcoefs(i, 1:2), singlecoefs(j+neact*2, 1:2), &
                                & zcoefs(i, 1:2))
 
                      enddo
                  enddo
              endif

              ! end of if npairnot0 > 0
          else if(nbasis0.ne.0) then
              ! npairnot0 = 0 all m = 0, or m, -m together 
              ! put all original ydet into zbasis
              zbasislist(1, 1:2) = det(1:2)
              zcoefs(1, 1:2) = (/1., 0./)
              do i = 1, nbasis0
                  call product_cmplx(zcoefs(1, 1:2), singlecoefs(i + neact*2, 1:2), zcoefs(1, 1:2))
              enddo
          endif
    


          write(*, *) 'Final Z zbasislist, zcoefs for this csf'
          do i = 1, nznot0
              write(*, '(2B16)') zbasislist(i, 1:2)
              write(*, *) zcoefs(i, 1), ' + i', zcoefs(i, 2)
          enddo
          deallocate(singlecoefs)
          deallocate(singledets)
      end subroutine Y2Z_det_incomplete


      subroutine product_cmplx(c1, c2, nout)
          real(rk) :: c1(:), c2(:)
          real(rk) :: n1(2), n2(2), nout(:)
          n1(1:2) = c1(1:2)
          n2(1:2) = c2(1:2)
          nout(1) = n1(1)*n2(1) - n1(2)*n2(2)
          nout(2) = n1(1)*n2(2)+ n1(2)*n2(1)
      end subroutine product_cmplx
          
      integer function sign_m(pos, pos2, detplus, detminus)
          ! for a single det not a pair
          integer, intent(in) :: pos
          integer(i16b) :: detplus, detminus
          integer :: pos2, n, l, m
          call delocate(pos, n, l, m)
          if (m.eq.0) then
              sign_m = 0
              detplus = ibset(0_i16b, pos)
              detminus = 0_i16b
              pos2 = pos
          elseif(m.gt.0) then
              sign_m = 1
              detplus = ibset(0_i16b, pos)
              pos2 =  locate_det(n, l, -m)
              detminus = ibset(0_i16b, pos2)
          else
              sign_m = -1
              detminus = ibset(0_i16b, pos)
              pos2 = locate_det(n, l, -m)
              detplus = ibset(0_i16b, pos2)
          endif
          write(*, *) 'function sign_m : pos, pos2, detplus, detminus'
          write(*, '(2I4, 2b16)') pos, pos2, detplus, detminus
      end function sign_m



end module convertharmonics
