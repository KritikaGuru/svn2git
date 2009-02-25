#if !COMPILER
/*
 * File: imain.r
 * Interpreter main program, argument handling, and such.
 * Contents: main, icon_call, icon_setup, resolve, xmfree
 */

#include "../h/version.h"
#include "../h/header.h"
#include "../h/opdefs.h"

#if SCCX_MX
/*
 * The setsize program will replace "frog" with the file size of
 * iconx.exe.  The file size is used to scan to the end of the file
 * to see if a .icx file has been concatenated to the end.
 */
setint_t    sizevar = {'f','r','o','g'};
int  thisIsIconx;
char settingsname[260];

/* This sets the stack size so it runs in a Windows DOS box */
unsigned _stack = 100000;

#endif  /* SCCX_MX */

/*
 * Prototypes.
 */
static	void	env_err	(char *msg,char *name,char *val);
void	icon_setup	(int argc, char **argv, int *ip);

#ifdef MacGraph
void MacMain (int argc, char **argv);
void ToolBoxInit (void);
void MenuBarInit (void);
void MouseInfoInit (void);
int GetArgs (char **argv);
#endif					/* MacGraph */

/*
 * The following code is operating-system dependent [@imain.01].  Declarations
 *   that are system-dependent.
 */

#if PORT
   /* probably needs something more */
Deliberate Syntax Error
#endif					/* PORT */

#if AMIGA && __SASC
extern int _WBargc;     /* These are filled in by auto-initialization */
extern char **_WBargv;  /* code in rlocal.r                           */
char __stdiowin[] = "CON:10/40/640/200/IconX Console Window";
   /* These override environment variables if set from ToolTypes. */
extern uword WBstrsize;
extern uword WBblksize;
extern uword WBmstksize;
#endif					/* AMIGA && __SASC */

#if MACINTOSH
#if MPW
int NoOptions = 0;
#endif					/* MPW */
#endif					/* MACINTOSH */

#if ARM || MSDOS || MVS || VM || OS2 || UNIX || VMS
   /* nothing needed */
#endif					/* ARM || ... */

/*
 * End of operating-system specific code.
 */

extern int set_up;

/*
 * A number of important variables follow.
 */

#ifndef MultiThread
int n_globals = 0;			/* number of globals */
int n_statics = 0;			/* number of statics */
#endif					/* MultiThread */

/*
 * Initial icode sequence. This is used to invoke the main procedure with one
 *  argument.  If main returns, the Op_Quit is executed.
 */
word istart[4];
int mterm = Op_Quit;



#if NT
/*
 * Convert an argv array to a command line string.  argv[0] is searched
 * on the PATH, since system() or its relatives do not reliably do that.
 */
char *ArgvToCmdline(char **argv)
{
   int i, q, len = 0;
   char *mytmp, *tmp2;
   mytmp = malloc(1024);
   if ((argv == NULL) || (argv[0] == NULL)) return NULL;
   for (i=0; argv[i]; i++) len += strlen(argv[i]) + 1;
   if (strcmp(".exe", argv[0]+(strlen(argv[0])-4))) {
      tmp2 = malloc(strlen(argv[0])+5);
      strcpy(tmp2, argv[0]);
      strcat(tmp2, ".exe");
      }
   else tmp2 = strdup(argv[0]);
   mytmp[0] = '\0';
   q = pathFind(tmp2, mytmp, 2048);
   if (!q) strcpy(mytmp,argv[0]);
   else {
      char *qq = mytmp;
      while (qq=strchr(qq, '/')) *qq='\\';
      }
   len += strlen(mytmp);
   if (len > 1023) mytmp = realloc(mytmp, len+1);

   i = 1;
   while (argv[i] != NULL) {
      strcat(mytmp, " ");
      strcat(mytmp, argv[i++]);
   }
   return mytmp;
}
#endif					/* NT */

#ifdef MSWindows
#ifdef ConsoleWindow
void detectRedirection()
{
   struct stat sb;
   /*
    * Look at the standard file handles and attempt to detect
    * redirection.
    */
   if (fstat(stdin->_file, &sb) == 0) {
      if (sb.st_mode & S_IFCHR) {		/* stdin is a device */
	 }
      if (sb.st_mode & S_IFREG) {		/* stdin is a regular file */
	 }
      /* stdin is of size sb.st_size */
      if (sb.st_size > 0) {
         ConsoleFlags |= StdInRedirect;
	 }
      }
   else {					/* unable to identify stdin */
      }

   if (fstat(stdout->_file, &sb) == 0) {
      if (sb.st_mode & S_IFCHR) {		/* stdout is a device */
	 }
      if (sb.st_mode & S_IFREG) {		/* stdout is a regular file */
	 }
      /* stdout is of size sb.st_size */
      if (sb.st_size == 0)
         ConsoleFlags |= StdOutRedirect;
      }
   else {					/* unable to identify stdout */
     }
}
#endif					/* ConsoleWindow */

