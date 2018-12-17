NULL = 
ACLOCAL_AMFLAGS = -I m4

noinst_LTLIBRARIES = \
	libneighborhood.la \
	$(NULL)

check_PROGRAMS = \
	test_serializables \
	system_peer \
	$(NULL)

TESTS = \
	test_serializables \
	test_count_arcs \
	test_collision \
	test_no_self_arc \
	test_stop_monitor \
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

system_peer_SOURCES =  \
	testsuites/system_peer/system_peer.vala \
	testsuites/system_peer/rngen.vala \
	testsuites/system_peer/serializables.vala \
	testsuites/system_peer/neighborhood_helpers.vala \
	testsuites/system_peer/neighborhood_signals.vala \
	testsuites/system_peer/rpc/skeleton_factory.vala \
	testsuites/system_peer/rpc/stub_factory.vala \
	testsuites/system_peer/rpc/module_stubs.vala \
	testsuites/system_peer/check_remove_my_arc.vala \
	testsuites/system_peer/check_stop_monitor.vala \
	testsuites/system_peer/fake_command_dispatcher.vala \
	neighborhood.vapi \
	$(NULL)

system_peer_VALAFLAGS = \
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

system_peer_CPPFLAGS = \
	-w \
	$(GOBJECT_CFLAGS) \
	$(GEE_CFLAGS) \
	$(NTKDCOMMON_CFLAGS) \
	$(TASKLETSYSTEM_CFLAGS) \
	$(PTHTASKLET_CFLAGS) \
	$(NTKDRPC_CFLAGS) \
	$(NULL)

system_peer_LDADD = \
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

