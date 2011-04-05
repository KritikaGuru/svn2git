/*
 * File: fmisc.r
 * Contents:
 *  args, char, collect, copy, display, function, iand, icom, image, ior,
 *  ishift, ixor, [keyword], [load], ord, name, runerr, seq, sort, sortf,
 *  type, variable
 */
#if !COMPILER
#include "../h/opdefs.h"
#endif					/* !COMPILER */

"args(x,i) - produce number of arguments for procedure x."

function{0,1} args(x,i)

   if is:proc(x) then {
      abstract { return integer }
      inline { return C_integer BlkD(x,Proc)->nparam; }
      }
   else if !is:coexpr(x) then
      runerr(106, x)
   else if is:null(i) then {
      abstract { return integer }
      inline {
#ifdef MultiThread
	 return C_integer BlkD(x,Coexpr)->program->tstate->Xnargs;
#else
	 fail;
#endif					/* MultiThread */
	 }
      }
   else if !cnv:integer(i) then
      runerr(103, i)
   else {
      abstract { return any_value }
      inline {
#ifdef MultiThread
	 int c_i = IntVal(i);
	 if ((c_i <= 0) || (c_i > BlkD(x,Coexpr)->program->tstate->Xnargs)) fail;
	 return BlkD(x,Coexpr)->program->tstate->Xargp[IntVal(i)];
#else
	 fail;
#endif					/* MultiThread */
	 }
      }
end

#if !COMPILER
#ifdef ExternalFunctions

/*
 * callout - call a C library routine (or any C routine that doesn't call Icon)
 *   with an argument count and a list of descriptors.  This routine
 *   doesn't build a procedure frame to prepare for calling Icon back.
 */
function{1} callout(x[nargs])
   body {
      dptr retval;
      int signal;

      /*
       * Little cheat here.  Although this is a var-arg procedure, we need
       *  at least one argument to get started: pretend there is a null on
       *  the stack.  NOTE:  Actually, at present, varargs functions always
       *  have at least one argument, so this doesn't plug the hole.
       */
      if (nargs < 1)
         runerr(103, nulldesc);

      /*
       * Call the 'C routine caller' with a pointer to an array of descriptors.
       *  Note that these are being left on the stack. We are passing
       *  the name of the routine as part of the convention of calling
       *  routines with an argc/argv technique.
       */
      signal = -1;			/* presume successful completiong */
      retval = extcall(x, nargs, &signal);
      if (signal >= 0) {
         if (retval == NULL)
            runerr(signal);
         else
            runerr(signal, *retval); 
         }
      if (retval != NULL) {
         return *retval;
         }
      else 
         fail;
      }
end

#endif 					/* ExternalFunctions */
#endif					/* !COMPILER */


"char(i) - produce a string consisting of character i."

function{1} char(i)

   if !cnv:C_integer(i) then
      runerr(101,i)
   abstract {
      return string
      }
   body {
      if (i < 0 || i > 255) {
         irunerr(205, i);
         errorfail;
         }
      return string(1, (char *)&allchars[FromAscii(i) & 0xFF]);
      }
end


"collect(i1,i2) - call garbage collector to ensure i2 bytes in region i1."
" no longer works."

function{1} collect(region, bytes)

   if !def:C_integer(region, (C_integer)0) then
      runerr(101, region) 
   if !def:C_integer(bytes, (C_integer)0) then
      runerr(101, bytes)

   abstract {
      return null
      }
   body {
      CURTSTATE();
      if (bytes < 0) {
         irunerr(205, bytes);
         errorfail;
         }
      switch (region) {
	 case 0:
	    collect(0);
	    break;
	 case Static:
	    collect(Static);			 /* i2 ignored if i1==Static */
	    break;
	 case Strings:
	    if (DiffPtrs(strend,strfree) >= bytes)
	       collect(Strings);		/* force unneded collection */
	    else if (!reserve(Strings, bytes))	/* collect & reserve bytes */
               fail;
	    break;
	 case Blocks:
	    if (DiffPtrs(blkend,blkfree) >= bytes)
	       collect(Blocks);			/* force unneded collection */
	    else if (!reserve(Blocks, bytes))	/* collect & reserve bytes */
               fail;
	    break;
	 default:
            irunerr(205, region);
            errorfail;
         }
      return nulldesc;
      }
end


"copy(x) - make a copy of object x."

function{1} copy(x)
   abstract {
      return type(x)
      }
   type_case x of {
      null:
      string:
      cset:
      integer:
      real:
      file:
      proc:
      coexpr:
#ifdef PatternType
      pattern:
#endif					/* PatternType */
         inline {
            /*
             * Copy the null value, integers, long integers, reals, files,
             *	csets, procedures, and such by copying the descriptor.
             *	Note that for integers, this results in the assignment
             *	of a value, for the other types, a pointer is directed to
             *	a data block.
             */
            return x;
            }

      list:
         inline {
            /*
             * Pass the buck to cplist to copy a list.
             */
            if (cplist(&x, &result, (word)1, BlkD(x,List)->size + 1) ==Error)
	       runerr(0);
            return result;
            }
      table: {
         body {
	    if (cptable(&x, &result, BlkD(x,Table)->size) == Error) {
	       runerr(0);
	       }
	    return result;
            }
         }

      set: {
         body {
            /*
             * Pass the buck to cpset to copy a set.
             */
            if (cpset(&x, &result, BlkD(x,Set)->size) == Error)
               runerr(0);
	    return result;
            }
         }

      record: {
         body {
            /*
             * Note, these pointers don't need to be tended, because they are
             *  not used until after allocation is complete.
             */
            struct b_record *new_rec;
            tended struct b_record *old_rec;
            dptr d1, d2;
            int i;

            /*
             * Allocate space for the new record and copy the old
             *	one into it.
             */
            old_rec = BlkD(x, Record);
            i = Blk(old_rec->recdesc,Proc)->nfields;

            /* #%#% param changed ? */
            Protect(new_rec = alcrecd(i,old_rec->recdesc), runerr(0));
            d1 = new_rec->fields;
            d2 = old_rec->fields;
            while (i--)
               *d1++ = *d2++;
	    Desc_EVValD(new_rec, E_Rcreate, D_Record);
            return record(new_rec);
            }
         }

      default: body {
#if Never
         if (Type(x) == T_External) {
            word n;
            tended union block *op, *bp;

            /*
             * Duplicate the block.  Recover number of data words in block,
             * then allocate new block and copy the data.
             */
            op = BlkLoc(x);
            n = (op->externl.blksize - (sizeof(struct b_external) - 
                 sizeof(word))) / sizeof(word);
            Protect(bp = (union block *)alcextrnl(n), runerr(0));
            while (n--)
               bp->externl.exdata[n] = op->externl.exdata[n];
            result.dword = D_External;
            BlkLoc(result) = bp;
	    return result;
            }
         else
#endif					/* Never */
            runerr(123,x);
         }
         }
end


"display(i,f) - display local variables of i most recent"
" procedure activations, plus global variables."
" Output to file f (default &errout)."

#ifdef MultiThread
function{1} display(i,f,c)
   declare {
      struct b_coexpr *ce = NULL;
      struct progstate *prog, *savedprog;
#ifdef Concurrent
      struct threadstate *curtstate = get_tstate();
#endif					/* Concurrent */
      }
#else					/* MultiThread */
function{1} display(i,f)
#endif					/* MultiThread */

   if !def:C_integer(i,(C_integer)k_level) then
      runerr(101, i)

   if is:null(f) then
       inline {
	  f.dword = D_File;
	  BlkLoc(f) = (union block *)&k_errout;
          }
   else if !is:file(f) then
      runerr(105, f)

#ifdef MultiThread
   if !is:null(c) then inline {
      if (!is:coexpr(c)) runerr(118,c);
      else if (BlkLoc(c) != BlkLoc(k_current))
         ce = (struct b_coexpr *)BlkLoc(c);
      savedprog = curpstate;
      }
#endif						/* MultiThread */

   abstract {
      return null
      }

   body {
      FILE *std_f;
      int r;

      if (!debug_info)
         runerr(402);

      /*
       * Produce error if file cannot be written.
       */
      if ((BlkD(f,File)->status & Fs_Write) == 0) 
         runerr(213, f);

      std_f = BlkD(f,File)->fd.fp;

      /*
       * Produce error if i is negative; constrain i to be <= &level.
       */
      if (i < 0) {
         irunerr(205, i);
         errorfail;
         }
      else if (i > k_level)
         i = k_level;

      fprintf(std_f,"co-expression_%ld(%ld)\n\n",
         (long)BlkD(k_current,Coexpr)->id,
	 (long)BlkD(k_current,Coexpr)->size);
      fflush(std_f);
#ifdef MultiThread
      if (ce) {
	 if ((ce->es_pfp == NULL) || (ce->es_argp == NULL)) fail;
	 ENTERPSTATE(ce->program);
         r = xdisp(ce->es_pfp, ce->es_argp, (int)i, std_f);
	 ENTERPSTATE(savedprog);
       }
      else
#endif						/* MultiThread */
         r = xdisp(pfp, glbl_argp, (int)i, std_f);
      if (r == Failed)
         runerr(305);
      return nulldesc;
      }
end


"errorclear() - clear error condition."

function{1} errorclear()
   abstract {
      return null
      }
   body {
      CURTSTATE();
      k_errornumber = 0;
      k_errortext = "";
      k_errorvalue = nulldesc;
      have_errval = 0;
      return nulldesc;
      }
end

#if !COMPILER

