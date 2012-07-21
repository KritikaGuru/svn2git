/*
 * File: rcoexpr.r -- co_init, co_chng
 */


/*
 * Function to call after switching stacks. If NULL, call interp().
 */
static continuation coexpr_fnc;

#ifdef Concurrent
void tlschain_add(struct threadstate *tstate, struct context *ctx);
void tlschain_remove(struct threadstate *tstate);
#endif					/* Concurrent  */

/*
 * co_init - use the contents of the refresh block to initialize the
 *  co-expression.
 */
void co_init(sblkp)
struct b_coexpr *sblkp;
{
#ifndef CoExpr
   syserr("co_init() called, but co-expressions not implemented");
#else					/* CoExpr */
   register word *newsp;
   register dptr dp, dsp;
   int frame_size;
   word stack_strt;
   int na, nl, nt, i;
   /*
    * Get pointer to refresh block.
    */
   struct b_refresh *rblkp = (struct b_refresh *)BlkLoc(sblkp->freshblk);
   CURTSTATE();

#if COMPILER
   na = rblkp->nargs;                /* number of arguments */
   nl = rblkp->nlocals;              /* number of locals */
   nt = rblkp->ntemps;               /* number of temporaries */

   /*
    * The C stack must be aligned on the correct boundary. For up-growing
    *  stacks, the C stack starts after the initial procedure frame of
    *  the co-expression block. For down-growing stacks, the C stack starts
    *  at the last word of the co-expression block.
    */
#ifdef UpStack
   frame_size = sizeof(struct p_frame) + sizeof(struct descrip) * (nl + na +
      nt - 1) + rblkp->wrk_size;
   stack_strt = (word)((char *)&sblkp->pf + frame_size + StackAlign*WordSize);
#else					/* UpStack */
   stack_strt = (word)((char *)sblkp + stksize - WordSize);
#endif					/* UpStack */
   sblkp->cstate[0] = stack_strt & ~(WordSize * StackAlign - 1);

   sblkp->es_argp = &sblkp->pf.t.d[nl + nt];   /* args follow temporaries */

#else					/* COMPILER */

   na = (rblkp->pfmkr).pf_nargs + 1; /* number of arguments */
   nl = (int)rblkp->nlocals;         /* number of locals */

   /*
    * The interpreter stack starts at word after co-expression stack block.
    *  C stack starts at end of stack region on machines with down-growing C
    *  stacks and somewhere in the middle of the region.
    *
    * The C stack is aligned on a doubleword boundary.	For up-growing
    *  stacks, the C stack starts in the middle of the stack portion
    *  of the static block.  For down-growing stacks, the C stack starts
    *  at the last word of the static block.
    */

   newsp = (word *)((char *)sblkp + sizeof(struct b_coexpr) + sizeof(struct threadstate));

#ifdef UpStack
   sblkp->cstate[0] =
      ((word)((char *)sblkp + (stksize - sizeof(*sblkp))/2)
         &~((word)WordSize*StackAlign-1));
#else					/* UpStack */
   sblkp->cstate[0] =
	((word)((char *)sblkp + stksize - WordSize)
           &~((word)WordSize*StackAlign-1));
#endif					/* UpStack */

   sblkp->es_argp = (dptr)newsp;  /* args are first thing on stack */
#ifdef StackCheck
   sblkp->es_stack = newsp;
   sblkp->es_stackend = (word *)
      ((word)((char *)sblkp + (stksize - sizeof(*sblkp))/2)
         &~((word)WordSize*StackAlign-1));
#endif					/* StackCheck */
#endif					/* COMPILER */

   /*
    * Copy arguments onto new stack.
    */
   dsp = sblkp->es_argp;
   dp = rblkp->elems;
   for (i = 1; i <=  na; i++)
      *dsp++ = *dp++;

   /*
    * Set up state variables and initialize procedure frame.
    */
#if COMPILER
   sblkp->es_pfp = &sblkp->pf;
   sblkp->es_tend = &sblkp->pf.t;
   sblkp->pf.old_pfp = NULL;
   sblkp->pf.rslt = NULL;
   sblkp->pf.succ_cont = NULL;
   sblkp->pf.t.previous = NULL;
   sblkp->pf.t.num = nl + na + nt;
   sblkp->es_actstk = NULL;
#else					/* COMPILER */
   *((struct pf_marker *)dsp) = rblkp->pfmkr;
   sblkp->es_pfp = (struct pf_marker *)dsp;
   sblkp->es_tend = NULL;
   dsp = (dptr)((word *)dsp + Vwsizeof(*pfp));
   sblkp->es_ipc.opnd = rblkp->ep;
   sblkp->es_gfp = 0;
   sblkp->es_efp = 0;
   sblkp->es_ilevel = 0;
#endif					/* COMPILER */
   sblkp->tvalloc = NULL;

