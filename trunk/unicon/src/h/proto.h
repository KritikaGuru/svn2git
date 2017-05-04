/*
 * proto.h -- prototypes for library functions.
 */

/*
 * The following code is operating-system dependent. [@proto.01].
 *  Prototypes for library functions.
 */

#if PORT
   Deliberate Syntax Error
#endif					/* PORT */

#if AMIGA
   #if LATTICE
      #include <dos.h>
   #endif				/* LATTICE */
   #if __SASC
      /* GLOBAL and STATIC are defined in tparse.c as well as
      in <exec/types.h>, which is included in <dos.h>. */
      #undef GLOBAL        
      #undef STATIC
      #include <dos.h>
      #undef GLOBAL        
      #undef STATIC
      /* From tparse.c */
      # define GLOBAL 273
      # define STATIC 286
   #endif                               /* __SASC */
#endif					/* AMIGA */

#if MSDOS || OS2
   #if HIGHC_386
      int	brk		(pointer p);
      pointer sbrk		(msize n);
   #endif				/* HIGHC_386 */
   #if INTEL_386
      #include <dos.h>
      int	brk		(pointer p);
   #endif				/* INTEL_386 */
   #if MICROSOFT || TURBO || NT || BORLAND_386 || SCCX_MX
#ifndef LCC
      #include <dos.h>
#endif					/* not LCC */
   #endif				/* MICROSOFT || TURBO ... */
#endif					/* MSDOS || OS2 */

/*
 * End of operating-system specific code.
 */

#include "../h/mproto.h"

/*
 * These must be after prototypes to avoid clash with system
 * prototypes.
 */

#if IntBits == 16
   #define sbrk lsbrk
   #define strlen lstrlen
   #define qsort lqsort
#endif					/* IntBits == 16 */
