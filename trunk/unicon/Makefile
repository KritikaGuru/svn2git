#  Top Level Makefile for Unicon
#

#  configuration parameters
VERSION=13.1
name=unspecified
REPO_REV="$(shell LC_ALL=C svnversion -cn . | sed -e "s/.*://" -e "s/\([0-9]*\).*/\1/" | grep "[0-9]" )"

SHELL=sh
SHTOOL=./shtool
prefix=/usr/local
exec_prefix=${prefix}
bindir=${exec_prefix}/bin
libdir=${exec_prefix}/lib
docdir=${prefix}/share/doc/${PACKAGE_TARNAME}
mandir=${prefix}/share/man

PATCHSTR=./bin/patchstr

default: allsrc
	$(MAKE) -C ipl/lib 
	$(MAKE) -C uni 


.PHONY: plugins

Makedefs: Makedefs.in configure
	sh configure

#
# if you make any changes to configure.ac or aclocal.m4 run  autoreconf -i
#
#configure: configure.ac aclocal.m4
#	autoreconf -i

config: configure
	sh configure	

help:
	@echo
	@echo Unicon Build Instructions:
	@echo
	@echo Platform
	@echo "  UNIX:" 
	@echo "      Run \"./configure\""
	@echo
	@echo "  Windows:"
	@echo "      MSVC: Run \"nmake NT-Configure\" or \"nmake W-Configure\"."
	@echo "      GCC : Run \"make NT-Configure-GCC\" or \"make W-Configure-GCC\"."
	@echo "            For a fully-automated build Run \"make WUnicon\" ."
	@echo "            Autoconf:"
	@echo "            sh configure --build=i686-w64-mingw32 when building 32-bit" 
	@echo "            sh configure --build=x86_64-w64-mingw32 when building 64-bit"
	@echo ""
	@echo "All: after configuration, run \"make (or nmake) Unicon\"."
	@echo

##################################################################
#
# Default targets.

All:	Icont Ilib Ibin

allsrc: Makedefs update_rev
	$(MAKE) -C src


config/unix/$(name)/status src/h/define.h:
	:
	: To configure Unicon, run either
	:
	:	make Configure name=xxxx     [for no graphics]
	: or	make X-Configure name=xxxx   [with X-Windows graphics]
	:
	: where xxxx is one of
	:
	@cd config/unix; ls -d [a-z]*
	:
	@exit 1

##################################################################
#
# Code configuration.
#
# $Id: top.mak,v 1.30 2010-05-06 23:13:56 jeffery Exp $

# needed especially for MacOS
.PHONY: Configure

# Configure the code for a specific system.

Configure:
		./configure --disable-graphics

X-Configure:
		./configure


Thin-Configure:
		./configure --enable-thin


Thin-X-Configure:
		./configure --enable-thinx

V-Configure:	config/unix/$(name)/status
		$(MAKE) Pure >/dev/null
		-cd src/lib/voice; $(MAKE)
		cd config/unix; $(MAKE) Setup-NoGraphics name=$(name)
		sh ./configure --disable-graphics CFLAGS=$(CFLAGS) LDFLAGS=$(LDFLAGS)

VX-Configure:	config/unix/$(name)/status
		$(MAKE) Pure >/dev/null
		-cd src/lib/voice; $(MAKE)
		cd config/unix; $(MAKE) Setup-Graphics name=$(name)
		sh ./configure CFLAGS=$(CFLAGS) LDFLAGS=$(LDFLAGS)
		@echo Remember to add unicon/bin to your path

WUnicon32:
	sh configure --host=i686-w64-mingw32 --disable-iconc

WUnicon64:
	sh configure --build=x86_64-w64-mingw32 --disable-iconc

WUnicon:
	@echo Reloading the Makefile from config/win32/gcc/makefile.top
	cp config/win32/gcc/makefile.top Makefile
	@echo Done.
	@echo
	@echo Ready to build Windows Unicon
	@echo Make sure the Unicon bin directory is in your path before continuing, then run:
	@echo
	@echo "   - " \"make WUnicon32\" for a 32-bit build, or
	@echo "   - " \"make WUnicon64\" for a 64-bit build - requires MinGW64.
	@echo

NT-Configure:
		cmd /C "cd config\win32\msvc && config"
		@echo Now remember to add unicon/bin to your path

W-Configure:
		cmd /C "cd config\win32\msvc && w-config"
		@echo Now remember to add unicon/bin to your path

W-Configure-GCC:
		cd config/win32/gcc && sh w-config.sh
		@echo Now remember to add unicon/bin to your path
		@echo Then run "make Unicon" to build

NT-Configure-GCC:
		cd config/win32/gcc && sh config.sh
		@echo Now remember to add unicon/bin to your path
		@echo Then run "make Unicon" to build