   /*
    * Copy locals into the co-expression.
    */
#if COMPILER
   dsp = sblkp->pf.t.d;
#endif					/* COMPILER */
   for (i = 1; i <= nl; i++)
      *dsp++ = *dp++;

#if COMPILER
   /*
    * Initialize temporary variables.
    */
   for (i = 1; i <= nt; i++)
      *dsp++ = nulldesc;
#else					/* COMPILER */
   /*
    * Push two null descriptors on the stack.
    */
   *dsp++ = nulldesc;
   *dsp++ = nulldesc;

   sblkp->es_sp = (word *)dsp - 1;
#endif					/* COMPILER */

#endif					/* CoExpr */
   }

/*
 * co_chng - high-level co-expression context switch.
 */
int co_chng(ncp, valloc, rsltloc, swtch_typ, first)
struct b_coexpr *ncp;
struct descrip *valloc; /* location of value being transmitted */
struct descrip *rsltloc;/* location to put result */
int swtch_typ;          /* A_Coact, A_Coret, A_Cofail, or A_MTEvent */
int first;
{
#ifndef CoExpr
   syserr("co_chng() called, but co-expressions not implemented");
#else        				/* CoExpr */

   register struct b_coexpr *ccp;
   CURTSTATE();

   ccp = (struct b_coexpr *)BlkLoc(k_current);

#if !COMPILER
#ifdef MultiThread
   switch(swtch_typ) {
      /*
       * A_MTEvent does not generate an event.
       */
      case A_MTEvent:
	 break;
      case A_Coact:
         EVValX(ncp,E_Coact);
	 if (!is:null(curpstate->eventmask) && ncp->program == curpstate) {
	    curpstate->parent->eventsource.dword = D_Coexpr;
	    BlkLoc(curpstate->parent->eventsource) = (union block *)ncp;
	    }
#ifdef Concurrent
	    if (ncp->program == ccp->program) {
	       struct context *nctx, *cctx;
	       nctx = (struct context *) ncp->cstate[1];
	       cctx = (struct context *) ccp->cstate[1];
	       if (nctx->tstate)
	       	  nctx->tstate->K_level =  cctx->tstate->K_level;
	       else
	       	  nctx->tmplevel =  cctx->tstate->K_level;
	    	}
#endif					/* Concurrent */
	 break;
      case A_Coret:
         EVValX(ncp,E_Coret);
	 if (!is:null(curpstate->eventmask) && ncp->program == curpstate) {
	    curpstate->parent->eventsource.dword = D_Coexpr;
	    BlkLoc(curpstate->parent->eventsource) = (union block *)ncp;
	    }
	 break;
      case A_Cofail:
         EVValX(ncp,E_Cofail);
	 if (!is:null(curpstate->eventmask) && ncp->program == curpstate) {
	    curpstate->parent->eventsource.dword = D_Coexpr;
	    BlkLoc(curpstate->parent->eventsource) = (union block *)ncp;
	    }
	 break;
      }
#endif        				/* MultiThread */
#endif					/* COMPILER */

   /*
    * Determine if we need to transmit a value.
    */
   if (valloc != NULL) {

#if !COMPILER
      /*
       * Determine if we need to dereference the transmitted value. 
       */
      if (Var(*valloc))
         retderef(valloc, (word *)glbl_argp, sp);
#endif					/* COMPILER */

#ifdef Concurrent
      if (ccp->status & Ts_Async){
         struct b_list *hp;
         struct descrip L;
         L = ccp->outbox;
      	 hp = BlkD(L, List);
      	 MUTEX_LOCKBLK_CONTROLLED(hp, "co_chng(): list mutex");
      	 if (hp->size>=hp->max){
            hp->full++;
            while (hp->size>=hp->max){
 	       CV_SIGNAL_EMPTYBLK(hp);
	       DEC_NARTHREADS;
	       CV_WAIT_FULLBLK(hp);
	       INC_NARTHREADS_CONTROLLED;
	       }
	    hp->full--;
      	    }
         c_put(&L, valloc);
      	 MUTEX_UNLOCKBLK(hp, "co_chng(): list mutex");
      	 CV_SIGNAL_EMPTYBLK(hp);
	 return;
      }
      else
#endif					/* Concurrent */
         if (ncp->tvalloc != NULL)
            *ncp->tvalloc = *valloc;
      }

#ifdef Concurrent
   /*
    * exit if this is a thread.
    * May want to check/fix thread  activator initialization 
    * depending on desired join semantics.
    * coclean calls pthread_exit() in case of Async threads.
    */
   if (ccp->status & Ts_Async){
      #ifdef CoClean
 	 coclean(ccp->cstate);
      #endif				/* CoClean */
      }
#endif					/* Concurrent */

   ncp->tvalloc = NULL;
   ccp->tvalloc = rsltloc;

   /*
    * Save state of current co-expression.
    */
   ccp->es_pfp = pfp;
   ccp->es_argp = glbl_argp;
   ccp->es_tend = tend;
#if !COMPILER
   ccp->es_efp = efp;
   ccp->es_gfp = gfp;
   ccp->es_ipc = ipc;
   ccp->es_oldipc = oldipc; /* To be used when the found line is zero*/
   ccp->es_sp = sp;
   ccp->es_ilevel = ilevel;
#ifdef EventMon
   ccp->actv_count += 1;
#endif					/* EventMon */
#endif					/* COMPILER */

#if COMPILER
   if (line_info) {
      ccp->file_name = file_name;
      ccp->line_num = line_num;
      file_name = ncp->file_name;
      line_num = ncp->line_num;
      }
#endif					/* COMPILER */

#if COMPILER
   if (debug_info)
#endif					/* COMPILER */
      if (k_trace) {
#ifdef MultiThread
	 if (swtch_typ != A_MTEvent)
#endif					/* MultiThread */
	 cotrace(ccp, ncp, swtch_typ, valloc);
	 }

#ifndef Concurrent
   /*
    * Establish state for new co-expression.
    */
   pfp = ncp->es_pfp;
   tend = ncp->es_tend;

#if !COMPILER
   efp = ncp->es_efp;
   gfp = ncp->es_gfp;
   ipc = ncp->es_ipc;
   sp = ncp->es_sp;
   ilevel = (int)ncp->es_ilevel;
#endif					/* COMPILER */

#if 0
/* testing: update the curtstate for native (non-pthreads) co-expr switches */
#ifndef PthreadCoswitch
   curtstate = ncp->tstate;
#endif                                  /* PthreadCoswitch */
#endif

#if !COMPILER
#ifdef MultiThread
   /*
    * Enter the program state of the co-expression being activated
    */
   ENTERPSTATE(ncp->program);
#endif        				/* MultiThread */
#endif					/* COMPILER */

   glbl_argp = ncp->es_argp;
   BlkLoc(k_current) = (union block *)ncp;

#if COMPILER
   coexpr_fnc = ncp->fnc;
#endif					/* COMPILER */

#else					/* ! Concurrent */
#if !COMPILER
#ifdef MultiThread
   /*
    * Enter the program state of the co-expression being activated
    */
   ENTERPSTATE(ncp->program);
#endif        				/* MultiThread */
#endif					/* COMPILER */
#endif					/* ! Concurrent */

#ifdef MultiThread
   /*
    * From here on out, A_MTEvent looks like a A_Coact.
    */
   if (swtch_typ == A_MTEvent)
      swtch_typ = A_Coact;
#endif					/* MultiThread */

   ncp->coexp_act = swtch_typ;
#ifdef PthreadCoswitch
#ifdef Concurrent
   pthreadcoswitch(ccp->cstate, ncp->cstate,first, ccp->status, ncp->status );
#else					/* Concurrent */
   pthreadcoswitch(ccp->cstate, ncp->cstate,first);
#endif					/* Concurrent */
#else					/* PthreadCoswitch */
   coswitch(ccp->cstate, ncp->cstate,first);
#endif					/* PthreadCoswitch */
   /*
    * Beware!  Native co-expression switches may not save all registers,
    * they might only preserve enough to immediate return.  So local variables
    * like ccp might not be correct after the coswitch.
    */
   return ((struct b_coexpr *)BlkLoc(k_current))->coexp_act;

#endif        				/* CoExpr */
   }