"function() - generate the names of the functions."

function{*} function()
   abstract {
      return string
      }
   body {
      register int i;

      for (i = 0; i<pnsize; i++) {
	 suspend string(strlen(pntab[i].pstrep), pntab[i].pstrep);
         }
      fail;
      }
end
#endif					/* !COMPILER */


/*
 * the bitwise operators are identical enough to be expansions
 *  of a macro.
 */

#begdef  bitop(func_name, c_op, operation)
#func_name "(i,j) - produce bitwise " operation " of i and j."
function{1} func_name(i,j)
   /*
    * i and j must be integers
    */
   if !cnv:integer(i) then
      runerr(101,i)
   if !cnv:integer(j) then
      runerr(101,j)

   abstract {
      return integer
      }
   inline {
#ifdef LargeInts
      if ((Type(i)==T_Lrgint) || (Type(j)==T_Lrgint)) {
         big_ ## c_op(i,j);
         }
      else
#endif					/* LargeInts */
      return C_integer IntVal(i) c_op IntVal(j);
      }
end
#enddef

#define bitand &
#define bitor  |
#define bitxor ^
#begdef big_bitand(x,y)
{
   if (bigand(&x, &y, &result) == Error)  /* alcbignum failed */
      runerr(0);
   return result;
}
#enddef
#begdef big_bitor(x,y)
{
   if (bigor(&x, &y, &result) == Error)  /* alcbignum failed */
      runerr(0);
   return result;
}
#enddef
#begdef big_bitxor(x,y)
{
   if (bigxor(&x, &y, &result) == Error)  /* alcbignum failed */
      runerr(0);
   return result;
}
#enddef

bitop(iand, bitand, "AND")          /* iand(i,j) bitwise "and" of i and j */
bitop(ior,  bitor, "inclusive OR")  /* ior(i,j) bitwise "or" of i and j */
bitop(ixor, bitxor, "exclusive OR") /* ixor(i,j) bitwise "xor" of i and j */


"icom(i) - produce bitwise complement (one's complement) of i."

function{1} icom(i)
   /*
    * i must be an integer
    */
   if !cnv:integer(i) then
      runerr(101, i)

   abstract {
      return integer
      }
   inline {
#ifdef LargeInts
      if (Type(i) == T_Lrgint) {
         struct descrip td;

         td.dword = D_Integer;
         IntVal(td) = -1;
         if (bigsub(&td, &i, &result) == Error)  /* alcbignum failed */
            runerr(0);
         return result;
         }
      else
#endif					/* LargeInts */
      return C_integer ~IntVal(i);
      }
end


"image(x) - return string image of object x."
/*
 *  All the interesting work happens in getimage()
 */
function{1} image(x)
   abstract {
      return string
      }
   body {
#ifdef EventMon
      type_case x of {
          tvmonitored:{
             if (getimage(VarLoc(BlkD(x,Tvmonitored)->tv),&result) == Error)
                runerr(0);
             }
          default:{
             if (getimage(&x,&result) == Error)
                runerr(0);
             }
      }
#else
      if (getimage(&x,&result) == Error)
	 runerr(0);
#endif
      return result;
      }
end


"ishift(i,j) - produce i shifted j bit positions (left if j<0, right if j>0)."

function{1} ishift(i,j)

   if !cnv:integer(i) then
      runerr(101, i)
   if !cnv:integer(j) then
      runerr(101, j)

   abstract {
      return integer
      }
   body {
      uword ci;			 /* shift in 0s, even if negative */
      C_integer cj;
#ifdef LargeInts
      if (Type(j) == T_Lrgint)
         runerr(101,j);
      cj = IntVal(j);
      if (Type(i) == T_Lrgint || cj >= WordBits
      || ((ci=(uword)IntVal(i))!=0 && cj>0 && (ci >= (1<<(WordBits-cj-1))))) {
         if (bigshift(&i, &j, &result) == Error)  /* alcbignum failed */
            runerr(0);
         return result;
         }
#else					/* LargeInts */
      ci = (uword)IntVal(i);
      cj = IntVal(j);
#endif					/* LargeInts */
      /*
       * Check for a shift of WordSize or greater; handle specially because
       *  this is beyond C's defined behavior.  Otherwise shift as requested.
       */
      if (cj >= WordBits)
         return C_integer 0;
      if (cj <= -WordBits)
         return C_integer ((IntVal(i) >= 0) ? 0 : -1);
      if (cj >= 0)
         return C_integer ci << cj;
      if (IntVal(i) >= 0)
         return C_integer ci >> -cj;
      /*else*/
         return C_integer ~(~ci >> -cj);	/* sign extending shift */
      }
end


"ord(s) - produce integer ordinal (value) of single character."

function{1} ord(s)
   if !cnv:tmp_string(s) then
      runerr(103, s)
   abstract {
      return integer
      }
   body {
      if (StrLen(s) != 1)
         runerr(205, s);
      return C_integer ToAscii(*StrLoc(s) & 0xFF);
      }
end


"name(v) - return the name of a variable."

#ifdef MultiThread
function{1} name(underef v, c)
   declare {
      struct progstate *prog, *savedprog;
      }
#else						/* MultiThread */
function{1} name(underef v)
#endif						/* MultiThread */
   /*
    * v must be a variable
    */
   if !is:variable(v) then
      runerr(111, v);

   abstract {
      return string
      }

   body {
      C_integer i;
#ifdef Uniconc
      if (!debug_info)
         runerr(402);
#endif

#ifdef MultiThread
      savedprog = curpstate;
      if (is:null(c)) {
         prog = curpstate;
         }
      else if (is:coexpr(c)) {
         prog = BlkD(c,Coexpr)->program;
         }
      else {
         runerr(118,c);
         }

      ENTERPSTATE(prog);
#endif						/* MultiThread */
      i = get_name(&v, &result);		/* return val ? #%#% */

#ifdef MultiThread
      ENTERPSTATE(savedprog);
#endif						/* MultiThread */

      if (i == Error)
         runerr(0);
      return result;
      }
end


"runerr(i,x) - produce runtime error i with value x."

function{} runerr(i,x[n])

   if !cnv:C_integer(i) then
      runerr(101,i)
   body {
      if (i <= 0) {
         irunerr(205,i);
         errorfail;
         }
      /*
       * A reason to make runerr() a vararg function is so that the offending
       * value may be a null value where it was not wanted.
       */
      if (n == 0)
         runerr((int)i);
      else
         runerr((int)i, x[0]);
      }
end

"seq(i, j) - generate i, i+j, i+2*j, ... ."

function{1,*} seq(from, by)

   if !def:C_integer(from, 1) then
      runerr(101, from)
   if !def:C_integer(by, 1) then
      runerr(101, by)
   abstract {
      return integer
      }
   body {
      word seq_lb = 0, seq_ub = 0;
      CURTSTATE();

      /*
       * Produce error if by is 0, i.e., an infinite sequence of from's.
       */
      if (by > 0) {
         seq_lb = MinLong + by;
         seq_ub = MaxLong;
         }
      else if (by < 0) {
         seq_lb = MinLong;
         seq_ub = MaxLong + by;
         }
      else if (by == 0) {
         irunerr(211, by);
         errorfail;
         }

      /*
       * Suspend sequence, stopping when largest or smallest integer
       *  is reached.
       */
      do {
         suspend C_integer from;
         from += by;
         }
      while (from >= seq_lb && from <= seq_ub);

#if !COMPILER
      {
      /*
       * Suspending wipes out some things needed by the trace back code to
       *  render the offending expression. Restore them.
       */
      lastop = Op_Invoke;
      xnargs = 2;
      xargp = r_args;
      r_args[0].dword = D_Proc;
      r_args[0].vword.bptr = (union block *)&Bseq;
      }
#endif					/* COMPILER */

      runerr(203);
      }
end

"serial(x) - return serial number of structure."

function {0,1} serial(x)
   abstract {
      return integer
      }

   type_case x of {
      list:   inline {
         return C_integer BlkD(x,List)->id;
         }
      set:   inline {
         return C_integer BlkD(x,Set)->id;
         }
      table:   inline {
         return C_integer BlkD(x,Table)->id;
         }
      record:   inline {
         return C_integer BlkD(x,Record)->id;
         }
      coexpr:   inline {
         return C_integer BlkD(x,Coexpr)->id;
         }
#ifdef Graphics
      file:   inline {
	 if (BlkD(x,File)->status & Fs_Window) {
	    wsp ws = BlkD(x,File)->fd.wb->window;
	    return C_integer ws->serial;
	    }
	 else {
	    fail;
	    }
         }
#endif					/* Graphics */
      default:
         inline { fail; }
      }
end

"sort(x,i) - sort structure x by method i (for tables)"

