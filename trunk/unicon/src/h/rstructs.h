/*
 * Run-time data structures.
 */

/*
 * Structures common to the compiler and interpreter.
 */

/*
 * Run-time error numbers and text.
 */
struct errtab {
   int err_no;			/* error number */
   char *errmsg;		/* error message */
   };

/*
 * Descriptor
 */

struct descrip {		/* descriptor */
   word dword;			/*   type field */
   union {
      word integr;		/*   integer value */
      char *sptr;		/*   pointer to character string */
      union block *bptr;	/*   pointer to a block */
      dptr descptr;		/*   pointer to a descriptor */
      } vword;
   };

struct sdescrip {
   word length;			/*   length of string */
   char *string;		/*   pointer to string */
   };

#if defined(Graphics) || defined(PosixFns)

struct si_ {
  char *s;
  int i;
};
typedef struct si_ stringint;
typedef struct si_ *siptr;

#endif					/* Graphics || PosixFns */

/*
 * structure supporting dynamic record types
 */
struct b_proc_list {
   struct b_proc *this;
   struct b_proc_list *next;
};

#ifdef LargeInts
struct b_bignum {		/* large integer block */
   word title;			/*   T_Lrgint */
   word blksize;		/*   block size */
   word msd, lsd;		/*   most and least significant digits */
   int sign;			/*   sign; 0 positive, 1 negative */
   DIGIT digits[1];		/*   digits */
   };
#endif					/* LargeInts */

struct b_real {			/* real block */
   word title;			/*   T_Real */
   double realval;		/*   value */
   };

struct b_cset {			/* cset block */
   word title;			/*   T_Cset */
   word size;			/*   size of cset */
   unsigned int bits[CsetSize];		/*   array of bits */
   };

/*
 * This union was pulled out of struct b_file and made non-anonymous
 * in order to eliminate an error in some version of gcc on amd64.
 */
union f {
   FILE *fp;
#ifdef Graphics
   struct _wbinding *wb;
#endif
#ifdef Messaging
   struct MFile *mf;
#endif               /* Messaging */
#ifdef ISQL
   struct ISQLFile *sqlf;
#endif               /* ISQL */
#ifdef Dbm
   DBM *dbm;
#endif               /* Dbm */
#ifdef Audio
   struct AudioFile *af;
#endif               /* Audio */
#ifdef PseudoPty
     struct ptstruct *pt;
#endif					/* PseudoPty */
   int fd;        /*   other int-based file descriptor */
   };

struct b_file {			/* file block */
   word title;			/*   T_File */
   union f fd;
   word status;			/*   file status */
   struct descrip fname;	/*   file name (string qualifier) */
   };

#ifdef ISQL

  struct ISQLFile {             /* SQL file */
    SQLHDBC hdbc;               /* used by open, close, query, fetch */
    SQLHSTMT hstmt;             /* statement handler */
    char *query;                /* SQL query buffer */
    long qsize;                 /* SQL query buffer size */
    char *tablename;
    struct b_proc *proc;	/* current record constructor procedure */
    int refcount;
    struct ISQLFile *previous, *next; /* links, so we can find & free these*/
  };

#endif					/* ISQL */

#ifdef Messaging
struct MFile {                  /* messaging file abstraction */
   int flags;                   /* request options */
   int state;                   /* our current action */
   Tp_t *tp;                    /* a libtp handle */
   Tpresponse_t *resp;          /* response from the last request */
   void *data;                  /* for storing extra connection data */
   };

struct Mpoplist {
   int msgnum;
   struct Mpoplist *next;
   struct Mpoplist *prev;
   };
#endif                                  /* Messaging */

struct b_lelem {		/* list-element block */
   word title;			/*   T_Lelem */
   word blksize;		/*   size of block */
   union block *listprev;	/*   previous list-element block */
   union block *listnext;	/*   next list-element block */
   word nslots;			/*   total number of slots */
   word first;			/*   index of first used slot */
   word nused;			/*   number of used slots */
   struct descrip lslots[1];	/*   array of slots */
   };

struct b_list {			/* list-header block */
   word title;			/*   T_List */
   word size;			/*   current list size */
   word id;			/*   identification number */
#ifdef Concurrent
   pthread_mutex_t mutex;
#endif				/* Concurrent */
   union block *listhead;	/*   pointer to first list-element block */
   union block *listtail;	/*   pointer to last list-element block */
   };