#ifdef CoExpr
/*
 * new_context - determine what function to call to execute the new
 *  co-expression; this completes the context switch.
 */
void new_context(fsig,cargp)
int fsig;
dptr cargp;
   {
   continuation cf;
   CURTSTATVAR();
   if (coexpr_fnc != NULL) {
      cf = coexpr_fnc;
      coexpr_fnc = NULL;
      (*cf)();
      }
   else
#if COMPILER
      syserr("new_context() called with no coexpr_fnc defined");
#else					/* COMPILER */
#ifdef TSTATARG 
      interp(fsig, cargp, CURTSTATARG);
#else 		 	   	  	 /* TSTATARG */
      interp(fsig, cargp);
#endif 		 	   	  	 /* TSTATARG */
#endif					/* COMPILER */
   }
#else					/* CoExpr */
/* dummy new_context if co-expressions aren't supported */
void new_context(fsig,cargp)
int fsig;
dptr cargp;
   {
   syserr("new_context() called, but co-expressions not implemented");
   }
#endif					/* CoExpr */


#ifdef PthreadCoswitch
/*
 * pthreads.c -- Icon context switch code using POSIX threads and semaphores
 *
 * This code implements co-expression context switching on any system that
 * provides POSIX threads and semaphores.  It requires Icon 9.4.1 or later
 * built with "#define CoClean" in order to free threads and semaphores when
 * co-expressions are collected.  It is typically much slower when called
 * than platform-specific custom code, but of course it is much more portable,
 * and it is typically used infrequently.
 *
 * Unnamed semaphores are used unless NamedSemaphores is defined.
 * (This is for Mac OS 10.3 which does not have unnamed semaphores.)
 */