function{1} sort(t, i)
   type_case t of {
      list: {
         abstract {
            return type(t)
            }
         body {
            register word size;

            /*
             * Sort the list by copying it into a new list and then using
             *  qsort to sort the descriptors.  (That was easy!)
             */
            size = BlkD(t,List)->size;
            if (cplist(&t, &result, (word)1, size + 1) == Error)
	       runerr(0);
            qsort((char *)Blk(BlkD(result,List)->listhead,Lelem)->lslots,
               (int)size, sizeof(struct descrip),(QSortFncCast) anycmp);

            Desc_EVValD(BlkLoc(result), E_Lcreate, D_List);
            return result;
            }
         }

      record: {
         abstract {
            return new list(store[type(t).all_fields])
            }
         body {
            register dptr d1;
            register word size;
            tended struct b_list *lp;
            union block *bp;
            register int i;
            /*
             * Create a list the size of the record, copy each element into
             * the list, and then sort the list using qsort as in list
             * sorting and return the sorted list.
             */
            size = Blk(BlkD(t,Record)->recdesc,Proc)->nfields;

            Protect(lp = alclist_raw(size, size), runerr(0));

            bp = BlkLoc(t);  /* need not be tended if not set until now */

            if (size > 0) {  /* only need to sort non-empty records */
               d1 = Blk(lp->listhead,Lelem)->lslots;
               for (i = 0; i < size; i++)
                  *d1++ = Blk(bp,Record)->fields[i];
               qsort((char *)Blk(lp->listhead,Lelem)->lslots,(int)size,
                     sizeof(struct descrip),(QSortFncCast)anycmp);
               }

            Desc_EVValD(lp, E_Lcreate, D_List);
            return list(lp);
            }
         }

      set: {
         abstract {
            return new list(store[type(t).set_elem])
            }
         body {
	    register word size;
	    tended struct descrip d;
	    cnv_list(&t, &d); /* can't fail, already know t is a set */

	    size = BlkD(t,Set)->size;
	    if (size > 1)  /* only need to sort non-trivial sets */
	       qsort((char *)Blk(BlkD(d,List)->listhead,Lelem)->lslots,
		     (int)size,sizeof(struct descrip),(QSortFncCast)anycmp);

            return d;
            }
         }

      table: {
         abstract {
            return new list(new list(store[type(t).tbl_key ++
               type(t).tbl_val]) ++ store[type(t).tbl_key ++ type(t).tbl_val])
            }
         if !def:C_integer(i, 1) then
            runerr(101, i)
         body {
            register dptr d1;
            register word size;
            register int j, k, n;
	    tended struct b_table *bp;
            tended struct b_list *lp, *tp;
            tended union block *ep;
	    tended struct b_slots *seg;

            switch ((int)i) {

            /*
             * Cases 1 and 2 are as in early versions of Icon
             */
               case 1:
               case 2:
		      {
               /*
                * The list resulting from the sort will have as many elements
                *  as the table has, so get that value and also make a valid
                *  list block size out of it.
                */
               size = BlkD(t,Table)->size;

	       /*
		* Make sure, now, that there's enough room for all the
		*  allocations we're going to need.
		*/
	       if (!reserve(Blocks, (word)(sizeof(struct b_list)
		  + sizeof(struct b_lelem) + (size - 1) * sizeof(struct descrip)
		  + size * sizeof(struct b_list)
		  + size * (sizeof(struct b_lelem) + sizeof(struct descrip)))))
		  runerr(0);
               /*
                * Point bp at the table header block of the table to be sorted
                *  and point lp at a newly allocated list
                *  that will hold the the result of sorting the table.
                */
               bp = (struct b_table *)BlkLoc(t);
               Protect(lp = alclist(size, size), runerr(0));

               /*
                * If the table is empty, there is no need to sort anything.
                */
               if (size <= 0)
                  break;
               /*
                * Traverse the element chain for each table bucket.  For each
                *  element, allocate a two-element list and put the table
                *  entry value in the first element and the assigned value in
                *  the second element.  The two-element list is assigned to
                *  the descriptor that d1 points at.  When this is done, the
                *  list of two-element lists is complete, but unsorted.
                */

               n = 0;				/* list index */
               for (j = 0; j < HSegs && (seg = bp->hdir[j]) != NULL; j++)
                  for (k = segsize[j] - 1; k >= 0; k--)
                     for (ep= seg->hslots[k];
			  BlkType(ep) == T_Telem;
			  ep = Blk(ep,Telem)->clink){
                        Protect(tp = alclist_raw(2, 2), runerr(0));
                        Blk(tp->listhead,Lelem)->lslots[0]=Blk(ep,Telem)->tref;
                        Blk(tp->listhead,Lelem)->lslots[1]=Blk(ep,Telem)->tval;
                        d1 = &Blk(lp->listhead,Lelem)->lslots[n++];
                        d1->dword = D_List;
                        BlkLoc(*d1) = (union block *)tp;
                        }
               /*
                * Sort the resulting two-element list using the sorting
                *  function determined by i.
                */
               if (i == 1)
                  qsort((char *)Blk(lp->listhead,Lelem)->lslots, (int)size,
                        sizeof(struct descrip), (QSortFncCast)trefcmp);
               else
                  qsort((char *)Blk(lp->listhead,Lelem)->lslots, (int)size,
                        sizeof(struct descrip), (QSortFncCast)tvalcmp);
               break;		/* from cases 1 and 2 */
               }
            /*
             * Cases 3 and 4 were introduced in Version 5.10.
             */
               case 3 :
               case 4 :
                       {
            /*
             * The list resulting from the sort will have twice as many
             *  elements as the table has, so get that value and also make
             *  a valid list block size out of it.
             */
            size = BlkD(t,Table)->size * 2;

            /*
             * Point bp at the table header block of the table to be sorted
             *  and point lp at a newly allocated list
             *  that will hold the the result of sorting the table.
             */
            bp = (struct b_table *)BlkLoc(t);
            Protect(lp = alclist(size, size), runerr(0));

            /*
             * If the table is empty there's no need to sort anything.
             */
            if (size <= 0)
               break;

            /*
             * Point d1 at the start of the list elements in the new list
             * element block in preparation for use as an index into the list.
             */
            d1 = Blk(lp->listhead,Lelem)->lslots;
            /*
             * Traverse the element chain for each table bucket.  For each
             *  table element copy the the entry descriptor and the value
             *  descriptor into adjacent descriptors in the lslots array
             *  in the list element block.
             *  When this is done we now need to sort this list.
             */

            for (j = 0; j < HSegs && (seg = bp->hdir[j]) != NULL; j++)
               for (k = segsize[j] - 1; k >= 0; k--)
                  for (ep = seg->hslots[k];
		       BlkType(ep) == T_Telem;
		       ep = Blk(ep,Telem)->clink) {
                     *d1++ = Blk(ep,Telem)->tref;
                     *d1++ = Blk(ep,Telem)->tval;
                     }
            /*
             * Sort the resulting two-element list using the
             *  sorting function determined by i.
             */
            if (i == 3)
               qsort((char *)Blk(lp->listhead,Lelem)->lslots, (int)size / 2,
                     (2 * sizeof(struct descrip)),(QSortFncCast)trcmp3);
            else
               qsort((char *)Blk(lp->listhead,Lelem)->lslots, (int)size / 2,
                     (2 * sizeof(struct descrip)),(QSortFncCast)tvcmp4);
            break; /* from case 3 or 4 */
               }

            default: {
               irunerr(205, i);
               errorfail;
               }

            } /* end of switch statement */

            /*
             * Make result point at the sorted list.
             */

            Desc_EVValD(lp, E_Lcreate, D_List);
            return list(lp);
            }
         }

      default:
         runerr(115, t);		/* structure expected */
      }
end

/*
 * trefcmp(d1,d2) - compare two-element lists on first field.
 */

int trefcmp(d1,d2)
dptr d1, d2;
   {

#ifdef DeBug
   if (d1->dword != D_List || d2->dword != D_List)
      syserr("trefcmp: internal consistency check fails.");
#endif					/* DeBug */

   return (anycmp(&(Blk(BlkD(*d1,List)->listhead,Lelem)->lslots[0]),
                  &(Blk(BlkD(*d2,List)->listhead,Lelem)->lslots[0])));
   }

/*
 * tvalcmp(d1,d2) - compare two-element lists on second field.
 */

int tvalcmp(d1,d2)
dptr d1, d2;
   {

#ifdef DeBug
   if (d1->dword != D_List || d2->dword != D_List)
      syserr("tvalcmp: internal consistency check fails.");
#endif					/* DeBug */

   return (anycmp(&(Blk(BlkD(*d1,List)->listhead,Lelem)->lslots[1]),
      &(Blk(BlkD(*d2,List)->listhead,Lelem)->lslots[1])));
   }

/*
 * The following two routines are used to compare descriptor pairs in the
 *  experimental table sort.
 *
 * trcmp3(dp1,dp2)
 */

int trcmp3(dp1,dp2)
struct dpair *dp1,*dp2;
{
   return (anycmp(&((*dp1).dr),&((*dp2).dr)));
}
/*
 * tvcmp4(dp1,dp2)
 */

int tvcmp4(dp1,dp2)
struct dpair *dp1,*dp2;

   {
   return (anycmp(&((*dp1).dv),&((*dp2).dv)));
   }


"sortf(x,i) - sort list or set x on field i of each member"