struct b_intarray {
   word title;			/* T_Intarray */
   word blksize;		/* size of block */
   union block *listp;		/* pointer to the list block */
   union block *dims;		/* dimension sizes, NULL for 1D */
   word a[1];			/* true array size == size, above */
   };

struct b_realarray {
   word title;			/* T_Realarray */
   word blksize;		/* size of block */
   union block *listp;		/* pointer to the list block */
   union block *dims;		/* dimension sizes, NULL for 1D */
   double a[1];			/* true array size == size, above */
   };


struct b_proc {			/* procedure block */
   word title;			/*   T_Proc */
   word blksize;		/*   size of block */

   #if COMPILER
      int (*ccode)();
   #else				/* COMPILER */
      union {			/*   entry points for */
         int (*ccode)();	/*     C routines */
         uword ioff;		/*     and icode as offset */
         pointer icode;		/*     and icode as absolute pointer */
         } entryp;
   #endif				/* COMPILER */

   word nparam;			/*   number of parameters */
   word ndynam;			/*   number of dynamic locals */
   word nstatic;		/*   number of static locals */
   word fstatic;		/*   index (in global table) of first static */
   struct descrip pname;	/*   procedure name (string qualifier) */
   struct descrip lnames[1];	/*   list of local names (qualifiers) */
   };

struct b_record {		/* record block */
   word title;			/*   T_Record */
   word blksize;		/*   size of block */
   word id;			/*   identification number */
   union block *recdesc;	/*   pointer to record constructor */
   struct descrip fields[1];	/*   fields */
   };

/*
 * Alternate uses for procedure block fields, applied to records.
 */
#define nfields	nparam		/* number of fields */
#define recnum nstatic		/* record number */
#define recid fstatic		/* record serial number */
#define recname	pname		/* record name */

struct b_selem {		/* set-element block */
   word title;			/*   T_Selem */
   union block *clink;		/*   hash chain link */
   uword hashnum;		/*   hash number */
   struct descrip setmem;	/*   the element */
   };

/*
 * A set header must be a proper prefix of a table header,
 *  and a set element must be a proper prefix of a table element.
 */
struct b_set {			/* set-header block */
   word title;			/*   T_Set */
   word size;			/*   size of the set */
   word id;			/*   identification number */
   word mask;			/*   mask for slot num, equals n slots - 1 */
   struct b_slots *hdir[HSegs];	/*   directory of hash slot segments */
   };

struct b_table {		/* table-header block */
   word title;			/*   T_Table */
   word size;			/*   current table size */
   word id;			/*   identification number */
   word mask;			/*   mask for slot num, equals n slots - 1 */
   struct b_slots *hdir[HSegs];	/*   directory of hash slot segments */
   struct descrip defvalue;	/*   default table element value */
   };

struct b_slots {		/* set/table hash slots */
   word title;			/*   T_Slots */
   word blksize;		/*   size of block */
   union block *hslots[HSlots];	/*   array of slots (HSlots * 2^n entries) */
   };

struct b_telem {		/* table-element block */
   word title;			/*   T_Telem */
   union block *clink;		/*   hash chain link */
   uword hashnum;		/*   for ordering chain */
   struct descrip tref;		/*   entry value */
   struct descrip tval;		/*   assigned value */
   };

struct b_tvsubs {		/* substring trapped variable block */
   word title;			/*   T_Tvsubs */
   word sslen;			/*   length of substring */
   word sspos;			/*   position of substring */
   struct descrip ssvar;	/*   variable that substring is from */
   };

struct b_tvtbl {		/* table element trapped variable block */
   word title;			/*   T_Tvtbl */
   union block *clink;		/*   pointer to table header block */
   uword hashnum;		/*   hash number */
   struct descrip tref;		/*   entry value */
   };

#ifdef EventMon
struct b_tvmonitored {          /* Monitored variable block */
   word title;                  /*   T_Tvmonitored */
   word cur_actv;		/*   current co-expression activation */
   struct descrip tv;           /*   the variable in the other program */
   };
#endif				/* EventMon */

struct b_external {		/* external block */
   word title;			/*   T_External */
   word blksize;		/*   size of block */
   word exdata[1];		/*   words of external data */
   };

struct astkblk {		  /* co-expression activator-stack block */
   int nactivators;		  /*   number of valid activator entries in
				   *    this block */
   struct astkblk *astk_nxt;	  /*   next activator block */
   struct actrec {		  /*   activator record */
      word acount;		  /*     number of calls by this activator */
      struct b_coexpr *activator; /*     the activator itself */
      } arec[ActStkBlkEnts];
   };