#if 0
static int pco_inited = 0;		/* has first-time initialization been done? */
#endif

/*
 * coswitch(old, new, first) -- switch contexts.
 */

#ifdef Concurrent
int pthreadcoswitch(void *o, void *n, int first, word ostat, word nstat)
#else
int pthreadcoswitch(void *o, void *n, int first)
#endif					/* Concurrent */
{
   cstate ocs = o;			/* old cstate pointer */
   cstate ncs = n;			/* new cstate pointer */
   context *old, *new;			/* old and new context pointers */

   old = ocs[1];			/* load current context pointer */

   if (first != 0)			/* if not first call for this cstate */
      new = ncs[1];			/* load new context pointer */
   else {
      /*
       * This is a newly allocated cstate array, allocated and initialized
       * over in alccoexp().  Create a thread for it and mark it alive.
       */
      new = ncs[1];
       if (pthread_create(&new->thread, NULL, nctramp, new) != 0) 
         syserr("cannot create thread");
      new->alive = 1;
      new->have_thread = 1;

      /*if (!(nstat & Ts_Sync ))pthread_detach(&new->thread);*/
      }
   
   sem_post(new->semp);			/* unblock the new thread */

#ifdef AAAConcurrent
   if (nstat & Ts_Sync )
#endif					/* Concurrent */
      
      sem_wait(old->semp);		/* block this thread */

   if (!old->alive) {
      pthread_exit(NULL);		/* if unblocked because unwanted */
      }
   return 0;				/* else return to continue running */
   }

/*
 * coclean(old) -- clean up co-expression state before freeing.
 */
void coclean(void *o) {
   cstate ocs = o;			/* old cstate pointer */
   struct context *old = ocs[1];	/* old context pointer */
   struct region *strregion=NULL, *blkregion=NULL;
   if (old == NULL) 			/* if never initialized, do nothing */
     /* ((old->c->status & Ts_Sync) && (old->alive == 0)))*/      
      return;
    
   if (old->tstate){
      strregion = old->tstate->Curstring;
      blkregion = old->tstate->Curblock;
   }


   if (old->c->status & Ts_Sync){
      old->alive = 0;			/* signal thread to exit */
      if (old->have_thread){
         sem_post(old->semp);		/* unblock it */
         THREAD_JOIN(old->thread, NULL);	/* wait for thread to exit */
         }
      }
 
   #ifdef NamedSemaphores
      sem_close(old->semp);		/* close associated semaphore */
   #else
      sem_destroy(old->semp);		/* destroy associated semaphore */
   #endif

   if ((old->c->status & Ts_Async) && (old->alive <= 0)){
      MUTEX_LOCKID(MTX_TLS_CHAIN);
      tlschain_remove(old->tstate);
      MUTEX_UNLOCKID(MTX_TLS_CHAIN);
      free(old); 			/* free context block */
      return;
      }

   if (old->c->status & Ts_Async){
      tended struct b_list *hp;
      /* give up the heaps owned by the thread */
      if (blkregion){
         MUTEX_LOCKID(MTX_PUBLICBLKHEAP);
         swap2publicheap(blkregion, NULL,  &public_blockregion);
         MUTEX_UNLOCKID(MTX_PUBLICBLKHEAP);

         MUTEX_LOCKID(MTX_PUBLICSTRHEAP);
         swap2publicheap(strregion, NULL,  &public_stringregion);
         MUTEX_UNLOCKID(MTX_PUBLICSTRHEAP);
         }
      DEC_NARTHREADS;	
      old->alive = -1;

      hp = BlkD(old->c->outbox, List);
      CV_SIGNAL_EMPTYBLK(hp);

      hp = BlkD(old->c->inbox, List);
      CV_SIGNAL_FULLBLK(hp);

      pthread_exit(NULL);
      }
   else{
      /*
       * Give up the heaps owned by the old thread, 
       * only GC thread is running, no need to lock 
       */
      if (blkregion){
         swap2publicheap(blkregion, NULL,  &public_blockregion);
         swap2publicheap(strregion, NULL,  &public_stringregion);
         }
      tlschain_remove(old->tstate);
      free(old); 			/* free context block */
      }
  }

