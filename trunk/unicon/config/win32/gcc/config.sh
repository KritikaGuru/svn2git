mkdir -p ../../../bin
cp mkicont.bat ../../..
cp mkunivib.bat ../../..
cp gdbm.bat ../../../src/runtime
cp libtp.bat ../../../src/runtime
cp makefile.top ../../../makefile
cp define.h ../../../src/h
cp path.h ../../../src/h
cp auto.h ../../../src/h
cp RSWITCH.S ../../../src/common
cp NTICONT.LNK ../../../src/icont
# unicon.icon has a control-Z char at pos 29, cp on our sh.exe
# fails to copy beyoned that point leaving the file truncated.
# Manual copy for now!
# cp unicon.ico ../../../src/runtime
cp icon.rc ../../../src/runtime
echo CONSOLE=NTConsole >../../../src/common/makefile
cat makefile.cmn >>../../../src/common/makefile
cp MAKEFILE.RTT ../../../src/rtt/makefile
echo ICONX=nticonx >../../../src/runtime/makefile
echo CONSOLE=NTConsole >>../../../src/runtime/makefile
cat MAKEFILE.RUN >>../../../src/runtime/makefile
echo ICONT=icont >../../../src/icont/makefile
echo CONSOLE=NTConsole >>../../../src/icont/makefile
cat MAKEFILE.T >>../../../src/icont/makefile
rm ../../../src/libtp/config.h
cp ../../../src/libtp/config_h.win ../../../src/libtp/config.h
mkdir -p ../../../ipl/lib
cp makefile.cfn ../../../ipl/cfuncs/makefile

cp ../../unix/Config/ipllib.mak ../../../ipl/lib/makefile
# cp ../../unix/Config/ide.mak ../../../uni/ide/makefile
cp ../../unix/Config/ivib.mak ../../../uni/ivib/makefile
cp ../../unix/Config/unilib.mak ../../../uni/lib/makefile
echo EXE=.exe > ../../../uni/unicon/makefile
cat ../../unix/Config/unicon.mak >>../../../uni/unicon/makefile
cp ../../unix/Config/xml.mak ../../../uni/xml/makefile
cp ../../unix/Config/unidep.mak ../../../uni/unidep/makefile
cp ../../unix/Config/unidoc.mak ../../../uni/unidoc/makefile
cp ../../unix/Config/parser.mak ../../../uni/parser/makefile
cp ../../unix/Config/util.mak ../../../uni/util/makefile
cp ../../unix/Config/gui.mak ../../../uni/gui/makefile
cp ../../unix/Config/guidemos.mak ../../../uni/gui/guidemos/makefile
cp ../../unix/Config/ivib-v2.mak ../../../uni/gui/ivib/makefile
cp ../../unix/Config/uni-top.mak ../../../uni/Makefile
echo EXE=.exe > ../../../uni/makedefs
cat ../../unix/Config/uni-makedefs >>../../../uni/makedefs
cp iyacc.mak ../../../uni/iyacc/Makefile

rm ../../../src/icont/*.o 2> nul
rm ../../../src/common/*.o 2> nul
rm ../../../src/runtime/*.o 2> nul
echo # noop > ../../../uni/ide/makefile