#ifdef PatternType
struct b_pattern {            /*Pattern header block*/
    word title;             /*T_Pattern*/  
    word id;
    word stck_size;         /* size of stack for pattern history during match*/
    union block * pe;		/*   pattern element */
};

struct b_pelem {                      /* Pattern element block */
    word title;                     /* T_Pelem       */
    word pcode;                     /* Indicates Pattern type*/
    union block * pthen;            /*  Pointer to succeeding pointer element*/
    word index;                     /* posn of pattern elem in pointer chain
				     * (used in image) */
    struct descrip parameter;		/*   parameter */    
};
#endif					/* PatternType */

/*
 * Structure for keeping set/table generator state across a suspension.
 */
struct hgstate {		/* hashed-structure generator state */
   int segnum;			/* current segment number */
   word slotnum;		/* current slot number */
   word tmask;			/* structure mask before suspension */
   word sgmask[HSegs];		/* mask in use when the segment was created */
   uword sghash[HSegs];		/* hashnum in process when seg was created */
   };


/*
 * Structure for chaining tended descriptors.
 */
struct tend_desc {
   struct tend_desc *previous;
   int num;
   struct descrip d[1]; /* actual size of array indicated by num */
   };

/*
 * Structure for mapping string names of functions and operators to block
 * addresses.
 */
struct pstrnm {
   char *pstrep;
   struct b_proc *pblock;
   };

struct dpair {
   struct descrip dr;
   struct descrip dv;
   };

/*
 * Allocated memory region structure.  Each program has linked lists of
 * string and block regions.
 */
struct region {
   word  size;				/* allocated region size in bytes */
   char *base;				/* start of region */
   char *end;				/* end of region */
   char *free;				/* free pointer */
   struct region *prev, *next;		/* forms a linked list of regions */
   struct region *Gprev, *Gnext;	/* global (all programs) lists */
   };

#ifdef Double
   /*
    * Data type the same size as a double but without alignment requirements.
    */
   struct size_dbl {
       char s[sizeof(double)];
       };
#endif					/* Double */


#if COMPILER

/*
 * Structures for the compiler.
 */
   struct p_frame {
      struct p_frame *old_pfp;
      struct descrip *old_argp;
      struct descrip *rslt;
      continuation succ_cont;
      struct tend_desc t;
      };
   #endif				/* COMPILER */

/*
 * when debugging is enabled a debug struct is placed after the tended
 *  descriptors in the procedure frame.
 */
struct debug {
   struct b_proc *proc;
   char *old_fname;
   int old_line;
   };

union numeric {			/* long integers or real numbers */
   long integer;
   double real;
   #ifdef LargeInts
      struct b_bignum *big;
   #endif				/* LargeInts */
   };

#if COMPILER
struct b_coexpr {		/* co-expression stack block */
   word title;			/*   T_Coexpr */
   word size;			/*   number of results produced */
   word id;			/*   identification number */
#ifdef Concurrent
   word status;			/*   status (sync vs. async, etc) */
#endif					/* Concurrent */
   struct b_coexpr *nextstk;	/*   pointer to next allocated stack */
   continuation fnc;		/*   function containing co-expression code */
   struct p_frame *es_pfp;	/*   current procedure frame pointer */
   dptr es_argp;		/*   current argument pointer */
   struct tend_desc *es_tend;	/*   current tended pointer */
   char *file_name;		/*   current file name */
   word line_num;		/*   current line_number */
   dptr tvalloc;		/*   where to place transmitted value */
   struct descrip freshblk;	/*   refresh block pointer */
   struct astkblk *es_actstk;	/*   pointer to activation stack structure */
   word cstate[CStateSize];	/*   C state information */
   struct p_frame pf;           /*   initial procedure frame */
   };

struct b_refresh {		/* co-expression block */
   word title;			/*   T_Refresh */
   word blksize;		/*   size of block */
   word nlocals;		/*   number of local variables */
   word nargs;			/*   number of arguments */
   word ntemps;                 /*   number of temporary descriptors */
   word wrk_size;		/*   size of non-descriptor work area */
   struct descrip elems[1];	/*   locals and arguments */
   };

#else					/* COMPILER */

/*
 * Structures for the interpreter.
 */

/*
 * Declarations for entries in tables associating icode location with
 *  source program location.
 */