##################################################################
# 
# This is used utilize the ncurses-based tool to build Unicon
# make build name=xxxx

build:
	if test "$(TERM)" = "dumb" ; then \
		echo "No building on dumb terminals, use make Configure"; \
	elif [ -f /usr/lib/libcurses.so ] ; then \
		gcc src/common/build.c -lcurses -o build; \
		./build $(name) ; \
		rm build; \
	elif [ -f /usr/include/curses.h ] ; then \
		gcc src/common/build.c -lncurses -o build; \
		./build $(name) ; \
		rm build; \
	else \
		make Configure name=$(name); \
		echo "No curses library was found for 'build', used 'make Configure name=$(name)'"; \
		echo "If you want X11 graphics, run 'make X-Configure name=$(name)'"; \
	fi

##################################################################
# Get the status information for a specific system.

Status:
		@cat config/unix/$(name)/status

##################################################################
#
# Compilation and installation.


# The OO translator. Add a line for uni/iyacc if you modify the Unicon grammar

Unicon:		Icont
		cd ipl/lib; $(MAKE)
		cd uni ; $(MAKE)

# The interpreter: icont and iconx.

Icont bin/icont:
		$(MAKE) -C src Icont

# The compiler: rtt, the run-time system, and iconc.

Iconc Uniconc bin/iconc:
		$(MAKE) -C src Iconc

# Common components.

Common:
		$(MAKE) -C src Common

# The Icon program library.

Ilib:		bin/icont
		$(MAKE) -C ipl

Ibin:		bin/icont
		$(MAKE) -C ipl Ibin

# Common components.

plugins:
		$(MAKE) -C plugins

##################################################################
#
# Installation and packaging.


# Installation:  "make Install dest=new-parent-directory"
ULROT=$(DESTDIR)$(libdir)/unicon
ULB=$(ULROT)/uni
UIPL=$(ULROT)/ipl
UPLUGINS=$(ULROT)/plugins/lib
INST=$(SHTOOL) install -c
F=*.{u,icn}
Tbins=unicon icont iconx iconc udb uprof unidep UniDoc ui ivib patchstr

Tdirs=$(ULB) $(UIPL) $(UPLUGINS)
Udirs=lib 3d gui unidoc unidep xml parser
IPLdirs=lib incl gincl mincl

uninstall Uninstall:
#	be conservative when deleting directories
	@for d in $(ULROT) $(docdir)/unicon ; do \
	   echo "Uninstalling dir $$d ..."; \
	   rm -rf $$d; \
	done
#	delete the binaries we installed from  unicon/bin
	@for f in $(Tbins); do \
	   echo "Uninstalling $(bindir)/$$f ..."; \
	   rm -f $(bindir)/$$f; \
	done
#	docs and man
	@echo "Uninstalling $(mandir)/man1/unicon.1 ..."
	@rm -f $(mandir)/man1/unicon.1

install Install:
#	create all directories first
	@for d in $(DESTDIR)$(bindir) $(DESTDIR)$(libdir) $(DESTDIR)$(docdir)/unicon $(DESTDIR)$(mandir) $(Tdirs) ; do \
	    (echo "Creating dir $$d") && (mkdir -p $$d); \
	done
	@for d in $(IPLdirs); do \
	    (echo "Creating dir $(UIPL)/$$d") && (mkdir -p $(UIPL)/$$d); \
	done
	@for d in $(Udirs); do \
	    (echo "Creating dir $(ULB)/$$d") && (mkdir -p $(ULB)/$$d); \
	done
#	install unicon/bin
	@for f in $(Tbins); do \
	  if test -f "bin/$$f"; then \
	    (echo "Installing bin/$$f") && ($(INST) bin/$$f $(DESTDIR)$(bindir)); \
	    if test "$$f" != "patchstr" ; then \
              $(PATCHSTR) -DPatchStringHere $(DESTDIR)$(bindir)/$$f $(bindir) || true; \
              $(PATCHSTR) -DPatchUnirotHere $(DESTDIR)$(bindir)/$$f $(ULROT) || true;  \
            fi; \
	  fi; \
	done
