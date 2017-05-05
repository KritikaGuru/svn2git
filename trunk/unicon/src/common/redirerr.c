#include "../h/gsupport.h"

/*
 * redirerr - redirect error output to the named file. '-' indicates that
 *  it should be redirected to standard out.
 */
int redirerr(p)
char *p;
   {
   if ( *p == '-' ) { /* let - be stdout */

/*
 * The following code is operating-system dependent [@redirerr.01].  Redirect
 *  stderr to stdout.
 */

#if PORT
   /* may not be possible */
   Deliberate Syntax Error
#endif					/* PORT */

#if AMIGA
   #if LATTICE
      /*
       * The following code varies from compiler to compiler, or even
       *  between versions of the same compiler (e.g. lattice 3.1 vs. 4.0).
       */
      stderr->_file = stdout->_file;
      stderr->_flag = stdout->_flag;
   #endif				/* LATTICE */
#endif					/* AMIGA */

#if ARM || MVS || VM
   /* cannot do this */
#endif					/* ARM || MVS || VM */

#if MSDOS || OS2 || VMS
   #if NT
      /*
       * Don't like doing this, but it seems to work.
       */
      setbuf(stdout,NULL);
      setbuf(stderr,NULL);
      stderr->_file = stdout->_file;
   #else				/* NT */
      dup2(fileno(stdout),fileno(stderr));
   #endif				/* NT */
#endif					/* MSDOS || OS2 ... */


#if MACINTOSH
   #if MPW
      close(fileno(stderr));
      dup(fileno(stdout));
   #endif				/* MPW */
#endif					/* MACINTOSH */

#if UNIX
      /*
       * This relies on the way UNIX assigns file numbers.
       */
      close(fileno(stderr));
      dup(fileno(stdout));
#endif					/* UNIX */

/*
 * End of operating-system specific code.
 */

       }
    else    /* redirecting to named file */
       if (freopen(p, "w", stderr) == NULL)
          return 0;
   return 1;
   }