char *lognam;
char tmplognam[128];

void MSStartup(HINSTANCE hInstance, HINSTANCE hPrevInstance)
   {
   WNDCLASS wc;
#ifdef ConsoleWindow
   char *tnam;
   extern FILE *flog;

   /*
    * Select log file name.  Might make this a command-line option.
    * Default to "WICON.LOG".  The log file is used by IDE programs to
    * report translation errors and jump to the offending source code line.
    */
   if ((lognam = getenv("WICONLOG")) == NULL) {
      if (((lognam = getenv("TEMP")) != NULL) &&
	  (lognam = malloc(strlen(lognam) + 13)) != NULL) {
	 strcpy(lognam, getenv("TEMP"));
	 strcat(lognam, "\\");
	 strcat(lognam, "winicon.log");
         }
      else
         lognam = "winicon.log";
      }
   remove(lognam);
   if (getenv("WICONLOG")!=NULL)
      lognam = strdup(lognam);
   if (getenv("TEMP") != NULL) {
      tnam = _tempnam(getenv("TEMP"), "wx");
      }
   else {
      tnam = _tempnam("C:\\TEMP", "wx");
      }
   if (tnam == NULL) {
      fprintf(stderr, "_tempnam failed, is your temp directory full?\n");
      tnam = "wx0001";
      }
   strcpy(tmplognam, tnam);
   flog = fopen(tnam, "w");
   free(tnam);

   if (flog == NULL) {
      syserr("unable to open logfile");
      }
#endif					/* ConsoleWindow */
   if (!hPrevInstance) {
#if NT
      wc.style = CS_HREDRAW | CS_VREDRAW;
#ifdef Graphics3D
      wc.style |= CS_OWNDC;
#endif
#else					/* NT */
      wc.style = 0;
#endif					/* NT */
      wc.lpfnWndProc = WndProc;
      wc.cbClsExtra = 0;
      wc.cbWndExtra = 0;
      wc.hInstance  = hInstance;
      wc.hIcon      = NULL;
      wc.hCursor    = NULL;
      wc.hbrBackground = GetStockObject(WHITE_BRUSH);
      wc.lpszMenuName = NULL;
      wc.lpszClassName = "iconx";
      RegisterClass(&wc);
      }
   }

void iconx(int argc, char **argv);

jmp_buf mark_sj;

int_PASCAL WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance,
                   LPSTR lpszCmdLine, int nCmdShow)
   {
   int argc;
   char **argv;

   mswinInstance = hInstance;
   ncmdShow = nCmdShow;

   argc = CmdParamToArgv(GetCommandLine(), &argv, 1);
   MSStartup(hInstance, hPrevInstance);
   if (setjmp(mark_sj) == 0)
      iconx(argc,argv);
   while (--argc>=0)
      free(argv[argc]);
   free(argv);
   wfreersc();
   xmfree();
#ifdef NTGCC
   _exit(0);
#endif					/* NTGCC */
   return 0;
}
#define main iconx
#else
#if WildCards
void ExpandArgv(int *argcp, char ***avp)
{
   int argc = *argcp;
   char **argv = *avp;
   char **newargv;
   FINDDATA_T fd;
   int j,newargc=0;
   for(j=0; j < argc; j++) {
      newargc++;
      if (strchr(argv[j], '*') || strchr(argv[j], '?')) {
         if (FINDFIRST(argv[j], &fd)) {
            while (FINDNEXT(&fd)) newargc++;
	    FINDCLOSE(&fd);
            }
         }
      }
   if (newargc == argc) return;

   if ((newargv = malloc((newargc+1) * sizeof (char *))) == NULL) return;
   newargc = 0;
   for(j=0; j < argc; j++) {
      if (strchr(argv[j], '*') || strchr(argv[j], '?')) {
         if (FINDFIRST(argv[j], &fd)) {
            char dir[MaxPath];
            int end;
            strcpy(dir, argv[j]);
            do {
               end = strlen(dir)-1;
               while(end >= 0 && !strchr("\\/:", dir[end])) {
                  dir[end] = '\0';
                  end--;
                  }
               strcat(dir, FILENAME(&fd));
               newargv[newargc++] = strdup(dir);
               newargv[newargc] = NULL;
               } while (FINDNEXT(&fd));
            FINDCLOSE(&fd);
            }
         else {
            newargv[newargc++] = strdup(argv[j]);
            }
         }
      else {
         newargv[newargc++] = strdup(argv[j]);
         }
      }
   *avp = newargv;
   *argcp = newargc;
}
#endif					/* WildCards */
#endif					/* MSWindows */