struct ipc_fname {
   word ipc;		/* offset of instruction into code region */
   word fname;		/* offset of file name into string region */
   };

struct ipc_line {
   word ipc;		/* offset of instruction into code region */
   int line;		/* line number */
   };

#ifdef Concurrent
struct threadstate {
   pthread_t tid;
   /* signal mask? etc. */
   /*
    * main goal for this struct is to hold VM-specific per-thread variables.
    */
   };
#endif					/* Concurrent */

#ifdef MultiThread
/*
 * Program state encapsulation.  This consists of the VARIABLE parts of
 * many global structures.
 */
struct progstate {
   long hsize;				/* size of icode, 0 = C|Python|... */
	/* hsize is a constant defined at load time, MT safe */
   struct progstate *parent;
	/* parent is a constant defined at load time, MT safe */
   struct progstate *next;
	/* next is a link list, seldom used, needs mutex */
   struct descrip parentdesc;		/* implicit "&parent" */
	/* parentdesc is a constant defined at load time, MT safe */
   struct descrip eventmask;		/* implicit "&eventmask" */
	/* eventmask is read-only (to me), MT safe */
   struct descrip eventcount;		/* implicit "&eventcount" */
   struct descrip valuemask;
   struct descrip eventcode;		/* &eventcode */
   struct descrip eventval;		/* &eventval */
   struct descrip eventsource;		/* &eventsource */
   dptr Glbl_argp;			/* global argp */

   /* Systems don't have more than, oh, about 50 signals, eh?
    * Currently in the system there is 40 of them            */
   struct descrip Handlers[41];
   int Inited;
   int signal;
   /*
    * trapped variable keywords' values
    */
   struct descrip Kywd_err;
   struct descrip Kywd_pos;
   struct descrip ksub;
   struct descrip Kywd_prog;
   struct descrip Kywd_ran;
   struct descrip Kywd_trc;
   struct b_coexpr *Mainhead;
   char *Code;
   char *Ecode;
   word *Records;
   int *Ftabp;
   #ifdef FieldTableCompression
      short Ftabwidth, Foffwidth;
      unsigned char *Ftabcp, *Focp;
      short *Ftabsp, *Fosp;
      int *Fo;
      char *Bm;
   #endif				/* FieldTableCompression */
   dptr Fnames, Efnames;
   dptr Globals, Eglobals;
   dptr Gnames, Egnames;
   dptr Statics, Estatics;
   int NGlobals, NStatics;
   char *Strcons;
   struct ipc_fname *Filenms, *Efilenms;
   struct ipc_line *Ilines, *Elines;
   struct ipc_line * Current_line_ptr;

   #ifdef PosixFns
      struct descrip AmperErrno;
   #endif					/* PosixFns */

   #ifdef Graphics
      struct descrip AmperX, AmperY, AmperRow, AmperCol;/* &x, &y, &row, &col */
      struct descrip AmperInterval;			/* &interval */
      struct descrip LastEventWin;			/* last Event() win */
      int LastEvFWidth;
      int LastEvLeading;
      int LastEvAscent;
      uword PrevTimeStamp;				/* previous timestamp */
      uword Xmod_Control, Xmod_Shift, Xmod_Meta;	/* control,shift,meta */
      struct descrip Kywd_xwin[2];			/* &window + ... */

   #ifdef Graphics3D
      struct descrip AmperPick;				/* &pick */
   #endif				/* Graphics3D */
   #endif				/* Graphics */
   
   word Line_num, Column, Lastline, Lastcol;

   word Coexp_ser;			/* this program's serial numbers */
   word List_ser;
#ifdef PatternType   
   word Pat_ser;
#endif					/* PatternType */
   word Set_ser;
   word Table_ser;

   word Kywd_time_elsewhere;		/* &time spent in other programs */
   word Kywd_time_out;			/* &time at last program switch out */

   uword stringtotal;			/* cumulative total allocation */
   uword blocktotal;			/* cumulative total allocation */
   word colltot;			/* total number of collections */
   word collstat;			/* number of static collect requests */
   word collstr;			/* number of string collect requests */
   word collblk;			/* number of block collect requests */
   struct region *stringregion;
   struct region *blockregion;

   word Lastop;

   dptr Xargp;
   word Xnargs;
   struct descrip Value_tmp;

   struct descrip K_current;
   int K_errornumber;
   int K_level;
   char *K_errortext;
   struct descrip K_errorvalue;
   int Have_errval;
   int T_errornumber;
   int T_have_val;
   struct descrip T_errorvalue;