function{1} sortf(t, i)
   type_case t of {
      list: {
         abstract {
            return type(t)
            }
         if !def:C_integer(i, 1) then
            runerr (101, i)
         body {
            register word size;
            extern word sort_field;

            if (i == 0) {
               irunerr(205, i);
               errorfail;
               }
            /*
             * Sort the list by copying it into a new list and then using
             *  qsort to sort the descriptors.  (That was easy!)
             */
            size = BlkD(t,List)->size;
            if (cplist(&t, &result, (word)1, size + 1) == Error)
               runerr(0);
            sort_field = i;
            qsort((char *)Blk(BlkD(result,List)->listhead,Lelem)->lslots,
               (int)size, sizeof(struct descrip),(QSortFncCast) nthcmp);

            Desc_EVValD(BlkLoc(result), E_Lcreate, D_List);
            return result;
            }
         }

      record: {
         abstract {
            return new list(any_value)
            }
         if !def:C_integer(i, 1) then
            runerr(101, i)
         body {
            register dptr d1;
            register word size;
            tended struct b_list *lp;
            union block *ep, *bp;
            register int j;
            extern word sort_field;

            if (i == 0) {
               irunerr(205, i);
               errorfail;
               }
            /*
             * Create a list the size of the record, copy each element into
             * the list, and then sort the list using qsort as in list
             * sorting and return the sorted list.
             */
            size = Blk(BlkD(t,Record)->recdesc,Proc)->nfields;

            Protect(lp = alclist_raw(size, size), runerr(0));

            bp = BlkLoc(t);  /* need not be tended if not set until now */

            if (size > 0) {  /* only need to sort non-empty records */
               d1 = Blk(lp->listhead,Lelem)->lslots;
               for (j = 0; j < size; j++)
                  *d1++ = Blk(bp,Record)->fields[j];
               sort_field = i;
               qsort((char *)Blk(lp->listhead,Lelem)->lslots,(int)size,
                  sizeof(struct descrip),(QSortFncCast)nthcmp);
               }

            Desc_EVValD(lp, E_Lcreate, D_List);
            return list(lp);
            }
         }

      set: {
         abstract {
            return new list(store[type(t).set_elem])
            }
         if !def:C_integer(i, 1) then
            runerr (101, i)
         body {
            register dptr d1;
            register word size;
            register int j, k;
            tended struct b_list *lp;
            union block *ep, *bp;
            register struct b_slots *seg;
            extern word sort_field;

            if (i == 0) {
               irunerr(205, i);
               errorfail;
               }
            /*
             * Create a list the size of the set, copy each element into
             * the list, and then sort the list using qsort as in list
             * sorting and return the sorted list.
             */
            size = BlkD(t,Set)->size;

            Protect(lp = alclist(size, size), runerr(0));

            bp = BlkLoc(t);  /* need not be tended if not set until now */

            if (size > 0) {  /* only need to sort non-empty sets */
               d1 = Blk(lp->listhead,Lelem)->lslots;
               for (j = 0; j < HSegs && (seg = BlkPH(bp,Table,hdir)[j]) != NULL; j++)
                  for (k = segsize[j] - 1; k >= 0; k--)
                     for (ep=seg->hslots[k];ep!=NULL;ep=BlkPE(ep,Telem,clink))
                        *d1++ = BlkPE(ep,Selem,setmem);
               sort_field = i;
               qsort((char *)Blk(lp->listhead,Lelem)->lslots,(int)size,
                     sizeof(struct descrip),(QSortFncCast)nthcmp);
               }

            Desc_EVValD(lp, E_Lcreate, D_List);
            return list(lp);
            }
         }

      default:
         runerr(125, t);	/* list, record, or set expected */
      }
end

/*
 * nthcmp(d1,d2) - compare two descriptors on their nth fields.
 */
word sort_field;		/* field number, set by sort function */
static dptr nth (dptr d);

int nthcmp(d1,d2)
dptr d1, d2;
   {
   int t1, t2, rv;
   dptr e1, e2;

   t1 = Type(*d1);
   t2 = Type(*d2);
   if (t1 == t2 && (t1 == T_Record || t1 == T_List)) {
      e1 = nth(d1);		/* get nth field, or NULL if none such */
      e2 = nth(d2);
      if (e1 == NULL) {
         if (e2 != NULL)
            return -1;		/* no-nth-field is < any nth field */
         }
      else if (e2 == NULL)
	 return 1;		/* any nth field is > no-nth-field */
      else {
	 /*
	  *  Both had an nth field.  If they're unequal, that decides.
	  */
         rv = anycmp(nth(d1), nth(d2));
         if (rv != 0)
            return rv;
         }
      }
   /*
    * Comparison of nth fields was either impossible or indecisive.
    *  Settle it by comparing the descriptors directly.
    */
   return anycmp(d1, d2);
   }

/*
 * nth(d) - return the nth field of d, if any.  (sort_field is "n".)
 */
static dptr nth(d)
dptr d;
   {
   union block *bp;
   struct b_list *lp;
   word i, j;
   dptr rv;

   rv = NULL;
   if (d->dword == D_Record) {
      /*
       * Find the nth field of a record.
       */
      bp = BlkLoc(*d);
      i =cvpos((long)sort_field,(long)(Blk(Blk(bp,Record)->recdesc,Proc)->nfields));
      if (i != CvtFail && i <= Blk(Blk(bp,Record)->recdesc,Proc)->nfields)
         rv = &Blk(bp,Record)->fields[i-1];
      }
   else if (d->dword == D_List) {
      /*
       * Find the nth element of a list.
       */
      lp = (struct b_list *)BlkLoc(*d);
      i = cvpos ((long)sort_field, (long)lp->size);
      if (i != CvtFail && i <= lp->size) {
         /*
          * Locate the correct list-element block.
          */
         bp = lp->listhead;
         j = 1;
         while (i >= j + Blk(bp,Lelem)->nused) {
            j += Blk(bp,Lelem)->nused;
            bp = Blk(bp,Lelem)->listnext;
            }
         /*
          * Locate the desired element.
          */
         i += Blk(bp,Lelem)->first - j;
         if (i >= Blk(bp,Lelem)->nslots)
            i -= Blk(bp,Lelem)->nslots;
         rv = &Blk(bp,Lelem)->lslots[i];
         }
      }
   return rv;
   }


"type(x) - return type of x as a string."

function{1} type(x)
   abstract {
      return string
      }
   type_case x of {
      string:   inline { return C_string "string";    }
      null:     inline { return C_string "null";      }
      integer:  inline { return C_string "integer";   }
      real:     inline { return C_string "real";      }
      cset:     inline { return C_string "cset";      }
      file:
	 inline {
#ifdef Graphics
	    if (BlkD(x,File)->status & Fs_Window)
	       return C_string "window";
#endif					/* Graphics */
	    return C_string "file";
	    }
      proc:     inline { return C_string "procedure"; }
      list:     inline { return C_string "list";      }
      table:    inline { return C_string "table";     }
      set:      inline { return C_string "set";       }
      record:   inline { return Blk(BlkD(x,Record)->recdesc,Proc)->recname; }
      coexpr:   inline { return C_string "co-expression"; }
#ifdef PatternType
      pattern:     inline { return C_string "pattern"; }
#endif					/* PatternType */

#ifdef EventMon
      tvmonitored:  
         body {
             if (is:string(*(VarLoc(BlkD(x,Tvmonitored)->tv))))
                return C_string "foreign-local-string";
             else switch(Type(*(VarLoc(BlkD(x,Tvmonitored)->tv)))) { 
                case T_Null:   { return C_string "foreign-local-null";     }
		case T_Integer:{ return C_string "foreign-local-integer";  }
                case T_Real:   { return C_string "foreign-local-real";     }
                case T_Cset:   { return C_string "foreign-local-cset";     }
                case T_File:   { return C_string "foreign-local-file";     }
                case T_Proc:   { return C_string "foreign-local-procedure";}
                case T_List:   { return C_string "foreign-local-list";     }
                case T_Table:  { return C_string "foreign-local-table";    }
                case T_Set:    { return C_string "foreign-local-set";      }
                case T_Record: { return C_string "foreign-local-record";   }
                case T_Coexpr: { return C_string "foreign-local-co-expression";}
		default:       { return C_string "foreign-local-??";       }
		}
	     fail; /* won't get here; this silences a bogus rtt warning */
             }
#endif					/* EventMon */
      default:
         inline {
#if !COMPILER
            if (!Qual(x) && (Type(x)==T_External)) {
               return C_string "external";
               }
            else
#endif					/* !COMPILER */
               runerr(123,x);
	    }
      }
end


"variable(s) - find the variable with name s and return a"
" variable descriptor which points to its value."

#ifdef MultiThread
function{0,1} variable(s,c,i,trap_local)
#else					/* MultiThread */
function{0,1} variable(s)
#endif					/* MultiThread */

   if !cnv:C_string(s) then
      runerr(103, s)

#ifdef MultiThread
   if !def:C_integer(i,0) then
      runerr(101,i)
   if !def:C_integer(trap_local,0) then
      runerr(101,trap_local)
#endif					/* MultiThread */

   abstract {
      return variable
      }

   body {
      register int rv;
#ifdef MultiThread
      struct progstate *prog, *savedprog;
      struct pf_marker *tmp_pfp;
      dptr tmp_argp;
#endif					/* MultiThread */
      CURTSTATE();

#ifdef MultiThread
      tmp_pfp = pfp;
      tmp_argp = glbl_argp;

      savedprog = curpstate;
      if (is:null(c)) c = k_current;
      else if (!is:coexpr(c)){
	 runerr(118, c);
	 }
      BlkD(k_current, Coexpr)->es_pfp = pfp; /* sync frame pointer */

      prog = BlkD(c,Coexpr)->program;
      pfp = BlkD(c,Coexpr)->es_pfp;
      glbl_argp = BlkD(c,Coexpr)->es_argp;
      ENTERPSTATE(prog);

      /*
       * Produce error if i is negative
       */
      if (i < 0) {
         irunerr(205, i);
         errorfail;
         }

      while (i--) {
	 if (pfp == NULL) {
	    pfp = tmp_pfp;
	    fail;
	    }
	 pfp = pfp->pf_pfp;
         }
      if (pfp)
      glbl_argp = &((dptr)pfp)[-(pfp->pf_nargs) - 1];
      else glbl_argp = NULL;
#endif						/* MultiThread */

      rv = getvar(s, &result);
   
#ifdef MultiThread
      if (is:coexpr(c)) {
	 ENTERPSTATE(savedprog);
	 pfp = tmp_pfp;
	 glbl_argp = tmp_argp;

	 if ((rv == LocalName) || (rv == StaticName)) {

#ifdef MonitoredTrappedVar
	    if (trap_local) {
               result.dword = D_Tvmonitored;
               VarLoc(result) = 
                  (dptr) alctvmonitored(&result, BlkD(c,Coexpr)->actv_count);
	       }
	    else
#endif                                         /* MonitoredTrappedVar */
            Deref(result);
	    }
	 }
#endif						/* MultiThread */

      if (rv != Failed)
         return result;
      else
         fail;
      }
