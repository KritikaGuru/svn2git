#  Top Level Makefile for Unicon
#

#  configuration parameters
VERSION=13.1
name=unspecified

prefix=/usr/local
exec_prefix=${prefix}
bindir=${exec_prefix}/bin
libdir=${exec_prefix}/lib
docdir=${prefix}/share/doc/${PACKAGE_TARNAME}
mandir=${prefix}/share/man

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
	@echo Start by adding the Unicon bin directory to your path.
	@echo
	@echo Platform
	@echo "  UNIX:" 
	@echo "      Run \"./configure\""
	@echo
	@echo "  Windows:"
	@echo "      MSVC: Run \"nmake NT-Configure\" or \"nmake W-Configure\"."
	@echo "      GCC : Run \"make NT-Configure-GCC\" or \"make W-Configure-GCC\"."
	@echo "            For a fully-automated build Run \"make WUnicon\" ."
	@echo
	@echo "All: after configuration, run \"make (or nmake) Unicon\"."
	@echo

##################################################################
#
# Default targets.

All:	Icont Ilib Ibin

allsrc: Makedefs
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

ULB=$(libdir)/unicon/uni
UIPL=$(libdir)/unicon/ipl
UPLUGINS=$(libdir)/unicon/plugins/lib
INST=$(SHTOOL) install -c
install Install:
	mkdir -p $(bindir)
	mkdir -p $(libdir)
	mkdir -p $(ULB)
	mkdir -p $(UIPL)
	mkdir -p $(UPLUGINS)
	mkdir -p $(UIPL)/lib
	mkdir -p $(UIPL)/incl
	mkdir -p $(UIPL)/gincl
	mkdir -p $(UIPL)/mincl
	mkdir -p $(ULB)/lib
	mkdir -p $(ULB)/3d
	mkdir -p $(ULB)/gui
	mkdir -p $(ULB)/unidoc
	mkdir -p $(ULB)/parser
	mkdir -p $(ULB)/xml
	mkdir -p $(ULB)/unidep
	mkdir -p $(docdir)/unicon
	mkdir -p $(mandir)
	$(INST) bin/[a-qs-z]* $(bindir)/bin
	$(INST) -m 644 ipl/lib/*.u $(UIPL)/lib
	$(INST) -m 644 ipl/incl/*.* $(UIPL)/incl
	$(INST) -m 644 ipl/gincl/*.* $(UIPL)/gincl
	$(INST) -m 644 ipl/mincl/*.* $(UIPL)/mincl
	$(INST) -m 644 uni/lib/*.* $(ULB)/lib
	$(INST) -m 644 uni/gui/*.* $(ULB)/gui
	$(INST) -m 644 uni/3d/*.* $(ULB)/3d
	$(INST) -m 644 uni/xml/*.* $(ULB)/xml
	$(INST) -m 644 uni/unidep/*.* $(ULB)/unidep
	$(INST) -m 644 uni/unidoc/*.* $(ULB)/unidoc
	$(INST) -m 644 uni/parser/*.* $(ULB)/parser
	$(INST) -m 644 doc/unicon/unicon.1 $D/man/man1
	$(INST) -m 644 README $(docdir)/unicon
#	$(INST) -m 644 doc/unicon/*.* $(docdir)/unicon

# Bundle up for binary distribution.

DIR=icon.$(VERSION)
Package:
		rm -rf $(DIR)
		umask 002; $(MAKE) Install dest=$(DIR)
		tar cf - icon.$(VERSION) | gzip -9 >icon.$(VERSION).tgz
		rm -rf $(DIR)

SHTOOL=./shtool

dist: distclean
	$(SHTOOL) fixperm -v *; \
	echo "Building unicon.tar.gz"; \
	$(SHTOOL) tarball -o unicon.tar.gz -c 'gzip -9' \
                          -e '\.svn,\.[oau]$$,\.core$$,~$$,^\.#,#*#,*~', . uni/unicon/unigram.u uni/unicon/idol.u

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
		cd uni;		$(MAKE) Clean
		cd ipl;			$(MAKE) Pure
		cd src;			$(MAKE) Pure
		cd tests;		$(MAKE) Pure
		cd plugins;		$(MAKE) Pure
		rm -f src/common/rswitch.[csS]
		rm -f Makedefs Makedefs.uni

#  (This is used at Arizona to prepare source distributions.)

Dist-Clean:
		rm -rf `find * -type d -name CVS`
		rm -f `find * -type f | xargs grep -l '<<ARIZONA-[O]NLY>>'`