   struct descrip K_main;
   struct b_file K_errout;
   struct b_file K_input;
   struct b_file K_output;

   dptr Clintsrargp;

   /*
    * Function Instrumentation Fields.
    */
#ifdef Arrays   
   int (*Cprealarray)(dptr, dptr, word, word);
   int (*Cpintarray)(dptr, dptr, word, word);
#endif					/* Arrays */
   int (*Cplist)(dptr, dptr, word, word);
   int (*Cpset)(dptr, dptr, word);
   int (*Cptable)(dptr, dptr, word);
   void (*EVstralc)(word);
   int (*Interp)(int,dptr);
   int (*Cnvcset)(dptr,dptr);
   int (*Cnvint)(dptr,dptr);
   int (*Cnvreal)(dptr,dptr);
   int (*Cnvstr)(dptr,dptr);
   int (*Cnvtcset)(struct b_cset *,dptr,dptr);
   int (*Cnvtstr)(char *,dptr,dptr);
   void (*Deref)(dptr,dptr);
   struct b_bignum * (*Alcbignum)(word);
   struct b_cset * (*Alccset)();
   struct b_file * (*Alcfile)(FILE*,int,dptr);
   union block * (*Alchash)(int);
   struct b_slots * (*Alcsegment)(word);
#ifdef PatternType
   struct b_pattern * (*Alcpattern)(word);
   struct b_pelem * (*Alcpelem)(word);
#endif					/* PatternType */
   struct b_list *(*Alclist_raw)(uword,uword);
   struct b_list *(*Alclist)(uword,uword);
   struct b_lelem *(*Alclstb)(uword,uword,uword);
   struct b_real *(*Alcreal)(double);
   struct b_record *(*Alcrecd)(int, union block *);
   struct b_refresh *(*Alcrefresh)(word *, int, int);
   struct b_selem *(*Alcselem)(dptr, uword);
   char *(*Alcstr)(char *, word);
   struct b_tvsubs *(*Alcsubs)(word, word, dptr);
   struct b_telem *(*Alctelem)(void);
   struct b_tvtbl *(*Alctvtbl)(dptr, dptr, uword);
   struct b_tvmonitored *(*Alctvmonitored) (dptr);
   void (*Deallocate)(union block *);
   char * (*Reserve)(int, word);
   };

#endif					/* MultiThread */

/*
 * Frame markers
 */
struct ef_marker {		/* expression frame marker */
   inst ef_failure;		/*   failure ipc */
   struct ef_marker *ef_efp;	/*   efp */
   struct gf_marker *ef_gfp;	/*   gfp */
   word ef_ilevel;		/*   ilevel */
   };

struct pf_marker {		/* procedure frame marker */
   word pf_nargs;		/*   number of arguments */
   struct pf_marker *pf_pfp;	/*   saved pfp */
   struct ef_marker *pf_efp;	/*   saved efp */
   struct gf_marker *pf_gfp;	/*   saved gfp */
   dptr pf_argp;		/*   saved argp */
   inst pf_ipc;			/*   saved ipc */
   word pf_ilevel;		/*   saved ilevel */
   dptr pf_scan;		/*   saved scanning environment */
#ifdef PatternType
    struct b_table *pattern_cache; /* used to cache the variable references used in a pattern*/
#endif

   struct descrip pf_locals[1];	/*   descriptors for locals */
   };

struct gf_marker {		/* generator frame marker */
   word gf_gentype;		/*   type */
   struct ef_marker *gf_efp;	/*   efp */
   struct gf_marker *gf_gfp;	/*   gfp */
   inst gf_ipc;			/*   ipc */
   struct pf_marker *gf_pfp;	/*   pfp */
   dptr gf_argp;		/*   argp */
   };

/*
 * Generator frame marker dummy -- used only for sizing "small"
 *  generator frames where procedure information need not be saved.
 *  The first five members here *must* be identical to those for
 *  gf_marker.
 */
struct gf_smallmarker {		/* generator frame marker */
   word gf_gentype;		/*   type */
   struct ef_marker *gf_efp;	/*   efp */
   struct gf_marker *gf_gfp;	/*   gfp */
   inst gf_ipc;			/*   ipc */
   };

/*
 * b_iproc blocks are used to statically initialize information about
 *  functions.	They are identical to b_proc blocks except for
 *  the pname field which is a sdescrip (simple/string descriptor) instead
 *  of a descrip.  This is done because unions cannot be initialized.
 */
	
