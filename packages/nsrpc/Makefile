AOLSERVER=/usr/local/aolserver
PACKAGENAME=nsrpc
INSTALLPATH=${AOLSERVER}/lib

install:
	mkdir -p ${INSTALLPATH}/${PACKAGENAME}
	echo "pkg_mkIndex -verbose . *.tcl" | tclsh
	cp *.tcl ${INSTALLPATH}/${PACKAGENAME}/.

clean:
	rm pkgIndex.tcl

distclean: clean
	rm -rf ${INSTALLPATH}/${PACKAGENAME}