#if OS2
int stubexe;
void os2main(int stubflag, int argc, char**argv); /* Prototype OS2main */
void os2main(stubflag, argc, argv)
int stubflag;
#else					/* OS2 */
#ifdef MacGraph
MouseInfoType gMouseInfo;
PaletteHandle gPal;
long gNumColors;
Boolean gDone;
char *cmlArgs;
StringHandle textHandle;

void MacMain (int argc, char **argv)
#else					/* MacGraph */
#ifdef DLLICONX
#passthru void __declspec(dllexport) iconx_entry(int argc, char **argv)
#else					/* DLLICONX */
#ifdef INTMAIN
int main(int argc, char **argv)
#else
void main(int argc, char **argv)
#endif					/* INTMAIN */
#endif					/* DLLICONX */
#endif					/* MacGraph */
#endif					/* OS2 */
   {
   int i, slen;

#if WildCards
#ifndef MSWindows
   ExpandArgv(&argc, &argv);
#endif
#endif					/* WildCards */

#if SCCX_MX
    int     ctrlbrk;
    FILE*   selfPtr;
    int     new_argc;
    char    **new_argv;
    struct FIND *p;

    strcpy(settingsname, argv[0]);
    selfPtr = fopen( settingsname, "rb");
    fseek( selfPtr, 0L, SEEK_END);
    if( ftell( selfPtr) > sizevar.value)
    {
        ++argc;
        --argv;
        thisIsIconx = 1;
    }
    else
        thisIsIconx = 0;

    fclose( selfPtr);

    /*
     *  Expand wildcard file names:
     *      Replace command line arguments with the file names that match
     *      wildcard specifications.
     *      Leave arguments that don't match file names as they are so the
     *      icon program can deal with them.
     */
    new_argc = 1;
    new_argv = malloc( new_argc * sizeof(char *));
    new_argv[0] = malloc( (strlen(settingsname)+1) * sizeof(char));
    memcpy( new_argv[0], settingsname, strlen(settingsname)+1);
    for( i=1; i<argc; ++i)
    {
        if( (p = findfirst( argv[i], 0)) != NULL)
        {
            while( p)
            {
                new_argc++;
                new_argv = realloc( new_argv, new_argc * sizeof(char *));
                new_argv[new_argc-1] = malloc( (strlen(p->name)+1) * sizeof(char));
                memcpy( new_argv[new_argc-1], p->name, strlen(p->name)+1);
                p = findnext();
            }
        }
        else
        {
            new_argc++;
            new_argv = realloc( new_argv, new_argc * sizeof(char *));
            new_argv[new_argc-1] = malloc( (strlen(argv[i])+1) * sizeof(char));
            memcpy( new_argv[new_argc-1], argv[i], strlen(argv[i])+1);
        }
    }

    if( new_argc == 1)
    {
        /* Add a null string to accommodate code in icon_setup() */
        new_argv = realloc( new_argv, new_argc+1 * sizeof(char *));
        new_argv[new_argc] = malloc( sizeof(char));
        strcpy( new_argv[new_argc], "");
    }

    argv = new_argv;
    argc = new_argc;

#if 0
    if( argc < 2)
    {
    syntax error!
    The Symantec license agreement requires you to include a copyright
    notice in your program.  This is a good place for it.

        fprintf( stderr,
            "\nCopyright (c) 1996, Your Name, Your City, Your State.\n");
        exit(1);
    }
#endif
    ctrlbrk = dos_get_ctrl_break();
    dos_set_ctrl_break(1);   /* Ensure proper Ctrl-C operation */
#endif  /* SCCX_MX */

#if SASC
   quiet(1);                    /* suppress C library diagnostics */
#endif					/* SASC */

#ifdef MultiThread
   /*
    * Look for MultiThread programming environment in which to execute
    * this program, specified by MTENV environment variable.
    */
   {
   char *p = NULL;
   char **new_argv = NULL;
   int i=0, j = 1, k = 1;
   if ((p = getenv("MTENV")) != NULL) {
      for(i=0;p[i];i++)
	 if (p[i] == ' ')
	    j++;
      new_argv = (char **)malloc((argc + j) * sizeof(char *));
      new_argv[0] = argv[0];
      for (i=0; p[i]; ) {
	 new_argv[k++] = p+i;
	 while (p[i] && (p[i] != ' '))
	    i++;
	 if (p[i] == ' ')
	    p[i++] = '\0';
	 }
      for(i=1;i<argc;i++)
	 new_argv[k++] = argv[i];
      argc += j;
      argv = new_argv;
      }
   }
#endif					/* MultiThread */

   ipc.opnd = NULL;

#if UNIX
   /*
    *  Append to FPATH the bin directory from which iconx was executed.
    */
   {
      char *p = getenv("FPATH");
      char *q = relfile(argv[0], "/..");
      char *buf = malloc((p?strlen(p):1) + (q?strlen(q):1) + 8);
      if (buf) {
	 sprintf(buf, "FPATH=%s %s", (p ? p : "."), (q ? q : "."));
	 putenv(buf);
	 free(buf);
	 }
      }
#endif

   /*
    * Setup Icon interface.  It's done this way to avoid duplication
    *  of code, since the same thing has to be done if calling Icon
    *  is enabled.
    */

#ifdef CRAY
   argv[0] = "iconx";
#endif					/* CRAY */

#if OS2
   if (stubflag) {  /* Invoked as a direct executable */
      stubexe = 1;
      icon_init(argv[0],&argc, argv);
      argc += 2;
      argv -= 2;
      }
   else {
      stubexe = 0;
      icon_setup(argc, argv, &i);
      if (i < 0) {
	 argc++;
	 argv--;
	 i++;
	 }
      while (i--) {			    /* skip option arguments */
	 argc--;
	 argv++;
	 }

      if (argc <= 1)
	 error(NULL, "An icode file was not specified.\nExecution cannot proceed.");
      /*
       * Call icon_init with the name of the icode file to execute.	    [[I?]]
       */

      icon_init(argv[1], &argc, argv);
      }
#else					/* OS2 */

#if AMIGA && __SASC
   if (argc == 0) {         /* argc == 0 flags a Workbench startup */
      struct DiskObject *dob;
      char *filename;
      char *errorname;
      char *size;
      long newout;
      long newerr;

      if(dob = GetDiskObject(_WBargv[1])) {
         if(dob->do_ToolTypes){
         /* First get redirects from ToolTypes.
            With a Workbench startup, stdin points to the console
            window opened in MODE_NEWFILE, while stdout and stderr
            share a pointer to the console window opened with
            MODE_OLDFILE.  The close flag is on stderr. */

            errorname = FindToolType(dob->do_ToolTypes,"STDERR");

            if (errorname != NULL && strcmp(errorname, "-") == 0) {
               if (filename = FindToolType(dob->do_ToolTypes,"STDOUT")) {
                  if ( newout = Open(filename, MODE_NEWFILE) ) {
                     Close(__ufbs[1].ufbfh);
                     __ufbs[1].ufbfh = newout;
                     __ufbs[2].ufbfh = newout;
                     }
                  }
               }

            else {
               if (errorname != NULL) {
                  if ( newerr = Open(errorname, MODE_NEWFILE) ) {
                     __ufbs[2].ufbfh = newerr;
                     __ufbs[1].ufbflg |= UFB_CLO;
                     }
                  }
 
               if (filename = FindToolType(dob->do_ToolTypes,"STDOUT")) {
                  if (newout = Open(filename, MODE_NEWFILE) ) {
                     if (newerr) Close(__ufbs[1].ufbfh);
                     __ufbs[1].ufbfh = newout;
                     __ufbs[1].ufbflg |= UFB_CLO;
                     }
                  }
               }

            if (filename = FindToolType(dob->do_ToolTypes,"STDIN"))
               freopen(filename, "r", stdin);

         /* Set sizes from Tooltypes. */
            if (size = FindToolType(dob->do_ToolTypes,"STRSIZE"))
               WBstrsize = strtoul(size,NULL,10);

            if (size = FindToolType(dob->do_ToolTypes,"BLKSIZE"))
               WBblksize = strtoul(size,NULL,10);

            if (size = FindToolType(dob->do_ToolTypes,"MSTKSIZE"))
               WBmstksize = strtoul(size,NULL,10);

            }
         FreeDiskObject(dob);
         }

      argc = _WBargc;
      argv = _WBargv;
      }
#endif					/* AMIGA && __SASC */

   icon_setup(argc, argv, &i);

   if (i < 0) {
      argc++;
      argv--;
      i++;
      }

   while (i--) {			/* skip option arguments */
      argc--;
      argv++;
      }

   if (argc <= 1) {
      error(NULL, "no icode file specified");
      }

   /*
    * Call icon_init with the name of the icode file to execute.	[[I?]]
    */
   icon_init(argv[1], &argc, argv);

#endif					/* OS2 */

#ifdef Messaging
   errno = 0;
#endif					/* Messaging */


#ifdef NativeObjects
   /*
    * The following block of code calls <classname>initialize() methods of
    * every class in the program. initialize methods create an instance of the
    * methods vector record for the class. In the original implementation of
    * Unicon, methods vector instance is created when first instance of that
    * class is created. This implementation creates methods vectors for all
    * the classes in the program before main() begins its execution.
    *
    * This is achieved by calling initialize() methods in icode from this
    * program. Following block of code aligns icode instructions to call
    * initialize() method and descriptor for these methods are pushed
    * on stack. When instructions and stack is setup, interp() is called
    * just like it is called for execution of main().
    *
    * This program also implements the modified Unicon object structure.
    * Object instances no longer carry a pointer to the methods vector.
    * Instead, the record constructor block now holds pointer to it.
    *
    * When initialize() method is called, it assigns the newly created method
    * vector pointer to <classname>__oprec global variable. This new value is
    * also copied into __m field of the record constructor block. This field
    * is reserved.
    */

{
    unsigned *temp_stackend=stackend, *temp_sp=sp;
    inst temp_ipc=ipc;
    struct gf_marker *temp_gfp=gfp;
    struct ef_marker *temp_efp=efp;
    struct pf_marker *temp_pfp=pfp;
    int temp_ilevel=ilevel;
    dptr temp_glbl_argp = glbl_argp;
    int temp_set_up=set_up;

    int numberof_globals,i,j,k;
    char classname[500]={0}, *begin=0,*position=0;
    register dptr dp=0;
    char *initialize="initialize";
    int initialize_length=strlen(initialize);

    numberof_globals = egnames - gnames;

    for(i=0;i < numberof_globals;++i) {
       char *sptr;

       if ((globals[i].dword == D_Proc) &&
           (sptr=globals[i].vword.bptr->proc.pname.vword.sptr) &&
           (position=(char *)memmem(sptr,strlen(sptr)+1,initialize,initialize_length+1))) {

          begin=sptr;
          k=0;
          while(begin != position) {
             classname[k]=*begin;
             k++;
             begin++;
          }
          classname[k]=0;

          stackend = stack + mstksize/WordSize;
          sp = stack + Wsizeof(struct b_coexpr);

          ipc.opnd = istart;
          *ipc.op++ = Op_Noop;
          *ipc.op++ = Op_Invoke;
          *ipc.opnd++ = 0;
          *ipc.op = Op_Quit;
          ipc.opnd = istart;

          gfp = 0;

          efp = (struct ef_marker *)(sp);
          efp->ef_failure.op = &mterm;
          efp->ef_gfp = 0;
          efp->ef_efp = 0;
          efp->ef_ilevel = 1;
          sp += Wsizeof(*efp) - 1;

          pfp = 0;
          ilevel = 0;

          glbl_argp = 0;
          set_up = 1;

          PushDesc(globals[i]);
          interp(0,(dptr)NULL);

	  /*
	   * Now we have <classname>__oprec pointing at method vector.
	   * Copy it in  __m field of record constructor block
	   */

	  strcat(classname,"__state");
	  for(j=0; j < numberof_globals; ++j) {
	     union block *bptr=globals[j].vword.bptr;
	     if((globals[j].dword == D_Proc) && (-3 == bptr->proc.ndynam) &&
		(0==strcmp(classname,bptr->proc.pname.vword.sptr))) {
		*strstr(classname,"__state")=0;
		strcat(classname,"__oprec");

		for(k=0;k < numberof_globals;++k) {
		   if(strcmp(classname,gnames[k].vword.sptr)==0) {
		      bptr->proc.lnames[bptr->proc.nparam]=globals[k];
		      j = numberof_globals; /* exit outer for-loop */
		      break;
		      }
		   }
		}
             }
	  }
       }

    stackend=temp_stackend;
    sp=temp_sp;
    ipc=temp_ipc;
    gfp=temp_gfp;
    efp=temp_efp;
    pfp=temp_pfp;
    ilevel=temp_ilevel;
    glbl_argp = temp_glbl_argp;
    set_up=temp_set_up;
    }
#endif					/* NativeObjects */


   /*
    *  Point sp at word after b_coexpr block for &main, point ipc at initial
    *	icode segment, and clear the gfp.
    */

   stackend = stack + mstksize/WordSize;
   sp = stack + Wsizeof(struct b_coexpr);

   ipc.opnd = istart;
   *ipc.op++ = Op_Noop;  /* aligns Invoke's operand */	/*	[[I?]] */
   *ipc.op++ = Op_Invoke;				/*	[[I?]] */
   *ipc.opnd++ = 1;
   *ipc.op = Op_Quit;
   ipc.opnd = istart;

   gfp = 0;

   /*
    * Set up expression frame marker to contain execution of the
    *  main procedure.  If failure occurs in this context, control
    *  is transferred to mterm, the address of an Op_Quit.
    */
   efp = (struct ef_marker *)(sp);
   efp->ef_failure.op = &mterm;
   efp->ef_gfp = 0;
   efp->ef_efp = 0;
   efp->ef_ilevel = 1;
   sp += Wsizeof(*efp) - 1;

   pfp = 0;
   ilevel = 0;

/*
 * We have already loaded the
 * icode and initialized things, so it's time to just push main(),
 * build an Icon list for the rest of the arguments, and called
 * interp on a "invoke 1" bytecode.
 */
   /*
    * The first global variable holds the value of "main".  If it
    *  is not of type procedure, this is noted as run-time error 117.
    *  Otherwise, this value is pushed on the stack.
    */
   if (globals[0].dword != D_Proc)
      fatalerr(117, NULL);
   PushDesc(globals[0]);
   PushNull;
   glbl_argp = (dptr)(sp - 1);

   /*
    * If main() has a parameter, it is to be invoked with one argument, a list
    *  of the command line arguments.  The command line arguments are pushed
    *  on the stack as a series of descriptors and Ollist is called to create
    *  the list.  The null descriptor first pushed serves as Arg0 for
    *  Ollist and receives the result of the computation.
    */
   if (((struct b_proc *)BlkLoc(globals[0]))->nparam > 0) {
      for (i = 2; i < argc; i++) {
         char *tmp;
         slen = strlen(argv[i]);
         PushVal(slen);
         Protect(tmp=alcstr(argv[i],(word)slen), fatalerr(0,NULL));
         PushAVal(tmp);
         }

      Ollist(argc - 2, glbl_argp);
      }


   sp = (word *)glbl_argp + 1;
   glbl_argp = 0;

   set_up = 1;			/* post fact that iconx is initialized */

   /*
    * Start things rolling by calling interp.  This call to interp
    *  returns only if an Op_Quit is executed.	If this happens,
    *  c_exit() is called to wrap things up.
    */



#ifdef CoProcesses
   codisp();    /* start up co-expr dispatcher, which will call interp */
#else					/* CoProcesses */
   interp(0,(dptr)NULL);                        /*      [[I?]] */
#endif					/* CoProcesses */


#if SCCX_MX
    dos_set_ctrl_break(ctrlbrk);   /* Restore original Ctrl-C operation */
#endif

   c_exit(EXIT_SUCCESS);
#ifdef INTMAIN
   return 0;
#endif
}

