NULL = 
ACLOCAL_AMFLAGS = -I m4

EXTRA_LTLIBRARIES = \
	libneighborhood.la \
	$(NULL)

bin_PROGRAMS =  \
	neighborhoodclient \
	$(NULL)

neighborhoodclient_SOURCES =  \
	main.vala \
	neighborhood.vapi \
	$(NULL)

neighborhoodclient_VALAFLAGS = \
	--pkg gio-2.0 \
	--pkg gee-0.8 \
	--pkg tasklet \
	--pkg posix \
	--pkg zcd \
	--pkg linux \
	$(NULL)

neighborhoodclient_CPPFLAGS = \
	$(GOBJECT_CFLAGS) \
	$(GIO_CFLAGS) \
	$(GEE_CFLAGS) \
	$(TASKLET_CFLAGS) \
	$(ZCD_CFLAGS) \
	$(NULL)

neighborhoodclient_LDADD = \
	$(GOBJECT_LIBS) \
	$(GIO_LIBS) \
	$(GEE_LIBS) \
	$(TASKLET_LIBS) \
	$(ZCD_LIBS) \
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
	--pkg linux \
	$(NULL)

libneighborhood_la_CPPFLAGS = \
	$(GOBJECT_CFLAGS) \
	$(GIO_CFLAGS) \
	$(GEE_CFLAGS) \
	$(TASKLET_CFLAGS) \
	$(ZCD_CFLAGS) \
	$(NULL)

libneighborhood_la_LIBADD = \
	$(GOBJECT_LIBS) \
	$(GIO_LIBS) \
	$(GEE_LIBS) \
	$(TASKLET_LIBS) \
	$(ZCD_LIBS) \
	$(NULL)

BUILT_SOURCES = libneighborhood_la_vala.stamp

