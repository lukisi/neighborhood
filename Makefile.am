NULL = 
ACLOCAL_AMFLAGS = -I m4

bin_PROGRAMS =  \
	neighborhood \
	$(NULL)

neighborhood_SOURCES =  \
	neighborhood.vala \
	$(NULL)

neighborhood_VALAFLAGS = \
	--pkg gio-2.0 \
	--pkg gee-0.8 \
	--pkg tasklet \
	--pkg posix \
	--pkg zcd \
	--pkg linux \
	$(NULL)

neighborhood_CPPFLAGS = \
	$(GOBJECT_CFLAGS) \
	$(GIO_CFLAGS) \
	$(GEE_CFLAGS) \
	$(TASKLET_CFLAGS) \
	$(ZCD_CFLAGS) \
	$(NULL)

neighborhood_LDADD = \
	$(GOBJECT_LIBS) \
	$(GIO_LIBS) \
	$(GEE_LIBS) \
	$(TASKLET_LIBS) \
	$(ZCD_LIBS) \
	$(NULL)

BUILT_SOURCES = neighborhood_vala.stamp

