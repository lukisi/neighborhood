NULL = 
ACLOCAL_AMFLAGS = -I m4

noinst_LTLIBRARIES = \
	libmacgetter.la \
	libneighborhood.la \
	$(NULL)

#noinst_PROGRAMS =  \
#	neighborhoodclient \
#	$(NULL)

check_PROGRAMS = \
	test_serialize_helpers \
	$(NULL)
#	test_neighbours

TESTS = \
	test_serialize_helpers \
	$(NULL)
#	test_neighbours

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
	serialize_helpers.vala \
	$(NULL)

libneighborhood_la_VALAFLAGS = \
	-H neighborhood.h \
	--library neighborhood \
	--pkg gee-0.8 \
	--pkg json-glib-1.0 \
	--pkg tasklet-system \
	--pkg ntkd-common \
	--pkg ntkdrpc\
	$(NULL)

libneighborhood_la_CPPFLAGS = \
	-w \
	$(GOBJECT_CFLAGS) \
	$(GEE_CFLAGS) \
	$(JSONGLIB_CFLAGS) \
	$(TASKLETSYSTEM_CFLAGS) \
	$(NTKDCOMMON_CFLAGS) \
	$(NTKDRPC_CFLAGS) \
	$(NULL)

libneighborhood_la_LIBADD = \
	$(GOBJECT_LIBS) \
	$(GEE_LIBS) \
	$(JSONGLIB_LIBS) \
	$(TASKLETSYSTEM_LIBS) \
	$(NTKDCOMMON_LIBS) \
	$(NTKDRPC_LIBS) \
	$(NULL)

neighborhoodclient_SOURCES =  \
	main.vala \
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
	$(PTHTASKLET_CFLAGS) \
	$(NTKDRPC_CFLAGS) \
	$(NULL)

neighborhoodclient_LDADD = \
	$(GOBJECT_LIBS) \
	$(GEE_LIBS) \
	$(TASKLETSYSTEM_LIBS) \
	$(PTHTASKLET_LIBS) \
	$(NTKDRPC_LIBS) \
	$(builddir)/libmacgetter.la \
	$(builddir)/libneighborhood.la \
	$(NULL)

test_neighbours_SOURCES = \
	testsuites/test_neighbours/test_neighbours.vala \
	neighborhood.vapi \
	$(NULL)

test_neighbours_VALAFLAGS = \
	--pkg gee-0.8 \
	--pkg tasklet-system \
	--pkg pth-tasklet \
	--pkg ntkd-common\
	--pkg ntkdrpc\
	$(NULL)

test_neighbours_CPPFLAGS = \
	-w \
	$(GOBJECT_CFLAGS) \
	$(GEE_CFLAGS) \
	$(TASKLETSYSTEM_CFLAGS) \
	$(PTHTASKLET_CFLAGS) \
	$(NTKDCOMMON_CFLAGS) \
	$(NTKDRPC_CFLAGS) \
	$(NULL)

test_neighbours_LDADD = \
	$(GOBJECT_LIBS) \
	$(GEE_LIBS) \
	$(TASKLETSYSTEM_LIBS) \
	$(PTHTASKLET_LIBS) \
	$(NTKDCOMMON_LIBS) \
	$(NTKDRPC_LIBS) \
	$(builddir)/libneighborhood.la \
	$(NULL)

test_serialize_helpers_SOURCES =  \
	testsuites/test_serialize_helpers/test_serialize_helpers.vala \
	testsuites/test_serialize_helpers/serialize_helpers.vala \
	$(NULL)

test_serialize_helpers_VALAFLAGS = \
	--pkg gee-0.8 \
	--pkg json-glib-1.0 \
	$(NULL)

test_serialize_helpers_CPPFLAGS = \
	-w \
	$(GOBJECT_CFLAGS) \
	$(GEE_CFLAGS) \
	$(JSONGLIB_CFLAGS) \
	$(NULL)

test_serialize_helpers_LDADD = \
	$(GOBJECT_LIBS) \
	$(GEE_LIBS) \
	$(JSONGLIB_LIBS) \
	$(NULL)

MAINTAINERCLEANFILES = \
	$(srcdir)/neighborhood.vapi \
	$(NULL)

neighborhood.vapi: libneighborhood_la_vala.stamp
	$(NULL)

