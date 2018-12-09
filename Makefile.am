NULL = 
ACLOCAL_AMFLAGS = -I m4

noinst_LTLIBRARIES = \
	libneighborhood.la \
	$(NULL)

check_PROGRAMS = \
	test_serializables \
	here_i_am \
	$(NULL)

TESTS = \
	test_serializables \
	$(NULL)

libneighborhood_la_SOURCES = \
	neighborhood.vala \
	api.vala \
	serializables.vala \
	structs.vala \
	rngen.vala \
	$(NULL)

libneighborhood_la_VALAFLAGS = \
	-H neighborhood.h \
	--library neighborhood \
	--vapidir $(GEE_PREFIX)/share/vala/vapi \
	--vapidir $(JSON_PREFIX)/share/vala-0.36/vapi \
	--vapidir $(TASKLETSYSTEM_VAPIDIR) \
	--vapidir $(NTKDCOMMON_VAPIDIR) \
	--vapidir $(NTKDRPC_VAPIDIR) \
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

test_serializables_SOURCES =  \
	testsuites/test_serializables/test_serializables.vala \
	testsuites/test_serializables/serializables.vala \
	testsuites/test_serializables/rngen.vala \
	$(NULL)

test_serializables_VALAFLAGS = \
	--vapidir $(GEE_PREFIX)/share/vala/vapi \
	--vapidir $(JSON_PREFIX)/share/vala-0.36/vapi \
	--pkg gee-0.8 \
	--pkg json-glib-1.0 \
	$(NULL)

test_serializables_CPPFLAGS = \
	-w \
	$(GOBJECT_CFLAGS) \
	$(GEE_CFLAGS) \
	$(JSONGLIB_CFLAGS) \
	$(NULL)

test_serializables_LDADD = \
	$(GOBJECT_LIBS) \
	$(GEE_LIBS) \
	$(JSONGLIB_LIBS) \
	$(NULL)

here_i_am_SOURCES =  \
	testsuites/here_i_am/here_i_am.vala \
	testsuites/here_i_am/rngen.vala \
	testsuites/here_i_am/serializables.vala \
	testsuites/here_i_am/neighborhood_helpers.vala \
	testsuites/here_i_am/neighborhood_signals.vala \
	testsuites/here_i_am/rpc/skeleton_factory.vala \
	testsuites/here_i_am/rpc/stub_factory.vala \
	testsuites/here_i_am/rpc/module_stubs.vala \
	neighborhood.vapi \
	$(NULL)

here_i_am_VALAFLAGS = \
	--vapidir $(GEE_PREFIX)/share/vala/vapi \
	--vapidir $(TASKLETSYSTEM_VAPIDIR) \
	--vapidir $(PTHTASKLET_VAPIDIR) \
	--vapidir $(NTKDCOMMON_VAPIDIR) \
	--vapidir $(NTKDRPC_VAPIDIR) \
	--pkg gee-0.8 \
	--pkg ntkd-common \
	--pkg tasklet-system \
	--pkg pth-tasklet \
	--pkg ntkdrpc \
	$(NULL)

here_i_am_CPPFLAGS = \
	-w \
	$(GOBJECT_CFLAGS) \
	$(GEE_CFLAGS) \
	$(NTKDCOMMON_CFLAGS) \
	$(TASKLETSYSTEM_CFLAGS) \
	$(PTHTASKLET_CFLAGS) \
	$(NTKDRPC_CFLAGS) \
	$(NULL)

here_i_am_LDADD = \
	$(GOBJECT_LIBS) \
	$(GEE_LIBS) \
	$(NTKDCOMMON_LIBS) \
	$(TASKLETSYSTEM_LIBS) \
	$(PTHTASKLET_LIBS) \
	$(NTKDRPC_LIBS) \
	$(builddir)/libneighborhood.la \
	$(NULL)

MAINTAINERCLEANFILES = \
	$(srcdir)/neighborhood.vapi \
	$(NULL)

neighborhood.vapi: libneighborhood_la_vala.stamp
	$(NULL)