#	install unicon/ipl
	@echo "Installing unicon/ipl to $(UIPL) ..."
	@$(INST) -m 644 ipl/lib/*.u $(UIPL)/lib
	@$(INST) -m 644 ipl/incl/*.icn $(UIPL)/incl
	@$(INST) -m 644 ipl/gincl/*.icn $(UIPL)/gincl
	@$(INST) -m 644 ipl/mincl/*.icn $(UIPL)/mincl
#	install unicon/uni
	@for d in $(Udirs); do \
	  echo "Installing uni/$$d to $(ULB)/$$d ..."; \
	  $(INST) -m 644 uni/$$d/*.* $(ULB)/$$d; \
	done
#	docs and man
	@echo "Installing $(mandir)/man1/unicon.1 and $(docdir)/unicon ..."
#	@$(INST) -m 644 doc/unicon/unicon.1 $(DESTDIR)$(mandir)/man1
	@$(INST) -m 644 README $(DESTDIR)$(docdir)/unicon
#	@$(INST) -m 644 doc/unicon/*.* $(DESTDIR)$(docdir)/unicon

# Bundle up for binary distribution.

DIR=unicon.$(VERSION)
Package:
		rm -rf $(DIR)
		umask 002; $(MAKE) Install dest=$(DIR)
		tar cf - unicon.$(VERSION) | gzip -9 >unicon.$(VERSION).tgz
		rm -rf $(DIR)

distclean2: clean
	@for d in $(SUBDIRS); do \
	  if test "$$d" != "."; then \
	    (cd $$d && $(MAKE) $@); \
	  fi; \
	done
	$(RM) Makefile config.status config.cache config.log

#Makefile: Makefile.in config.status
#	cd $(top_srcdir) && $(SHELL) ./config.status

#config.status: $(srcdir)/configure 
#	$(SHELL) ./config.status --recheck

update_rev:
	@if test ! -z $(REPO_REV) ; then \
	   echo "#define REPO_REVISION \"$(REPO_REV)\"" > src/h/revision.h; \
	fi

VV=13.1.0
FV1=unicon-$(VV).tar.gz
FV2=unicon_$(VV).orig.tar.gz
dist: distclean update_rev
#	$(SHTOOL) fixperm -v *;
	echo "Building $(FV1)"
	tar -czf ../$(FV1) --exclude-vcs --exclude-backups ../unicon
#	$(SHTOOL) tarball -o $(FV1) -c 'gzip -9' \
#                          -e '\.svn,\.[oau]$$,\.core$$,~$$,^\.#,#*#,*~', . uni/unicon/unigram.u uni/unicon/idol.u

publishdist: dist
	scp ../$(FV1) web.sf.net:/home/project-web/unicon/htdocs/dist/uniconsrc-nightly.tar.gz

udist=unicondist
deb: dist
	mkdir -p ../$(udist)
	mv ../$(FV1) ../$(udist)/
	cp ../$(udist)/$(FV1) ../$(udist)/$(FV2)
	@echo unpacking ../$(udist)/$(FV1)
	cd ../$(udist) && tar -xf $(FV1)
	mv ../$(udist)/unicon ../$(udist)/unicon-$(VV)
	@echo "To finish building the deb package, do"
	@echo "   cd ../unicondist/unicon-$(VV)"
	@echo "Then run:"
	@echo "	 debuild -us -uc"

debauto: deb
	cd ../unicondist/unicon-$(VV) && debuild -us -uc
	@echo "  Did we get : ../unicondist/unicon-$(VV).deb"

##################################################################
#
# Tests.

Test    Test-icont:	; cd tests; $(MAKE) Test
Samples Samples-icont:	; cd tests; $(MAKE) Samples

Test-iconc:		; cd tests; $(MAKE) Test-iconc
Samples-iconc:		; cd tests; $(MAKE) Samples-iconc


#################################################################
#
# Run benchmarks.

Benchmark:
		$(MAKE) Benchmark-icont

Benchmark-iconc:
		cd tests/bench;		$(MAKE) benchmark-iconc

Benchmark-icont:
		cd tests/bench;		$(MAKE) benchmark-icont


##################################################################
#
# Clean-up.
#
# "make Clean" removes intermediate files, leaving executables and library.
# "make Pure"  also removes binaries, library, and configured files.

clean Clean:
		touch Makedefs Makedefs.uni
		rm -rf icon.*
		cd src;			$(MAKE) Clean
		cd tests;		$(MAKE) Clean
		cd plugins;		$(MAKE) Clean

distclean Pure:
		touch Makedefs Makedefs.uni
		rm -rf icon.* bin/[A-Za-z]* lib/[a-z]*
		cd uni;			$(MAKE) Pure
		cd ipl;			$(MAKE) Pure
		cd src;			$(MAKE) Pure
		cd tests;		$(MAKE) Pure
		cd plugins;		$(MAKE) Pure
		rm -f src/common/rswitch.[csS]
#		rm -f Makedefs Makedefs.uni
		$(RM) config.status config.cache config.log

#		rm -f \#*# *~ .#*
#		rm -f */#*# */*~ */.#*
#		rm -f */*/#*# */*/*~ */*/.#*
#		rm -f */*/*/#*# */*/*/*~ */*/*/.#*

#  (This is used at Arizona to prepare source distributions.)

Dist-Clean:
		rm -rf `find * -type d -name CVS`
		rm -f `find * -type f | xargs grep -l '<<ARIZONA-[O]NLY>>'`
