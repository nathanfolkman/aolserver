AOLSERVER = /usr/local/aolserver

ALIB = tcljson
LIBLIBS = -ltcl8.4g -lc -ljson
LIBOBJS = json.o

MOD = tcljson
DLLLIBS = -ltcl8.4g -lc -ljson
OBJS = json.o

LDFLAGS += -L$(AOLSERVER)/lib 
CFLAGS += -Wno-cast-align -std=c99 -I$(AOLSERVER)/include/json

include $(AOLSERVER)/include/ns.mak 