/*
 * makesem(ctx) -- initialize semaphore in context struct.
 */
void makesem(struct context *ctx) {
   #ifdef NamedSemaphores		/* if cannot use unnamed semaphores */
      char name[50];
      sprintf(name, "i%ld.sem", (long)getpid());
      ctx->semp = sem_open(name, O_CREAT, S_IRUSR | S_IWUSR, 0);
      if (ctx->semp == (sem_t *)SEM_FAILED)
         syserr("cannot create semaphore");
      sem_unlink(name);
   #else				/* NamedSemaphores */
      if (sem_init(&ctx->sema, 0, 0) == -1)
         syserr("cannot init semaphore");
      ctx->semp = &ctx->sema;
   #endif				/* NamedSemaphores */
   }

#if defined(Concurrent) && !defined(HAVE_KEYWORD__THREAD)
pthread_key_t tstate_key;
struct threadstate * alloc_tstate()
{
   struct threadstate *ts = malloc(sizeof(struct threadstate));
   if (ts == NULL) syserr("alloc_tstate(): Out of memory");
   return ts;
}
#endif					/* Concurrent && !HAVE_KEYWORD__THREAD */

/*
 * nctramp() -- trampoline for calling new_context(0,0).
 */
void *nctramp(void *arg)
{
   struct context *new = arg;		/* new context pointer */
   struct b_coexpr *ce;
#ifdef Concurrent

#ifndef HAVE_KEYWORD__THREAD
    struct threadstate *curtstate;
    curtstate = (new->tstate ? new->tstate : alloc_tstate());
    pthread_setspecific(tstate_key, (void *) curtstate);
#endif					/* HAVE_KEYWORD__THREAD */

   init_threadstate(curtstate);
   tlschain_add(curtstate, new);
   pthread_setcancelstate(PTHREAD_CANCEL_ENABLE, NULL);

   k_level = new->tmplevel;
   ce = new->c;
   if (ce->title != T_Coexpr) {
      fprintf(stderr, "warning ce title is %ld\n", ce->title);
      }
   pfp = ce->es_pfp;
   efp = ce->es_efp;
   gfp = ce->es_gfp;
   tend = ce->es_tend;
   ipc = ce->es_ipc;
   ilevel = ce->es_ilevel;
   sp = ce->es_sp;
   stack = ce->es_stack;
   stackend = ce->es_stackend;
   glbl_argp = ce->es_argp;
   k_current.dword = D_Coexpr;
   BlkLoc(k_current) = (union block *)ce;

   init_threadheap(curtstate, ce->ini_blksize, ce->ini_ssize);

#endif					/* Concurrent */
   sem_wait(new->semp);			/* wait for signal */
   new_context(0, 0);			/* call new_context; will not return */
   syserr("new_context returned to nctramp");
   return NULL;
   }
#endif					/* PthreadCoswitch */

#ifdef Concurrent 

pthread_mutexattr_t rmtx_attr;  /* recursive mutex attr ready to be used */
pthread_t TCthread;
int thread_call;
int NARthreads;
pthread_cond_t cond_tc;
sem_t sem_tc; 

pthread_cond_t **condvars;
word* condvarsmtxs;
word maxcondvars;
word ncondvars; 

pthread_mutex_t **mutexes;
word maxmutexes;
word nmutexes; 

