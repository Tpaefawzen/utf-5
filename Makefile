.POSIX:

TARGET = convtu5.sh convfu5.sh

.SUFFIXES: .m4

.m4.sh:
	m4 $< > $@
	chmod a+x $@

all: ${TARGET}
