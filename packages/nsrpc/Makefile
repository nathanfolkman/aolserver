AOLSERVER=${AOLSERVERBUILD}
PACKAGENAME=nsrpc
INSTALLPATH=${AOLSERVER}/packages

install:
	mkdir -p ${INSTALLPATH}/${PACKAGENAME}
	echo "pkg_mkIndex -verbose . *.tcl" | tclsh
	cp *.tcl ${INSTALLPATH}/${PACKAGENAME}/.

clean:
	rm pkgIndex.tcl

distclean: clean
	rm -rf ${INSTALLPATH}/${PACKAGENAME}