/*
 * icon_setup - handle interpreter command line options.
 */
void icon_setup(argc,argv,ip)
int argc;
char **argv;
int *ip;
   {

#ifdef TallyOpt
   extern int tallyopt;
#endif					/* TallyOpt */

   *ip = 0;			/* number of arguments processed */

#ifdef ExecImages
   if (dumped) {
      /*
       * This is a restart of a dumped interpreter.  Normally, argv[0] is
       *  iconx, argv[1] is the icode file, and argv[2:(argc-1)] are the
       *  arguments to pass as a list to main().  For a dumped interpreter
       *  however, argv[0] is the executable binary, and the first argument
       *  for main() is argv[1].  The simplest way to handle this is to
       *  back up argv to point at argv[-1] and increment argc, giving the
       *  illusion of an additional argument at the head of the list.  Note
       *  that this argument is never referenced.
       */
      argv--;
      argc++;
      (*ip)--;
      }
#endif					/* ExecImages */

   /*
    * if we didn't start with *iconx[.exe], backup one
    * so that our icode filename is argv[1].
    */
   {
   int len = 0;
   char *tmp = strdup(argv[0]), *t2 = tmp;
   if (tmp == NULL) {
      syserr("memory allocation failure in startup code");
      }
   while (*t2) {
      *t2 = tolower(*t2);
      t2++;
      }
   len = t2 - tmp;

   if (len > 4 && !strcmp(tmp+len-4, ".exe")) {len -= 4; tmp[len] = '\0'; }

   /*
    * if argv[0] is not a reference to our interpreter, take it as the
    * name of the icode file, and back up for it.
    */
   if (!(len >= 5 && !strcmp(tmp+len-4, "conx"))) {
      argv--;
      argc++;
      (*ip)--;
      }
   }

#ifdef MaxLevel
   maxilevel = 0;
   maxplevel = 0;
   maxsp = 0;
#endif					/* MaxLevel */

#if MACINTOSH
#if MPW
   InitCursorCtl(NULL);
   /*
    * To support the icode and iconx interpreter bundled together in
    * the same file, we might have to use this code file as the icode
    * file, too.  We do this if the command name is not 'iconx'.
    */
   {
   char *p,*q,c,fn[6];

   /*
    * Isolate the filename from the path.
    */
   q = strrchr(*argv,':');
   if (q == NULL)
       q = *argv;
   else
       ++q;
   /*
    * See if it's the real iconx -- case independent compare.
    */
   p = fn;
   if (strlen(q) == 5)
      while (c = *q++) *p++ = tolower(c);
   *p = '\0';
   if (strcmp(fn,"iconx") != 0) {
     /*
      * This technique of shifting arguments relies on the fact that
      * argv[0] is never referenced, since this will make it invalid.
      */
      --argv;
      ++argc;
      --(*ip);
      /*
       * We don't want to look for any command line options in this
       * case.  They could interfere with options for the icon
       * program.
       */
      NoOptions = 1;
      }
   }
#endif					/* MPW */
#endif                                  /* MACINTOSH */

/*
 * Handle command line options.
*/
#if MACINTOSH && MPW
   if (!NoOptions)
#endif					/* MACINTOSH && MPW */
   while ( argv[1] != 0 && *argv[1] == '-' ) {
      switch ( *(argv[1]+1) ) {

#ifdef TallyOpt
	/*
	 * Set tallying flag if -T option given
	 */
	case 'T':
	    tallyopt = 1;
	    break;
#endif					/* TallyOpt */

      /*
       * Set stderr to new file if -e option is given.
       */
	 case 'e': {
	    char *p;
	    if ( *(argv[1]+2) != '\0' )
	       p = argv[1]+2;
	    else {
	       argv++;
	       argc--;
               (*ip)++;
	       p = argv[1];
	       if ( !p )
		  error(NULL, "no file name given for redirection of &errout");
	       }
            if (!redirerr(p))
               syserr("Unable to redirect &errout\n");
	    break;
	    }
        }
	argc--;
        (*ip)++;
	argv++;
      }
   }