end


"fieldnames(r) - generate the fieldnames of record r"

function{*} fieldnames(r)
   abstract {
      return string
      }
   if !is:record(r) then runerr(107,r)
   body {
      int i, sz = Blk(BlkD(r,Record)->recdesc,Proc)->nfields;
      for(i=0;i<sz;i++)
	 suspend Blk(BlkD(r,Record)->recdesc,Proc)->lnames[i];
      fail;
      }
end

#ifdef MultiThread

"cofail(CE) - transmit a co-expression failure to CE"

function{0,1} cofail(CE)
   abstract {
      return any_value
      }
   if is:null(CE) then
      body {
#ifdef CoExpr
	 struct b_coexpr *ce;
	 CURTSTATE();
	 ce = topact(BlkD(k_current,Coexpr));
	 if (ce != NULL) {
	    CE.dword = D_Coexpr;
	    BlkLoc(CE) = (union block *)ce;
	    }
	 else runerr(118,CE);
#else					/* CoExpr */
	runerr(118, CE);
#endif					/* CoExpr */
	 }
   else if !is:coexpr(CE) then
      runerr(118,CE)
   body {
      struct b_coexpr *ncp = BlkD(CE, Coexpr);
      if (co_chng(ncp, NULL, &result, A_Cofail, 1) == A_Cofail) fail;
      return result;
      }
end


"localnames(ce,i) - produce the names of local variables"
" in the procedure activation i levels up in ce"
function{*} localnames(ce,i)
   declare {
      tended struct descrip d;
      }
   abstract {
      return string
      }
   if is:null(ce) then inline {
      d = k_current;
      BlkD(k_current, Coexpr)->es_pfp = pfp; /* sync w/ current value */
      }
   else if is:proc(ce) then inline {
      int j;
      struct b_proc *cproc = BlkD(ce, Proc);
      for(j = 0; j < cproc->ndynam; j++) {
	 result = cproc->lnames[j + cproc->nparam];
	 suspend result;
         }
      fail;
      }
   else if is:coexpr(ce) then inline {
      d = ce;
      BlkD(k_current, Coexpr)->es_pfp = pfp; /* sync w/ current value */
      }
   else runerr(118, ce)
   if !def:C_integer(i,0) then
      runerr(101,i)
   body {
#if !COMPILER
      int j;
      dptr arg;
      struct b_proc *cproc;
      struct pf_marker *thePfp = BlkD(d,Coexpr)->es_pfp;

      if (thePfp == NULL) fail;
      
      /*
       * Produce error if i is negative
       */
      if (i < 0) {
         irunerr(205, i);
         errorfail;
         }

      while (i--) {
	 thePfp = thePfp->pf_pfp;
	 if (thePfp == NULL) fail;
         }

      arg = &((dptr)thePfp)[-(thePfp->pf_nargs) - 1];
      cproc = BlkD(arg[0], Proc);
      for(j = 0; j < cproc->ndynam; j++) {
	 result = cproc->lnames[j + cproc->nparam];
	 suspend result;
         }
#endif					/* !COMPILER */
      fail;
      }
end



"staticnames(ce,i) - produce the names of static variables"
" in the current procedure activation in ce"

function{*} staticnames(ce,i)
   declare {
      tended struct descrip d;
      }
   abstract {
      return string
      }
   if is:null(ce) then inline {
      d = k_current;
      BlkD(k_current, Coexpr)->es_pfp = pfp; /* sync w/ current value */
      }
   else if is:proc(ce) then inline {
      int j;
      struct b_proc *cproc = BlkD(ce, Proc);
      for(j = 0; j < cproc->nstatic; j++) {
	 result = cproc->lnames[j + cproc->nparam + cproc->ndynam];
	 suspend result;
         }
      fail;
      }
   else if is:coexpr(ce) then inline {
      d = ce;
      BlkD(k_current, Coexpr)->es_pfp = pfp; /* sync w/ current value */
      }
   else runerr(118,ce)
   if !def:C_integer(i,0) then
      runerr(101,i)
   body {
#if !COMPILER
      int j;
      dptr arg;
      struct b_proc *cproc;
      struct pf_marker *thePfp = BlkD(d,Coexpr)->es_pfp;
      if (thePfp == NULL) fail;

      /*
       * Produce error if i is negative
       */
      if (i < 0) {
         irunerr(205, i);
         errorfail;
         }

      while (i--) {
	 thePfp = thePfp->pf_pfp;
	 if (thePfp == NULL) fail;
         }

      arg = &((dptr)thePfp)[-(thePfp->pf_nargs) - 1];
      cproc = BlkD(arg[0], Proc);
      for(j=0; j < cproc->nstatic; j++) {
	 result = cproc->lnames[j + cproc->nparam + cproc->ndynam];
	 suspend result;
         }
#endif					/* !COMPILER */
      fail;
      }
end

"paramnames(ce,i) - produce the names of the parameters"
" in the current procedure activation in ce"

function{1,*} paramnames(ce,i)
   declare {
      tended struct descrip d;
      }
   abstract {
      return string
      }
   if is:null(ce) then inline {
      d = k_main;
      BlkD(k_main, Coexpr)->es_pfp = pfp; /* sync w/ current value */
      }
   else if is:proc(ce) then inline {
      int j;
      struct b_proc *cproc = BlkD(ce, Proc);
      /* do built-ins (nparam < 0) have readable parameter names? maybe not.*/
      for(j = 0; j < cproc->nparam; j++) {
	 result = cproc->lnames[j];
	 suspend result;
         }
      fail;
      }
   else if is:coexpr(ce) then inline {
      d = ce;
      BlkD(k_main, Coexpr)->es_pfp = pfp; /* sync w/ current value */
      }
   else runerr(118,ce)
   if !def:C_integer(i,0) then
      runerr(101,i)
   body {
#if !COMPILER
      int j;
      dptr arg;
      struct b_proc *cproc;
      struct pf_marker *thePfp = BlkD(d,Coexpr)->es_pfp;

      if (thePfp == NULL) fail;

      /*
       * Produce error if i is negative
       */
      if (i < 0) {
         irunerr(205, i);
         errorfail;
         }

      while (i--) {
	 thePfp = thePfp->pf_pfp;
	 if (thePfp == NULL) fail;
         }

      arg = &((dptr)thePfp)[-(thePfp->pf_nargs) - 1];
      cproc = BlkD(arg[0], Proc);
      for(j = 0; j < cproc->nparam; j++) {
	 result = cproc->lnames[j];
	 suspend result;
         }
#endif					/* !COMPILER */
      fail;
      }
end


"load(s,arglist,input,output,error,blocksize,stringsize,stacksize) - load"
" a program corresponding to string s as a co-expression."

