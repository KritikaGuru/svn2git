
#define MSWIN64

#define IntBits 32
#define WordBits 64
#define StackAlign 16
#define LongLongWord


/*#define NoCoExpr*/

/*define for png image support, libz is required by PNG */
/*#define HAVE_LIBPNG 1
#define HAVE_LIBZ 1 */    /* DO NOT define if you are using zlib1.dll */

/*define for jpeg image support */
/*#define HAVE_LIBJPEG 1*/

/*define if you have pthreads and want concurrency*/
#define HAVE_LIBPTHREAD 1
#define Concurrent 1
#define NoKeyword__Thread 1