/*
 * resolve - perform various fix-ups on the data read from the icode
 *  file.
 */
#ifdef MultiThread
   void resolve(pstate)
   struct progstate *pstate;
#else					/* MultiThread */
   void resolve()
#endif					/* MultiThread */

   {
   register word i, j;
   register struct b_proc *pp;
   register dptr dp;

   #ifdef MultiThread
      register struct progstate *savedstate = curpstate;
      if (pstate) curpstate = pstate;
   #endif					/* MultiThread */

   /*
    * Relocate the names of the global variables.
    */
   for (dp = gnames; dp < egnames; dp++)
      StrLoc(*dp) = strcons + (uword)StrLoc(*dp);

   /*
    * Scan the global variable array for procedures and fill in appropriate
    *  addresses.
    */
   for (j = 0; j < n_globals; j++) {

      if (globals[j].dword != D_Proc)
         continue;

      /*
       * The second word of the descriptor for procedure variables tells
       *  where the procedure is.  Negative values are used for built-in
       *  procedures and positive values are used for Icon procedures.
       */
      i = IntVal(globals[j]);

      if (i < 0) {
         /*
          * globals[j] points to a built-in function; call (bi_)strprc
	  *  to look it up by name in the interpreter's table of built-in
	  *  functions.
          */
	 if((BlkLoc(globals[j])= (union block *)bi_strprc(gnames+j,0)) == NULL)
            globals[j] = nulldesc;		/* undefined, set to &null */
         }
      else {

         /*
          * globals[j] points to an Icon procedure or a record; i is an offset
          *  to location of the procedure block in the code section.  Point
          *  pp at the block and replace BlkLoc(globals[j]).
          */
         pp = (struct b_proc *)(code + i);
         BlkLoc(globals[j]) = (union block *)pp;

         /*
          * Relocate the address of the name of the procedure.
          */
         StrLoc(pp->pname) = strcons + (uword)StrLoc(pp->pname);

         if ((pp->ndynam == -2) || (pp->ndynam == -3)) {
            /*
             * This procedure is a record constructor.	Make its entry point
             *	be the entry point of Omkrec().
             */
            pp->entryp.ccode = Omkrec;

	    /*
	     * Initialize field names
	     */
            for (i = 0; i < pp->nfields; i++)
               StrLoc(pp->lnames[i]) = strcons + (uword)StrLoc(pp->lnames[i]);

	    }
         else {
            /*
             * This is an Icon procedure.  Relocate the entry point and
             *	the names of the parameters, locals, and static variables.
             */
            pp->entryp.icode = code + pp->entryp.ioff;
            for (i = 0; i < abs((int)pp->nparam)+pp->ndynam+pp->nstatic; i++)
               StrLoc(pp->lnames[i]) = strcons + (uword)StrLoc(pp->lnames[i]);
            }
         }
      }

   /*
    * Relocate the names of the fields.
    */

   for (dp = fnames; dp < efnames; dp++)
      StrLoc(*dp) = strcons + (uword)StrLoc(*dp);

#ifdef MultiThread
   curpstate = savedstate;
#endif						/* MultiThread */
   }