void init_threads()
{
   int i;

   pthread_mutexattr_init(&rmtx_attr);
   pthread_mutexattr_settype(&rmtx_attr,PTHREAD_MUTEX_RECURSIVE);

   rootpstate.mutexid_stringtotal = MTX_STRINGTOTAL;
   rootpstate.mutexid_blocktotal = MTX_BLOCKTOTAL;
   rootpstate.mutexid_coll = MTX_COLL;

   pthread_cond_init(&cond_tc, NULL);
   sem_init(&sem_tc, 0, 1);

   maxmutexes = 1024;
   mutexes=malloc(maxmutexes * sizeof(pthread_mutex_t *));
   if (mutexes==NULL) syserr("init_threads(): out of memory for mutexes!");

   ncondvars = 0;
   maxcondvars = 10*1024;
   condvars=malloc(maxcondvars * sizeof(pthread_cond_t *));
   condvarsmtxs=malloc(maxcondvars * WordSize);
   if (condvars==NULL || condvarsmtxs==NULL)
	     syserr("init_threads(): out of memory for condition variables!");


   nmutexes = NUM_STATIC_MUTEXES;

   for(i=0; i<NUM_STATIC_MUTEXES-1; i++)
      MUTEX_INITID(i, NULL);
   
   /* recursive mutex for initial clause */
   MUTEX_INITID( MTX_INITIAL, &rmtx_attr);
}

void clean_threads()
{
   int i;
   /*
    * Make sure that mutexes, thread stuff are initialized before cleaning
    * them. If not, just return; this might happen if iconx is called with
    * no args, for example.
    */


   pthread_cond_destroy(&cond_tc);
   sem_destroy(&sem_tc);

   for(i=0; i<nmutexes; i++){
      pthread_mutex_destroy(mutexes[i]);
      free(mutexes[i]);
      }
   
   free(mutexes);
   

   for(i=0; i<ncondvars; i++){
      pthread_cond_destroy(condvars[i]);
      free(condvars[i]);
      }

   pthread_mutexattr_destroy(&rmtx_attr);
   
   free(condvars);
   free(condvarsmtxs);

}
/*
 *  pthread errors handler
 */
void handle_thread_error(int val)
{
   switch(val) {

   case EINVAL:
      fatalerr(180, NULL);
      /* or syserr("the calling thread's priority is higher than the mutex's current priority ceiling");*/
      break;
   case EBUSY:
     /*syserr("The mutex could not be acquired because it was already locked. ");*/
      break;
   case EAGAIN :
      syserr("The mutex could not be acquired because the maximum number of recursive locks for mutex has been exceeded");
      break;
   case EDEADLK:
      syserr("The current thread already owns the mutex.");
      break;
   case EPERM:
      syserr("The current thread does not own the mutex. ");
      break;

   case ESRCH: /* pthread_cancel */
     fprintf(stderr, "\nError: Tried to cancel a thread that doesn't exist.\n");
      break;


   default:
      syserr(" pthread function error!\n ");
      break;

      }
}

/*
 * Function thread_control() governs when to run and when to stop threads.
 * Called by any place in the runtime system when it needs to stop all the
 * threads, notably garbage collection and runtime errors.  Not yet
 * implemented: ability to stop/resume individual threads.
 *
 * Legal values for the parameter (action) are:
 *   0==put this thread to sleep
 *   1==wakeup all
 *   2==stop all threads
 *   3==kill all threads
 */
