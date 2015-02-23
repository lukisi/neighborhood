NULL = 
ACLOCAL_AMFLAGS = -I m4

EXTRA_LTLIBRARIES = \
	libneighborhood.la \
	$(NULL)

bin_PROGRAMS =  \
	neighborhoodclient \
	$(NULL)

check_PROGRAMS = \
	test_neighbours \
	$(NULL)

TESTS = \
	test_neighbours \
	$(NULL)

test_neighbours_SOURCES = \
	testsuites/test_neighbours/test_neighbours.vala \
	testsuites/test_neighbours/base_dispatcher.vala \
	neighborhood.vapi \
	$(NULL)

test_neighbours_VALAFLAGS = \
	--pkg gio-2.0 \
	--pkg gee-0.8 \
	--pkg tasklet \
	--pkg zcd \
	--pkg ntkd-rpc\
	$(NULL)

test_neighbours_CPPFLAGS = \
	-w \
	$(GOBJECT_CFLAGS) \
	$(GIO_CFLAGS) \
	$(GEE_CFLAGS) \
	$(TASKLET_CFLAGS) \
	$(ZCD_CFLAGS) \
	$(NTKDRPC_CFLAGS) \
	$(NULL)

test_neighbours_LDADD = \
	$(GOBJECT_LIBS) \
	$(GIO_LIBS) \
	$(GEE_LIBS) \
	$(TASKLET_LIBS) \
	$(ZCD_LIBS) \
	$(NTKDRPC_LIBS) \
	$(builddir)/libneighborhood.la \
	$(NULL)

neighborhoodclient_SOURCES =  \
	main.vala \
	base_dispatcher.vala \
	neighborhood.vapi \
	$(NULL)

neighborhoodclient_VALAFLAGS = \
	--pkg gio-2.0 \
	--pkg gee-0.8 \
	--pkg tasklet \
	--pkg posix \
	--pkg zcd \
	--pkg ntkd-rpc\
	--pkg linux \
	$(NULL)

neighborhoodclient_CPPFLAGS = \
	-w \
	$(GOBJECT_CFLAGS) \
	$(GIO_CFLAGS) \
	$(GEE_CFLAGS) \
	$(TASKLET_CFLAGS) \
	$(ZCD_CFLAGS) \
	$(NTKDRPC_CFLAGS) \
	$(NULL)

neighborhoodclient_LDADD = \
	$(GOBJECT_LIBS) \
	$(GIO_LIBS) \
	$(GEE_LIBS) \
	$(TASKLET_LIBS) \
	$(ZCD_LIBS) \
	$(NTKDRPC_LIBS) \
	$(builddir)/libneighborhood.la \
	$(NULL)

libneighborhood_la_SOURCES = \
	neighborhood.vala \
	$(NULL)

libneighborhood_la_VALAFLAGS = \
	-H neighborhood.h \
	--library neighborhood \
	--pkg gio-2.0 \
	--pkg gee-0.8 \
	--pkg tasklet \
	--pkg posix \
	--pkg zcd \
	--pkg ntkd-rpc\
	--pkg linux \
	$(NULL)

libneighborhood_la_CPPFLAGS = \
	-w \
	$(GOBJECT_CFLAGS) \
	$(GIO_CFLAGS) \
	$(GEE_CFLAGS) \
	$(TASKLET_CFLAGS) \
	$(ZCD_CFLAGS) \
	$(NTKDRPC_CFLAGS) \
	$(NULL)

libneighborhood_la_LIBADD = \
	$(GOBJECT_LIBS) \
	$(GIO_LIBS) \
	$(GEE_LIBS) \
	$(TASKLET_LIBS) \
	$(ZCD_LIBS) \
	$(NTKDRPC_LIBS) \
	$(NULL)

CLEANFILES = \
	$(srcdir)/neighborhood.vapi \
	$(srcdir)/neighborhood.h \
	$(srcdir)/libneighborhood_la_vala.stamp \
	$(srcdir)/main.c \
	$(srcdir)/base_dispatcher.c \
	$(srcdir)/neighborhood.c \
	$(srcdir)/testsuites/test_neighbours/test_neighbours.c \
	$(srcdir)/testsuites/test_neighbours/base_dispatcher.c \
	$(NULL)

neighborhood.vapi: libneighborhood_la_vala.stamp
	$(NULL)