/*
 * Free malloc-ed memory; the main regions then co-expressions.  Note:
 *  this is only correct if all allocation is done by routines that are
 *  compatible with free() -- which may not be the case for all memory.
 */

void xmfree()
   {
   register struct b_coexpr **ep, *xep;
   register struct astkblk *abp, *xabp;

   if (mainhead == NULL) return;	/* already xmfreed */
   free((pointer)mainhead->es_actstk);	/* activation block for &main */
   mainhead->es_actstk = NULL;
   mainhead = NULL;

   free((pointer)code);			/* icode */
   code = NULL;
   free((pointer)stack);		/* interpreter stack */
   stack = NULL;
   /*
    * more is needed to free chains of heaps, also a multithread version
    * of this function may be needed someday.
    */
   if (strbase)
      free((pointer)strbase);		/* allocated string region */
   strbase = NULL;
   if (blkbase)
      free((pointer)blkbase);		/* allocated block region */
   blkbase = NULL;
#ifndef MultiThread
   if (curstring != &rootstring)
      free((pointer)curstring);		/* string region */
   curstring = NULL;
   if (curblock != &rootblock)
      free((pointer)curblock);		/* allocated block region */
   curblock = NULL;
#endif					/* MultiThread */
   if (quallist)
      free((pointer)quallist);		/* qualifier list */
   quallist = NULL;

   /*
    * The co-expression blocks are linked together through their
    *  nextstk fields, with stklist pointing to the head of the list.
    *  The list is traversed and each stack is freeing.
    */
   ep = &stklist;
   while (*ep != NULL) {
      xep = *ep;
      *ep = (*ep)->nextstk;
       /*
        * Free the astkblks.  There should always be one and it seems that
        *  it's not possible to have more than one, but nonetheless, the
        *  code provides for more than one.
        */
 	 for (abp = xep->es_actstk; abp; ) {
            xabp = abp;
            abp = abp->astk_nxt;
            free((pointer)xabp);
            }

#ifdef CoProcesses
         coswitch(BlkLoc(k_current)->coexpr.cstate, xep->cstate, -1);
                /* terminate coproc for coexpression first */
#endif					/* CoProcesses */

      free((pointer)xep);
      stklist = NULL;
      }

   }
#endif					/* !COMPILER */


#ifdef MacGraph
void MouseInfoInit (void)
{
   gMouseInfo.wasDown = false;
}

void ToolBoxInit (void)
{
   InitGraf (&qd.thePort);
   InitFonts ();
   InitWindows ();
   InitMenus ();
   TEInit ();
   InitDialogs (nil);
   InitCursor ();
}

void MenuBarInit (void)
{
   Handle         menuBar;
   MenuHandle     menu;
   OSErr          myErr;
   long           feature;

   menuBar = GetNewMBar (kMenuBar);
   SetMenuBar (menuBar);

   menu = GetMHandle (kAppleMenu);
   AddResMenu (menu, 'DRVR');

   DrawMenuBar ();
}

void EventLoop ( void )
{
   EventRecord event, *eventPtr;
   char theChar;

   gDone = false;
   while ( gDone == false )
   {
      if ( WaitNextEvent ( everyEvent, &event, kSleep, nil ) )
         DoEvent ( &event );
   }
}

void main ()
{
   atexit (EventLoop);
   ToolBoxInit ();
   MenuBarInit ();
   MouseInfoInit ();
   cmlArgs = "";

   EventLoop ();
}
#endif					/* MacGraph */