void thread_control(action)
int action; 
{
   static int tc_queue=0;        /* how many threads are waiting for TC */
   static int action_in_progress=TC_NONE;
   
   CURTSTATE();

   switch (action){
      case TC_ANSWERCALL:{
         /*---------------------------------*/
         switch (action_in_progress){
	    case TC_KILLALLTHREADS:
      	    default:{
      	       /*
       	        *  Check to see it is necessary to do GC for the current thread.
       		*  Hopefully we will force GC to happen if that is the case.
       		*/
               if ((curtblock->end - curtblock->free) / (double) curtblock->size < 0.09) {
	          if (!reserve(Blocks, curtblock->end - curtblock->free + 100))
	             fprintf(stderr, " Disaster! in thread_control. \n");
	          return;
         	  }


  	       /* The thread that gets here should block and wait for TC to finish. */

  	       /*
   	        * Lock MUTEX_COND_TC mutex and wait on the condition variable cond_gc.
   		* note that pthread_cond_wait will block the thread and will automatically
   		* and atomically unlock mutex while it waits. 
   		*/

  	       MUTEX_LOCKID(MTX_COND_TC);
    	       MUTEX_LOCKID(MTX_NARTHREADS);
    	       NARthreads--;
    	       MUTEX_UNLOCKID(MTX_NARTHREADS);
    	       while (thread_call) 
       	          pthread_cond_wait(&cond_tc, MUTEXID(MTX_COND_TC)); /*block!!*/
  	       MUTEX_UNLOCKID(MTX_COND_TC);

  	       /* 
	        * wake up call received! TC is over. increment NARthread 
	        * and go back to work
		*/

  	       INC_NARTHREADS_CONTROLLED;
               return;

	       } /* default */
	    } /* switch (action_in_progress)  */
	 break;
         /*---------------------------------*/
	 }
      case TC_WAKEUPCALL:{
         if (tc_queue){  /* Other threads are waiting for to take control */

	    /* lock MUTEX_COND_TC mutex and wait on the condition variable 
	     * cond_gc.
	     * note that pthread_cond_wait will block the thread and will
	     * automatically and atomically unlock the mutex while it is 
	     * blocking the thread. 
	     */

      	    MUTEX_UNLOCKID(MTX_NARTHREADS);
      	    MUTEX_UNLOCKID(MTX_THREADCONTROL);

	    MUTEX_LOCKID(MTX_COND_TC);
	    /* wake up another TCthread and go to sleep */
	    sem_post(&sem_tc);
	    while (thread_call) 
	       pthread_cond_wait(&cond_tc, MUTEXID(MTX_COND_TC)); /*block!!*/
	    MUTEX_UNLOCKID(MTX_COND_TC);
	 
	    /* Another TC thread just woke me up!
	     * TC is over. Increment NARthreads and return.
	     */
	    MUTEX_LOCKID(MTX_NARTHREADS);
	    NARthreads++;
	    MUTEX_UNLOCKID(MTX_NARTHREADS);

	    return;
            }
         /* 
          * GC is over, reset GCthread and wakeup all threads. 
          * reset (post) sem_gc to be ready for the next GC round
          */

         thread_call = 0;
         NARthreads++;
         sem_post(&sem_tc);
         action_in_progress = TC_NONE;
         MUTEX_UNLOCKID(MTX_NARTHREADS);
         MUTEX_UNLOCKID(MTX_THREADCONTROL);
         /* broadcast a wakeup call to all threads waiting on cond_tc */
         pthread_cond_broadcast(&cond_tc);
         return;
         }
      case:TC_STOPALLTHREADS:{
         /*
          * If there is a pending TC request, then block/sleep.
          * Make sure we do not start a GC in the middle of starting
          * a new Async thread. Precaution to avoid problems.
          */

         MUTEX_LOCKID(MTX_NARTHREADS);
         NARthreads--;
         tc_queue++;
         MUTEX_UNLOCKID(MTX_NARTHREADS);

         sem_wait(&sem_tc); /* Allow only one thread to pass at a time!! */

         /* If another TCthread just woke me up, ensure that he is gone to sleep already! */
         MUTEX_LOCKID(MTX_COND_TC);
         MUTEX_UNLOCKID(MTX_COND_TC);

         MUTEX_LOCKID(MTX_THREADCONTROL);

         TCthread = pthread_self();
         thread_call = 1;
         action_in_progress = action;
	 /* NARthreads should reach and stay at zero during TC*/
	 while (1) {
	    MUTEX_LOCKID(MTX_NARTHREADS);
	    if (NARthreads  <= 0) break;  /* unlock MTX_NARTHREADS after GC*/
	    MUTEX_UNLOCKID(MTX_NARTHREADS);
	    usleep(2);
	    }
         /*
          * Now it is safe to proceed with GC with only the current thread running
          */
         tc_queue--;
         return;
         }
      case TC_KILLALLTHREADS:{

         if (ccp->status & Ts_Async){
      	    #ifdef CoClean
 	    coclean(ccp->cstate);
            #endif				/* CoClean */
            }
	 break;
         }
      default:{

      }  /* switch (action) */

  return;
}

void howmanyblock()
{
  int i=0;
  struct region *rp;
  
  printf("here is what I have:\n");
  rp = curpstate->stringregion;
  while (rp){ i++;   rp = rp->Gnext; }
  rp = curpstate->stringregion->Gprev;
  while (rp){ i++;   rp = rp->Gprev; }
  printf(" Global string= %d\n", i);

  rp = curpstate->stringregion;
  i=0;
  while (rp){ i++; rp = rp->next;}
  rp = curpstate->stringregion->prev;
  while (rp){ i++;   rp = rp->prev; }

  printf(" local string= %d\n", i);

  rp = curpstate->blockregion;
  i=0;
  while (rp){i++; rp = rp->Gnext;}
  rp = curpstate->blockregion->Gprev;
  while (rp){ i++;   rp = rp->Gprev; }

  printf(" Global block= %d\n", i);

  rp = curpstate->blockregion;
  i=0;
  while (rp){i++; rp = rp->next; }
  rp = curpstate->blockregion->prev;
  while (rp){ i++;   rp = rp->prev; }

  printf(" local block= %d\n", i);
}

void tlschain_add(struct threadstate *tstate, struct context *ctx)
{
   MUTEX_LOCKID(MTX_TLS_CHAIN);
   tstate->prev = roottstatep->prev;
   tstate->next = NULL;
   roottstatep->prev->next = tstate;
   roottstatep->prev = tstate;
   if (ctx){
      tstate->ctx = ctx;
      ctx->tstate = tstate;
      }
   else
      /*
       *  Warning: This may overwrite already initialized ctx,
       *  But we can not risk leaving ctx uninitialized. 
       */
      tstate->ctx = NULL;

   MUTEX_UNLOCKID(MTX_TLS_CHAIN);
}

void tlschain_remove(struct threadstate *tstate)
{
   /* 
    * This function assumes that MTX_TLS_CHAIN is locked/unlocked 
    * if needed. GCthread doesn't need to lock for example.
    */

   if (!tstate || !tstate->prev) return;
 
   tstate->prev->next = tstate->next;
   if (tstate->next)
      tstate->next->prev = tstate->prev;

   rootpstate.stringtotal += tstate->stringtotal;
   rootpstate.blocktotal += tstate->blocktotal;

   if (tstate->ctx && tstate->ctx->isProghead) return;
   
   free(tstate);
}

/*
 * reuse_region - search region chain for a region having at least nbytes available
 */
static struct region *reuse_region(nbytes, region)
word nbytes;
int region;
   {
   struct region **p_public;
   struct region *curr;
   int mtx_publicheap;
   word freebytes = nbytes / 4;

   if (region == Strings){
      p_public = &public_stringregion;
      mtx_publicheap = MTX_PUBLICSTRHEAP;
      }
   else{
      p_public = &public_blockregion;
      mtx_publicheap = MTX_PUBLICBLKHEAP;
      }

   MUTEX_LOCKID(mtx_publicheap);
   for (curr = *p_public; curr; curr = curr->Tnext){
      if ( (curr->size>=nbytes) &&  DiffPtrs(curr->end, curr->free) >= freebytes){
         if (curr->Tprev) curr->Tprev->Tnext = curr->Tnext;
	 else *p_public = curr->Tnext;	        
  	 if (curr->Tnext) curr->Tnext->Tprev = curr->Tprev;
         curr->Tnext= NULL;
         curr->Tprev = NULL;
	  break;
 	   }
      }
   MUTEX_UNLOCKID(mtx_publicheap);

   return curr;
   }

/*
 * Initialize separate heaps for (concurrent) threads.
 * At present, PthreadCoswitch probably uses this for Pthread coexpressions.
 */
void init_threadheap(struct threadstate *ts, word blksiz, word strsiz)
{ 
   struct region *rp;

   /*
    *  new string and block region should be allocated.
    */

    if (strsiz <  MinStrSpace)
       strsiz = MinStrSpace;
    if (blksiz <  MinAbrSize)
       blksiz = MinAbrSize;

   if((rp = reuse_region(strsiz, Strings)) != 0)
      ts->Curstring =  curstring = rp;
   else if ((rp = newregion(strsiz, strsiz)) != 0) {
      MUTEX_LOCKID(MTX_STRHEAP);
      rp->prev = curstring;
      rp->next = NULL;
      curstring->next = rp;
      rp->Gnext = curstring;
      rp->Gprev = curstring->Gprev;
      if (curstring->Gprev) curstring->Gprev->Gnext = rp;
      curstring->Gprev = rp;
      curstring = rp;
      MUTEX_UNLOCKID(MTX_STRHEAP);
      ts->Curstring = rp;
      }
    else
      syserr(" init_threadheap: insufficient memory for string region");

   if((rp = reuse_region(blksiz, Blocks)) != 0)
      ts->Curblock =  curblock = rp;
   else if ((rp = newregion(blksiz, blksiz)) != 0) {
      MUTEX_LOCKID(MTX_BLKHEAP);
      rp->prev = curblock;
      rp->next = NULL;
      curblock->next = rp;
      rp->Gnext = curblock;
      rp->Gprev = curblock->Gprev;
      if (curblock->Gprev) curblock->Gprev->Gnext = rp;
      curblock->Gprev = rp;
      curblock = rp;
      MUTEX_UNLOCKID(MTX_BLKHEAP);
      ts->Curblock = rp;
      }
    else
      syserr(" init_threadheap: insufficient memory for block region");
}

#endif 					/* Concurrent */