function{1} load(s,arglist,infile,outfile,errfile,
		 blocksize, stringsize, stacksize)
   declare {
      tended char *loadstring;
      C_integer _bs_, _ss_, _stk_;
      }
   if !cnv:C_string(s,loadstring) then
      runerr(103,s)
   if !def:C_integer(blocksize,abrsize,_bs_) then
      runerr(101,blocksize)
   if !def:C_integer(stringsize,ssize,_ss_) then
      runerr(101,stringsize)
   if !def:C_integer(stacksize,mstksize,_stk_) then
      runerr(101,stacksize)
   abstract {
      return coexpr
      }
   body {
      word *stack_tmp;
      struct progstate *pstate;
      char sbuf1[MaxCvtLen], sbuf2[MaxCvtLen];
      register struct b_coexpr *sblkp;
      register struct b_refresh *rblkp;
      struct ef_marker *newefp;
      register dptr dp, ndp, dsp;
      register word *newsp, *savedsp;
      int na, nl, i, j, num_fileargs = 0;
      struct b_file *theInput = NULL, *theOutput = NULL, *theError = NULL;
      struct b_proc *cproc;
      extern char *prog_name;

      /*
       * Fragments of pseudo-icode to get loaded programs started,
       * and to handle termination.
       */
      static word pstart[7];
      static word *lterm;

      inst tipc;

      tipc.opnd = pstart;
      *tipc.op++ = Op_Noop; /* aligns Invokes operand */  /* ?cj? */
      *tipc.op++ = Op_Invoke;
      *tipc.opnd++ = 1;
      *tipc.op++ = Op_Coret;
      *tipc.op++ = Op_Efail;

      lterm = (word *)(tipc.op);

      *tipc.op++ = Op_Cofail;
      *tipc.op++ = Op_Agoto;
      *tipc.opnd = (word)lterm;

      prog_name = loadstring;			/* set up for &progname */

      /*
       * arglist must be a list
       */
      if (!is:null(arglist) && !is:list(arglist))
         runerr(108,arglist);

      /*
       * input, output, and error must be files
       */
      if (is:null(infile))
	 theInput = &(curpstate->K_input);
      else {
	 if (!is:file(infile))
	    runerr(105,infile);
	 else theInput = &(BlkLoc(infile)->File);
         }
      if (is:null(outfile))
	 theOutput = &(curpstate->K_output);
      else {
	 if (!is:file(outfile))
	    runerr(105,outfile);
	 else theOutput = &(BlkLoc(outfile)->File);
         }
      if (is:null(errfile))
	 theError = &(curpstate->K_errout);
      else {
	 if (!is:file(errfile))
	    runerr(105,errfile);
	 else theError = &(BlkLoc(errfile)->File); /* could check harder */
         }

      stack_tmp =
	(word *)(sblkp = loadicode(loadstring,theInput,theOutput,theError,
				   _bs_,_ss_,_stk_));
      if(!stack_tmp) {
	 fail;
         }
      pstate = sblkp->program;
      pstate->parent = curpstate;
      pstate->parentdesc = k_main;

      pstate->next = rootpstate.next;
      rootpstate.next = pstate;

      savedsp = sp;
      sp = stack_tmp + Wsizeof(struct b_coexpr)  + Wsizeof(struct progstate)
        + Wsizeof(struct threadstate) + pstate->hsize/WordSize;
      if (pstate->hsize % WordSize) sp++;

#ifdef UpStack
      sblkp->cstate[0] =
         ((word)((char *)sblkp + (mstksize - (sizeof(*sblkp)+sizeof(struct progstate)+
            sizeof(struct threadstate)+pstate->hsize))/2)
            &~((word)WordSize*StackAlign-1));
#else					/* UpStack */
      sblkp->cstate[0] =
	((word)((char *)sblkp + mstksize - WordSize + sizeof(struct progstate) +
           sizeof(struct threadstate) + pstate->hsize)
           &~((word)WordSize*StackAlign-1));
#endif					/* UpStack */

      sblkp->es_argp = NULL;
      sblkp->es_gfp = NULL;
      pstate->Mainhead->freshblk = nulldesc;/* &main has no refresh block. */
					/*  This really is a bug. */

      /*
       * Set up expression frame marker to contain execution of the
       *  main procedure.  If failure occurs in this context, control
       *  is transferred to lterm, the address of an ...
       */
      newefp = (struct ef_marker *)(sp+1);
#if IntBits != WordBits
      newefp->ef_failure.op = (int *)lterm;
#else					/* IntBits != WordBits */
      newefp->ef_failure.op = lterm;
#endif					/* IntBits != WordBits */

      newefp->ef_gfp = 0;
      newefp->ef_efp = 0;
      newefp->ef_ilevel = ilevel/*1*/;
      sp += Wsizeof(*newefp) - 1;
      sblkp->es_efp = newefp;

      /*
       * The first global variable holds the value of "main".  If it
       *  is not of type procedure, this is noted as run-time error 117.
       *  Otherwise, this value is pushed on the stack.
       */
      if (pstate->Globals[0].dword != D_Proc)
         fatalerr(117, NULL);

      PushDesc(pstate->Globals[0]);

      /*
       * Create a list from arguments using Ollist and push a descriptor
       * onto new stack.  Then create procedure frame on new stack.  Push
       * two new null descriptors, and set sblkp->es_sp when all finished.
       */
      if (!is:null(arglist)) {
         PushDesc(arglist);
	 pstate->tstate->Glbl_argp = (dptr)(sp - 1);
         }
      else {
         PushNull;
	 pstate->tstate->Glbl_argp = (dptr)(sp - 1);
         {
         dptr tmpargp = (dptr) (sp - 1);
         Ollist(0, tmpargp);
         sp = (word *)tmpargp + 1;
         }
         }
      sblkp->es_sp = (word *)sp;
      sblkp->es_ipc.opnd = pstart;

      result.dword = D_Coexpr;
      BlkLoc(result) = (union block *)sblkp;
      sp = savedsp;
      return result;
      }
end


"parent(ce) - given a ce, return &main for that ce's parent"

function{1} parent(ce)
   if is:null(ce) then inline {
      CURTSTATE();
      ce = k_current;
      }
   else if !is:coexpr(ce) then runerr(118,ce)
   abstract {
      return coexpr
      }
   body {
      if (BlkD(ce,Coexpr)->program->parent == NULL) fail;

      result.dword = D_Coexpr;
      BlkLoc(result) =
	(union block *)(BlkD(ce,Coexpr)->program->parent->Mainhead);
      return result;
      }
end

#ifdef MultiThread

"eventmask(ce,cs) - given a ce, get or set that program's event mask"

function{1} eventmask(ce,cs,vmask)
   if !is:coexpr(ce) then runerr(118,ce)
   if is:null(cs) && is:null(vmask) then {
      abstract {
         return cset++null
         }
      inline {
         return BlkD(ce,Coexpr)->program->eventmask;
         }
      }
   else if !cnv:cset(cs) then runerr(104,cs)
   else {
      abstract {
         return cset
         }
      body {
	 struct progstate *p = BlkD(ce,Coexpr)->program;
	 if (BlkLoc(cs) != BlkLoc(p->eventmask)) {
	    p->eventmask = cs;
	    assign_event_functions(p, cs);
	    }

	 if (!is:null(vmask)) {
            if (!is:table(vmask)) runerr(124,vmask);
	    BlkD(ce,Coexpr)->program->valuemask = vmask;
	    }
         return cs;
         }
      }
end
#endif					/* MultiThread */



"globalnames(ce) - produce the names of identifiers global to ce"

function{*} globalnames(ce)
#ifdef MultiThread
   declare {
      struct progstate *ps;
      }
#endif					/* MultiThread */
   abstract {
      return string
      }
#ifdef MultiThread
   if is:null(ce) then inline { ps = curpstate; }
   else if is:coexpr(ce) then
      inline { ps = BlkD(ce,Coexpr)->program; }
   else runerr(118,ce)
#else					/* MultiThread */
   if not (is:null(ce) || is:coexpr(ce)) runerr(118, ce)
