NULL = 
ACLOCAL_AMFLAGS = -I m4

noinst_LTLIBRARIES = \
	libmacgetter.la \
	libneighborhood.la \
	$(NULL)

noinst_PROGRAMS =  \
	neighborhoodclient \
	$(NULL)

check_PROGRAMS = \
	test_neighbours \
	$(NULL)

TESTS = \
	test_neighbours \
	$(NULL)

libmacgetter_la_SOURCES = \
	mac-getter/hw.c \
	mac-getter/hw.h \
	$(NULL)

libmacgetter_la_CPPFLAGS = \
	$(NULL)

libmacgetter_la_LIBADD = \
	$(NULL)

libneighborhood_la_SOURCES = \
	neighborhood.vala \
	$(NULL)

libneighborhood_la_VALAFLAGS = \
	-H neighborhood.h \
	--library neighborhood \
	--pkg gee-0.8 \
	--pkg ntkd-tasklet-system \
	--pkg ntkdrpc\
	--pkg zcd-tasklet-system \
	$(NULL)

libneighborhood_la_CPPFLAGS = \
	-w \
	$(GOBJECT_CFLAGS) \
	$(GEE_CFLAGS) \
	$(TASKLETSYSTEM_CFLAGS) \
	$(NTKDRPC_CFLAGS) \
	$(NULL)

libneighborhood_la_LIBADD = \
	$(GOBJECT_LIBS) \
	$(GEE_LIBS) \
	$(TASKLETSYSTEM_LIBS) \
	$(NTKDRPC_LIBS) \
	$(NULL)

neighborhoodclient_SOURCES =  \
	main.vala \
	tasklet_system_tasklet.vala \
	base_fake_address_manager.vala \
	mac-getter/hw.vapi \
	neighborhood.vapi \
	$(NULL)

neighborhoodclient_VALAFLAGS = \
	--pkg gee-0.8 \
	--pkg ntkd-tasklet-system \
	--pkg tasklet \
	--pkg ntkdrpc \
	--pkg zcd-tasklet-system \
	$(NULL)

neighborhoodclient_CPPFLAGS = \
	-w \
	$(GOBJECT_CFLAGS) \
	$(GEE_CFLAGS) \
	$(TASKLETSYSTEM_CFLAGS) \
	$(TASKLET_CFLAGS) \
	$(NTKDRPC_CFLAGS) \
	$(NULL)

neighborhoodclient_LDADD = \
	$(GOBJECT_LIBS) \
	$(GEE_LIBS) \
	$(TASKLETSYSTEM_LIBS) \
	$(TASKLET_LIBS) \
	$(NTKDRPC_LIBS) \
	$(builddir)/libmacgetter.la \
	$(builddir)/libneighborhood.la \
	$(NULL)

test_neighbours_SOURCES = \
	testsuites/test_neighbours/test_neighbours.vala \
	testsuites/test_neighbours/base_fake_address_manager.vala \
	testsuites/test_neighbours/tasklet_system_tasklet.vala \
	neighborhood.vapi \
	$(NULL)

test_neighbours_VALAFLAGS = \
	--pkg gee-0.8 \
	--pkg ntkd-tasklet-system \
	--pkg tasklet \
	--pkg ntkdrpc\
	--pkg zcd-tasklet-system \
	$(NULL)

test_neighbours_CPPFLAGS = \
	-w \
	$(GOBJECT_CFLAGS) \
	$(GEE_CFLAGS) \
	$(TASKLETSYSTEM_CFLAGS) \
	$(TASKLET_CFLAGS) \
	$(NTKDRPC_CFLAGS) \
	$(NULL)

test_neighbours_LDADD = \
	$(GOBJECT_LIBS) \
	$(GEE_LIBS) \
	$(TASKLETSYSTEM_LIBS) \
	$(TASKLET_LIBS) \
	$(NTKDRPC_LIBS) \
	$(builddir)/libneighborhood.la \
	$(NULL)

MAINTAINERCLEANFILES = \
	$(srcdir)/neighborhood.vapi \
	$(NULL)

neighborhood.vapi: libneighborhood_la_vala.stamp
	$(NULL)