struct b_iproc {		/* procedure block */
   word ip_title;		/*   T_Proc */
   word ip_blksize;		/*   size of block */
   int (*ip_entryp)();		/*   entry point (code) */
   word ip_nparam;		/*   number of parameters */
   word ip_ndynam;		/*   number of dynamic locals */
   word ip_nstatic;		/*   number of static locals */
   word ip_fstatic;		/*   index (in global table) of first static */

   struct sdescrip ip_pname;	/*   procedure name (string qualifier) */
   struct descrip ip_lnames[1];	/*   list of local names (qualifiers) */
   };

struct b_coexpr {		/* co-expression stack block */
   word title;			/*   T_Coexpr */
   word size;			/*   number of results produced */
   word id;			/*   identification number */
#ifdef Concurrent
   word status;			/*   status (sync vs. async, etc) */
   pthread_mutex_t smute, rmute;/*   control access to send/receive queues */
   union block *squeue, *rqueue;/*   pending send/receive queues */
#endif					/* Concurrent */
#ifdef EventMon
   word actv_count;             /*   number of times activated using EvGet() */
#endif				/* EventMon */
   struct b_coexpr *nextstk;	/*   pointer to next allocated stack */
   struct pf_marker *es_pfp;	/*   current pfp */
   struct ef_marker *es_efp;	/*   efp */
   struct gf_marker *es_gfp;	/*   gfp */
   struct tend_desc *es_tend;	/*   current tended pointer */
   dptr es_argp;		/*   argp */
   inst es_ipc;			/*   ipc */
   inst es_oldipc;              /*   oldipc */
   word es_ilevel;		/*   interpreter level */
   word *es_sp;			/*   sp */
   dptr tvalloc;		/*   where to place transmitted value */
   struct descrip freshblk;	/*   refresh block pointer */
   struct astkblk *es_actstk;	/*   pointer to activation stack structure */

   word cstate[CStateSize];	/*   C state information */

   #ifdef MultiThread
      struct progstate *program;
   #endif				/* MultiThread */
   };

struct b_refresh {		/* co-expression block */
   word title;			/*   T_Refresh */
   word blksize;		/*   size of block */
   word *ep;			/*   entry point */
   word numlocals;		/*   number of locals */
   struct pf_marker pfmkr;	/*   marker for enclosing procedure */
   struct descrip elems[1];	/*   arguments and locals, including Arg0 */
   };

#endif					/* COMPILER */

#ifdef PthreadCoswitch
/* from the Icon pthreads-based co-expression implementation. */
typedef struct context {
   pthread_t thread;	/* thread ID (thread handle) */
   sem_t sema;		/* synchronization semaphore (if unnamed) */
   sem_t *semp;		/* pointer to semaphore */
   int alive;		/* set zero when thread is to die */
   } context;
#endif					/* PthreadCoswitch */

union block {			/* general block */
   struct b_real Real;
   struct b_cset Cset;
   struct b_file File;
   struct b_proc Proc;
   struct b_record Record;
   struct b_list List;
   struct b_lelem Lelem;
   struct b_set Set;
   struct b_selem Selem;
   struct b_table Table;
   struct b_telem Telem;
   struct b_tvsubs Tvsubs;
   struct b_tvtbl Tvtbl;
#ifdef EventMon
   struct b_tvmonitored Tvmonitored;
#endif					/* EventMon */
   struct b_refresh Refresh;
   struct b_coexpr Coexpr;
   struct b_external External;
   struct b_slots Slots;

#ifdef PatternType
   struct b_pattern Pattern;
   struct b_pelem Pelem;
#endif					/* PatternType */
#ifdef LargeInts
   struct b_bignum Lrgint;
#endif				/* LargeInts */
#ifdef Arrays
   struct b_intarray Intarray;
   struct b_realarray Realarray;
#endif					/* Arrays */
   };

#ifdef PseudoPty
struct ptstruct {
#if NT
   HANDLE master_read, master_write;
   HANDLE slave_pid;
#else					/* WIN32 */
   int master_fd, slave_fd;		/* master, slave pty file descriptor */
   pid_t slave_pid;			/* process id of slave  */
#endif					/* WIN32 */
     
   char slave_filename[256];/* pty slave filename associated with master pty */
   char slave_command[256]; /* name of executable associated with slave */
};
#endif					/* PseudoPty */