#endif					/* MultiThread */
   body {
      struct descrip *dp;
#ifdef MultiThread
      for (dp = ps->Gnames; dp != ps->Egnames; dp++) {
#else					/* MultiThread */
      for (dp = gnames; dp != egnames; dp++) {
#endif					/* MultiThread */
         suspend *dp;
         }
      fail;
      }
end

"keyword(kname,ce,i) - produce a keyword in ce's thread"
function{*} keyword(keyname,ce,i)
   declare {
      tended struct descrip d;
      tended char *kyname;
      }
   abstract {
      return any_value
      }
   if !cnv:C_string(keyname,kyname) then runerr(103,keyname)
   if is:null(ce) then inline {
      d = k_current;
      }
   else if is:coexpr(ce) then
      inline { d = ce; }
   else runerr(118, ce)
   inline {
   BlkD(k_current, Coexpr)->es_pfp = pfp; /* sync w/ current value */
   BlkLoc(k_current)->Coexpr.es_ipc = ipc;
   }
   if !def:C_integer(i,0) then
      runerr(101,i)
   body {
#if 0
/*
 * Unfinished: change this gigantic chain of if (strcmp())... into
 * a switch statement that uses the stringint mechanism.
 */
static stringint siKeywords[] = {
   {0, 67},
#define KDef(p,n) {"p", n},
#include "../icont/keyword.h"
#include "../h/kdefs.h"
   };
#endif

      struct progstate *p = BlkD(d,Coexpr)->program;
      char *kname = kyname;
      if (kname[0] == '&') kname++;
      if (strcmp(kname,"allocated") == 0) {
	 int tot;
#ifdef Concurrent
	 pthread_mutex_lock(&p->mutex_stringtotal);
	 pthread_mutex_lock(&p->mutex_blocktotal);
	 tot =  stattotal + p->stringtotal + p->blocktotal;
	 pthread_mutex_unlock(&p->mutex_blocktotal);
	 pthread_mutex_unlock(&p->mutex_stringtotal);
	 suspend C_integer tot;

	 suspend C_integer stattotal;

	 pthread_mutex_lock(&p->mutex_stringtotal);
	 tot =  p->stringtotal;
	 pthread_mutex_unlock(&p->mutex_stringtotal);
	 suspend C_integer tot;

	 pthread_mutex_lock(&p->mutex_blocktotal);
	 tot =  p->blocktotal;
	 pthread_mutex_unlock(&p->mutex_blocktotal);
	 return C_integer tot;
#else					/* Concurrent */
	 suspend C_integer stattotal + p->stringtotal + p->blocktotal;
	 suspend C_integer stattotal;
	 suspend C_integer p->stringtotal;
	 return  C_integer p->blocktotal;
#endif					/* Concurrent */
	 }
      else if (strcmp(kname,"tallocated") == 0) {
#ifdef Concurrent
	 /*
	  * Preliminary version just reports space used in current regions.
	  */
	 suspend C_integer (curstring->free - curstring->base) +
	    (curblock->free - curblock->base);
	 suspend C_integer (curstring->free - curstring->base);
	 suspend C_integer (curblock->free - curblock->base);
#endif					/* Concurrent */
	 fail;
	 }
      else if (strcmp(kname,"collections") == 0) {
	 suspend C_integer p->colltot;
	 suspend C_integer p->collstat;
	 suspend C_integer p->collstr;
	 return  C_integer p->collblk;
	 }
      else if (strcmp(kname,"column") == 0) {
	 struct progstate *savedp = curpstate;
	 int col;
	 ENTERPSTATE(p);
	 col = findcol(BlkD(d,Coexpr)->es_ipc.opnd);
         if (col == 0){ /* fixing returned column zero */
	    col = findcol(BlkD(d,Coexpr)->es_oldipc.opnd);
            }
	 ENTERPSTATE(savedp);
	 return C_integer col;
	 }
      else if (strcmp(kname,"current") == 0) {
	 return p->tstate->K_current;
	 }
      else if (strcmp(kname,"error") == 0) {
	 return kywdint(&(p->Kywd_err));
	 }
      else if (strcmp(kname,"errornumber") == 0) {
	 return C_integer p->tstate->K_errornumber;
	 }
      else if (strcmp(kname,"errortext") == 0) {
	 return C_string p->tstate->K_errortext;
	 }
      else if (strcmp(kname,"errorvalue") == 0) {
	 return p->tstate->K_errorvalue;
	 }
      else if (strcmp(kname,"errout") == 0) {
	 return file(&(p->K_errout));
	 }
      else if (strcmp(kname,"eventcode") == 0) {
	 return kywdevent(&(p->eventcode));
	 }
      else if (strcmp(kname,"eventcount") == 0) {
	 return kywdevent(&(p->eventcount));
	 }
      else if (strcmp(kname,"eventsource") == 0) {
	 return kywdevent(&(p->eventsource));
	 }
      else if (strcmp(kname,"eventvalue") == 0) {
	 return kywdevent(&(p->eventval));
	 }
      else if (strcmp(kname,"file") == 0) {
	 struct progstate *savedp = curpstate;
	 struct descrip s;
         word * ipc_opnd;
         if (i > 0){
            ipc_opnd = findoldipc(BlkD(d,Coexpr),i);
	    ENTERPSTATE(p);
	    StrLoc(s) = findfile(ipc_opnd);
	    StrLen(s) = strlen(StrLoc(s));
            }
         else{
	    ENTERPSTATE(p);
	    StrLoc(s) = findfile(BlkD(d,Coexpr)->es_ipc.opnd);
	    StrLen(s) = strlen(StrLoc(s));
            } 
	 ENTERPSTATE(savedp);
	 if (!strcmp(StrLoc(s),"?")) fail;
	 return s;
	 }
      else if (strcmp(kname,"input") == 0) {
	 return file(&(p->K_input));
	 }
      else if (strcmp(kname,"level") == 0) {
	 /*
	  * Shouldn't &level be per co-expression, not per program?
	  */
	 return C_integer p->tstate->K_level;
	 }
      else if (strcmp(kname,"line") == 0) {
	 struct progstate *savedp = curpstate;
	 int ln;
         word * ipc_opnd;
         if (i > 0){
            ipc_opnd = findoldipc(BlkD(d,Coexpr),i);
	    ENTERPSTATE(p);
            ln = findline(ipc_opnd);
            }
         else{
	    ENTERPSTATE(p);
	    ln = findline(BlkD(d,Coexpr)->es_ipc.opnd);
            if (ln == 0){ /* fixing returned line zero */
	       ln = findline(BlkD(d,Coexpr)->es_oldipc.opnd);
               }
            }  
	 ENTERPSTATE(savedp);
	 return C_integer ln;
	 }
      else if (strcmp(kname,"syntax") == 0) {
         struct progstate *savedp = curpstate;
	 int syn;
	 ENTERPSTATE(p);
	 syn = findsyntax(BlkD(d,Coexpr)->es_ipc.opnd);
	 ENTERPSTATE(savedp);
	 return C_integer syn;
         } 
      else if (strcmp(kname,"main") == 0) {
	 return p->K_main;
	 }
      else if (strcmp(kname,"output") == 0) {
	 return file(&(p->K_output));
	 }
      else if (strcmp(kname,"pos") == 0) {
	 return kywdpos(&(p->tstate->Kywd_pos));
	 }
      else if (strcmp(kname,"progname") == 0) {
	 return kywdstr(&(p->Kywd_prog));
	 }
      else if (strcmp(kname,"random") == 0) {
	 return kywdint(&(p->tstate->Kywd_ran));
	 }
      else if (strcmp(kname,"regions") == 0) {
         word allRegions = 0;
         struct region *rp;

         suspend C_integer 0;
	 for (rp = p->stringregion; rp; rp = rp->next)
	    allRegions += DiffPtrs(rp->end,rp->base);
	 for (rp = p->stringregion->prev; rp; rp = rp->prev)
	    allRegions += DiffPtrs(rp->end,rp->base);
	 suspend C_integer allRegions;

	 allRegions = 0;
	 for (rp = p->blockregion; rp; rp = rp->next)
	    allRegions += DiffPtrs(rp->end,rp->base);
	 for (rp = p->blockregion->prev; rp; rp = rp->prev)
	    allRegions += DiffPtrs(rp->end,rp->base);
	 return C_integer allRegions;
	 }
      else if (strcmp(kname,"source") == 0) {
#ifdef CoExpr
	 return coexpr(topact(
			   BlkD(BlkD(d,Coexpr)->program->tstate->K_current,Coexpr)));
#else					/* CoExpr */
	fail;
#endif					/* CoExpr */
/*
	 if (BlkLoc(d)->coexpr.es_actstk)
	    return coexpr(topact((struct b_coexpr *)BlkLoc(d)));
	 else return BlkLoc(d)->coexpr.program->parent->K_main;
*/
	 }
      else if (strcmp(kname,"storage") == 0) {
	 word allRegions = 0;
	 struct region *rp;
	 suspend C_integer 0;
	 for (rp = p->stringregion; rp; rp = rp->next)
	    allRegions += DiffPtrs(rp->free,rp->base);
	 for (rp = p->stringregion->prev; rp; rp = rp->prev)
	    allRegions += DiffPtrs(rp->free,rp->base);
	 suspend C_integer allRegions;

	 allRegions = 0;
	 for (rp = p->blockregion; rp; rp = rp->next)
	    allRegions += DiffPtrs(rp->free,rp->base);
	 for (rp = p->blockregion->prev; rp; rp = rp->prev)
	    allRegions += DiffPtrs(rp->free,rp->base);
	 return C_integer allRegions;
	 }
      else if (strcmp(kname,"subject") == 0) {
	 return kywdsubj(&(p->tstate->ksub));
	 }
      else if (strcmp(kname,"time") == 0) {
	 /*
	  * &time in this program = total time - time spent in other programs
	  */
	 if (p != curpstate)
	    return C_integer p->Kywd_time_out - p->Kywd_time_elsewhere;
	 else
	    return C_integer millisec() - p->Kywd_time_elsewhere;
	 }
      else if (strcmp(kname,"trace") == 0) {
	 return kywdint(&(p->Kywd_trc));
	 }
#ifdef Graphics
      else if (strcmp(kname,"window") == 0) {
	 return kywdwin(&(p->Kywd_xwin[XKey_Window]));
	 }
      else if (strcmp(kname,"col") == 0) {
	 return kywdint(&(p->AmperCol));
	 }
      else if (strcmp(kname,"row") == 0) {
	 return kywdint(&(p->AmperRow));
	 }
      else if (strcmp(kname,"x") == 0) {
	 return kywdint(&(p->AmperX));
	 }
      else if (strcmp(kname,"y") == 0) {
	 return kywdint(&(p->AmperY));
	 }
      else if (strcmp(kname,"interval") == 0) {
	 return kywdint(&(p->AmperInterval));
	 }
      else if (strcmp(kname,"control") == 0) {
	 if (p->Xmod_Control)
	    return nulldesc;
	 else
	     fail;
	 }
      else if (strcmp(kname,"shift") == 0) {
	 if (p->Xmod_Shift)
	    return nulldesc;
	 else
	     fail;
	 }
      else if (strcmp(kname,"meta") == 0) {
	 if (p->Xmod_Meta)
	    return nulldesc;
	 else
	     fail;
	 }
#endif					/* Graphics */
      runerr(205, keyname);
      }
end

"structure(x) -- generate all structures allocated in program x"
function {*} structure(x)

   if !is:coexpr(x) then
       runerr(118, x)

   abstract {
      return list ++ set ++ table ++ record
      }

   body {
      tended char *bp;
      char *free;
      tended struct descrip descr;
      word type;
      struct region *theregion, *rp;

#ifdef MultiThread
      theregion = BlkD(x,Coexpr)->program->blockregion;
#else
      theregion = curblock;
#endif
      for(rp = theregion; rp; rp = rp->next) {
	 bp = rp->base;
	 free = rp->free;
	 while (bp < free) {
	    type = BlkType(bp);
	    switch (type) {
            case T_List:
            case T_Set:
            case T_Table:
            case T_Record: {
               BlkLoc(descr) = (union block *)bp;
               descr.dword = type | F_Ptr | D_Typecode;
               suspend descr;
               }
	       }
	    bp += BlkSize(bp);
	    }
	 }
      for(rp = theregion->prev; rp; rp = rp->prev) {
	 bp = rp->base;
	 free = rp->free;
	 while (bp < free) {
	    type = BlkType(bp);
	    switch (type) {
            case T_List:
            case T_Set:
            case T_Table:
            case T_Record: {
               BlkLoc(descr) = (union block *)bp;
               descr.dword = type | F_Ptr | D_Typecode;
               suspend descr;
               }
	       }
	    bp += BlkSize(bp);
	    }
	 }
      fail;
      }
end


#endif					/* MultiThread */

#ifdef Concurrent

pthread_cond_t* condvars;
int* condvarsmtxs;
int maxcondvars;
int ncondvars; 


pthread_mutex_t* mutexes;
int maxmutexes;
int nmutexes; 


"condvar(x) - create and initialize a condition variable. x is the mutex to be used with it"

function{1} condvar(x)
   if !cnv:C_integer(x) then
      runerr(101, x)
   body{
         if (x<1 || x>nmutexes)
	  irunerr(101, x);

	MUTEX_LOCKID(MTX_CONDVARS);
	if(ncondvars==maxcondvars){
	   maxcondvars = maxcondvars * 2 + 64;
	   condvars=realloc(condvars, maxcondvars * sizeof(pthread_cond_t));
	   condvarsmtxs=realloc(condvarsmtxs, maxcondvars * sizeof(int));
	   if (condvars==NULL || condvarsmtxs==NULL)
	     syserr("out of memory for condition variables!");
  	   }
	pthread_cond_init(condvars+ncondvars, NULL);
	condvarsmtxs[ncondvars]=x-1;
        ncondvars++;
        MUTEX_UNLOCKID(MTX_CONDVARS);
	return C_integer ncondvars;
      }
end

"condwait(x) - wait on condition variable x"

function{1} condwait(x)
   if !cnv:C_integer(x) then
      runerr(101, x)
   abstract { return integer}
   body {
      int rv;
      if (x<1 || x>ncondvars)
      	 irunerr(101, x);

      MUTEX_LOCKID(MTX_NARTHREADS); 
      NARthreads--;	
      MUTEX_UNLOCKID(MTX_NARTHREADS);

      if (rv=pthread_cond_wait(condvars+x-1, &mutexes[condvarsmtxs[x-1]]) != 0){
      	 fprintf(stderr, "condition variable wait failure %d\n", rv);
      	 exit(-1);
      	 }

      MUTEX_LOCKID(MTX_GCTHREAD);
      MUTEX_LOCKID(MTX_NARTHREADS); 
      NARthreads++;	
      MUTEX_UNLOCKID(MTX_NARTHREADS);
      MUTEX_UNLOCKID(MTX_GCTHREAD);

      return C_integer 1;
      }
end

"condsignal(x, y) - signal the condition variable x y times. Default y is 1, y=0 means broadcast"

function{1} condsignal(x, y)
   declare { int Y=0;}
   if !cnv:C_integer(x) then
      runerr(101, x)
      if is:null(y) then
	inline { Y = 1; }
      else if !cnv:C_integer(y) then
	 inline { Y = y; }
      else
	runerr(101, y)
   
   abstract { return integer}
   body {
      int rv, i;
      if (x<1 || x>ncondvars)
      	 irunerr(101, x);
      	 
      if (Y == 0) {
	 if ((rv=pthread_cond_broadcast(condvars+x-1)) != 0) {
	    }
	 }
      else
      for (i=0; i < Y; i++)
      if ((rv=pthread_cond_signal(condvars+x-1)) != 0){
      	 syserr("condition variable wait failure %d\n", rv);
      	 exit(-1);
      	 }
      return C_integer 1;
      }
end


"mutex(x) - create and initialize a mutex. To be extended later to allow for naming mutexes."

function{1} mutex(x)
   abstract { return integer }
   body{
	MUTEX_LOCKID(MTX_MUTEXES);
	if(nmutexes==maxmutexes){
	   maxmutexes = maxmutexes * 2 + 64;
	   mutexes=realloc(mutexes, maxmutexes * sizeof(pthread_mutex_t));
	   if (mutexes==NULL)
	     syserr("out of memory for mutexes!");
  	   }
	pthread_mutex_init(mutexes+nmutexes, NULL);
        nmutexes++;
	MUTEX_UNLOCKID(MTX_MUTEXES);
	return C_integer nmutexes;
      }
end

"lock(x) - lock mutex x"

function{1} lock(x)
   if !cnv:C_integer(x) then
      runerr(101, x)
   abstract { return integer}
   body {
      int rv;
      if (x<1 || x>nmutexes)
      	 irunerr(101, x);

      /*
       * The following code was modified o avoid extra locking to accomodate GC
       * There might be better ways to do this.
       */
      if ((rv=pthread_mutex_trylock(mutexes+x-1)) == 0)
      	 return C_integer 1;
      else if (rv!=EBUSY)
	fprintf(stderr, "pthread lock failure %d\n", rv);

      MUTEX_LOCKID(MTX_NARTHREADS); 
      NARthreads--;	
      MUTEX_UNLOCKID(MTX_NARTHREADS);

      if ((rv=pthread_mutex_lock(mutexes+x-1)) != 0) {
	 fprintf(stderr, "pthread lock failure %d\n", rv);
	 exit(-1);
	 }

      MUTEX_LOCKID(MTX_GCTHREAD);
      MUTEX_LOCKID(MTX_NARTHREADS); 
      NARthreads++;	
      MUTEX_UNLOCKID(MTX_NARTHREADS);
      MUTEX_UNLOCKID(MTX_GCTHREAD);

      return C_integer 1;
      }
end

"trylock(x) - try locking mutex x"

function{1} trylock(x)
   if !cnv:C_integer(x) then
      runerr(101, x)
   abstract { return integer}
   body {
      int rv;
      if (x<1 || x>nmutexes)
      	 irunerr(101, x);

      if ((rv=pthread_mutex_trylock(mutexes+x-1)) == 0)
      	 return C_integer 1;
      else if (rv==EBUSY)
	fail;
      else
	fprintf(stderr, "pthread lock failure %d\n", rv);
      fail;
      } 
end

"unlock(x) - unlock mutex x"

function{1} unlock(x)
   if !cnv:C_integer(x) then
      runerr(101, x)
   abstract { return integer}
   body{
      int rv;
      if (x<1 || x>nmutexes)
      	 irunerr(101, x);
      if ((rv=pthread_mutex_unlock(mutexes+x-1)) != 0) {
	 fprintf(stderr, "pthread unlock failure %d\n", rv);
	 exit(-1);
	 }
      return C_integer 1;
      }
end

"join(x) - join with thread x"

function{1} join(x)
  if is:coexpr(x) then {
     abstract { return coexpr }
     body {
	struct context *n;
	int rv;
	/*if (BlkLoc(x)->Coexpr.status & Ts_Async){*/
	n =  (struct context *)  BlkLoc(x)->Coexpr.cstate[1];
	MUTEX_LOCKID(MTX_NARTHREADS); 
	NARthreads--;	
	MUTEX_UNLOCKID(MTX_NARTHREADS);
	if ((rv=pthread_join(n->thread, NULL)) != 0) {
	   fprintf(stderr, "pthread join failure %d\n", rv);
	   exit(-1);
	   }
	/*}*/
        MUTEX_LOCKID(MTX_GCTHREAD);
	MUTEX_LOCKID(MTX_NARTHREADS); 
	NARthreads++;	
	MUTEX_UNLOCKID(MTX_NARTHREADS);
	MUTEX_UNLOCKID(MTX_GCTHREAD);
	return x;
	}
     }
  else { runerr(106,x)
     }
end

"thread(x) - execute a concurrent thread that evaluates procedure x"

function{1} thread(x)
  if is:coexpr(x) then {
     abstract { return coexpr }
     body {
	struct context *n;
	struct b_coexpr *cp = BlkD(x, Coexpr);
	int i;
	/* Make sure it is a pthreads-based co-expression. */
	if (cp->status & Ts_Native) runerr(101,x);
	if (cp->status & Ts_Async) return x;
	/* initialize sender/receiver queues */
	pthread_mutex_init(&(cp->smute), NULL);
	pthread_mutex_init(&(cp->rmute), NULL);
	cp->squeue = (union block *)alclist(0, MinListSlots);
	cp->rqueue = (union block *)alclist(0, MinListSlots);
	/* Transmit whatever is needed to wake it up. */
	n = (struct context *) cp->cstate[1];
	do{
	  i=pthread_mutex_trylock(&static_mutexes[MTX_GCTHREAD]);
	  if (i==EBUSY){
	     /* check to see if another thread and have already requested a GC.
	      * OR another thread is in a critical region and locked MTX_GCthread
	      */
	      if (thread_call)
		thread_control(GC_GOTOSLEEP); /* I'm part of the GC party now! Sleeping!!*/
	      else
		idelay(1);
	    }
	  else if (i) syserr("Mutex Disaster in GCthread mutex in thread()");
	} while (i); /* keep looping until I aquire the mutex*/
	if (n->alive == 0) {
	   /* activate thread x for the first time */

	   if ( pthread_create(&(n->thread), NULL, nctramp, n) != 0 )
	      syserr("cannot create thread");
	   }

	/* Turn on Async flag */
	cp->status = Ts_Posix | Ts_Async;

	/* activate co-expression x, having changed it to Asynchronous */
	sem_post(n->semp);
	/* inrement the counter of the Async running threads*/
	MUTEX_LOCKID(MTX_NARTHREADS); 
	NARthreads++;	
	MUTEX_UNLOCKID(MTX_NARTHREADS);
	MUTEX_UNLOCKID(MTX_GCTHREAD);

	return x;
	}
     }
  else if is:proc(x) then {
     abstract { return coexpr }
     body {
	tended struct descrip d;
	d = nulldesc;
	/*
	 * Create a thread, similar to creating a (pthreads-based)
	 * co-expression, except with the Cs_Concurrent flag on.
	 * Build the icode to call Invoke on procedure x.
	 */
	return d;
	}
     }
  else { runerr(106,x)
     }
end
#endif					/* Concurrent */
