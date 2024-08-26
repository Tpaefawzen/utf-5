changequote(<<<, >>>)dnl
dnl
dnl @string BOILERPLATE()
dnl initializes shellscript for portability as in POSIXism
dnl 
define(<<<BOILERPLATE>>>,
<<<## boilerplate
set -eu
umask 0022
if posix_path="$( comamnd -p getconf PATH 2>/dev/null )"; then
    export PATH="${posix_path}${PATH+:}${PATH:-}"
fi
export LC_ALL=C
export UNIX_STD=2003
export POSIXLY_CORRECT=1>>>)dnl
dnl
dnl @macro HEADER()
dnl @param NAME, DESCRIPTION
dnl sets header block of comments. Has command NAME, its DESCRIPTION, my copyright notice, license things.
dnl
define(<<<HEADER>>>, <<<dnl
################################################################################
#
# $1 - $2
#
# Copyright (C) 2023 Tpaefawzen <GitHub: Tpaefawzen>
#
# This software is licensed under the MIT license.
#
# MIT License
# 
# Copyright (c) 2023 Tpaefawzen
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
################################################################################
>>>)dnl
dnl
dnl @macro DEFINE_AWK_ERROR_EXIXT
dnl @param none
dnl @depends @variable myname
dnl @depends @variable ERRSTATUS
dnl @descrpiton
dnl Awk's user-defined internal function.
define(<<<DEFINE_AWK_ERROR_EXIT>>>,<<<dnl
function error_exit( msg ){
	print myname ": " msg | "cat 1>&2";
	print 1 >> ERRSTATUS;
	exit( 1 );
}>>>)dnl
dnl
dnl ## end of macros
dnl
<<<#!/bin/sh

>>>HEADER(
	<<<convfu5.sh>>>,
	<<<Convert UTF-5 text to UTF-8>>>dnl
)<<<

>>>BOILERPLATE()<<<

## pipestatus alternative
## shall have at least one line of text when error; empty if succesuful exit
tmpdir="$(
	mktemp -d -t "${0##*/}.XXXXXXXXXXXX"
)"
ERRSTATUS="$tmpdir/errstatus"

## clearner
cleaner(){
	exit_status=$?
	trap '' EXIT HUP INT QUIT PIPE ALRM TERM KILL
	rm -Rf "$tmpdir"
	trap - EXIT HUP INT QUIT PIPE ALRM TERM KILL
	exit "$exit_status"
}
trap cleaner EXIT HUP INT QUIT PIPE ALRM TERM KILL

## helper function
usage(){
	cat <<-USAGE 1>&2
	Usage: ${0##*/} [FILE]
	USAGE
	exit 1
}

## flags for this command
is_case_sensitive=1 # -c OR --case-insensitive
is_need2rm_blank=0 # -b OR --remove-blanks

## parse arguments
case "${1:-}" in (-h|--help|--usage)
	usage
esac

while :; do
	# no args
	case "$#" in 0) break;; esac

	# no flags
	# NAME ''
	# NAME -
	# NAME FILE
	case "$1" in ''|-|[!-]*) break;; esac

	# end of flags
	case "$1" in --) shift; break;; esac

	# flags #
	case "$1" in
	-c|--case-insensitive|--c*)
		is_case_sensitive=0
		shift
		continue
	;;
	-b|--remove-blanks|--r*)
		is_need2rm_blank=1
		shift
		continue
	;;esac

	# now unsupported flags
	usage
done

## main routine

# assuming input is UTF-5 in ASCII, get each byte as unsigned decimal
(
	cat ${1:+"$1"} || {
		printf '%s\n' "${0##*/}: ${1##*/}: Reading error occured (status: $?)" 1>&2
		echo 1 >> "$ERRSTATUS"
	}
) |
#
# to uppercase if requested
case $is_case_sensitive in 0) tr a-z A-Z;; *) cat;; esac |
#
# remove blank things if requested
case $is_need2rm_blank in 0) cat;; *) tr -d ' \t';; esac |
#
# are they utf-5 letters?
# if so convert each letter to code point
# otherwise fail
awk -v myname="${0##*/}" -v ERRSTATUS="$ERRSTATUS" -v is_reading=0 '
>>>DEFINE_AWK_ERROR_EXIT<<<

BEGIN {
	# 00000-01001 to 0-9
	for ( i = 0; i < 10; i++ ){
		d["" i] = i;
	}

	# 01010-11111 to A-V
	for ( i = 10; i < 32; i++ ){
		d[sprintf("%c", 55 + i)] = i;
	}
}
{
	L = length($0);
	for ( i = 1; i <= L; i++ ){
		c = substr($0, i, 1);
		if ( c in d ){
			print d[c];
			continue;
		}
		error_exit( "unknown character " c );
	}
}' |
#
# 1: quintet
# now group by sequence
# grouped by 1xxxx [0xxxx ...]
awk -v myname="${0##*/}" -v ERRSTATUS="$ERRSTATUS" -v is_error=0 '
>>>DEFINE_AWK_ERROR_EXIT<<<

BEGIN{
	row = "";
}
$1 >= 16 {
	if (row) print row;
	row = $1;
	next;
}
0 <= $1 && $1 < 16 {
	row = row FS $1;

	if (NR != 1) next;
	is_error = 1;
	error_exit("first 0xxxx quintet is illegal: " $1);	
}
END {
	if ( ! is_error && row ) print row;
}' |
#
# 1-NF: quintets
# convert quintets to code point
awk '
{
	val = $1 - 16;
	for ( i = 2; i <= NF; i++ ){
		val = val * 16 + $i;
	}
	print val;
}' |
#
# 1: code point
cat;exit;
#
# convert to code points
awk -v myname="${0##*/}" -v ERRSTATUS="$ERRSTATUS" -v is_reading=0 '
function getchar(){
	if( NR == 0 || gc_i > NF ){
		gc_status = getline;
		gc_i = 1;
	}
	if( gc_status <= 0 ){
		if( ! is_reading ) exit( 0 );
		error_exit("unexpected EOF while reading following byte(s)");
	}
	return $(gc_i++);
}
function error_exit( msg ){
	print myname ": " msg | "cat 1>&2";
	print 1 >> ERRSTATUS;
	exit( 1 );
}
BEGIN{
	for(;;){
		is_reading = 0;
		c = getchar();
		is_reading = 1;
		if( c < 128 ){
			print c;
		}
		else if( 128 <= c && c < 192 ){
			error_exit("WTF unknown byte " c " as leading")
		}
		else if( 192 <= c && c <= 224 ){
			c1 = c - 192;
			c2 = getchar() - 128;
			codepoint = c1 * 64 + c2;
			if( ! ( 128 <= codepoint && codepoint <= 2047 ) ){
				error_exit("2-byte code but WTF codepoint is " codepoint);
			}
			print codepoint;
		}
		else if( 224 <= c && c < 240 ){
			c1 = c - 224;
			c2 = getchar() - 128;
			c3 = getchar() - 128;
			codepoint = ( c1 * 64 + c2 ) * 64 + c3;
			if( ! ( 2048 <= codepoint && codepoint <= 65535 ) ){
				error_exit("3-byte code but WTF codepoint is " codepoint);
			}
			if( 55296 <= codepoint && codepoint <= 57343 ){
				error_exit("WTF surrogate " codepoint);
			}
			if( codepoint == 65534 || codepoint == 65535 ){
				error_exit("WTF BOM character " codepoint);
			}
			print codepoint;
		}
		else if( 240 <= c && c < 248 ){
			c1 = c - 240;
			c2 = getchar() - 128;
			c3 = getchar() - 128;
			c4 = getchar() - 128;
			codepoint = ( ( c1 * 64 + c2 ) * 64 + c3 ) * 64 + c4;
			if( ! ( 65536 <= codepoint && codepoint <= 1114111 ) ){
				error_exit("4-byte code but WTF codepoint is " codepoint);
			}
			print codepoint;
		}
		else{
			error_exit("WTF unknow leading byte " c);
		}
	}
}
' |
#
# to UTF-5 quintet sequence
awk '
{
	# store current code point
	c = $0;

	# variable s is list of quintet
	s = "";

	# loop until last quintet can be taken
	for(; c >= 16;){
		# q shall be 0xxxx
		q = c % 16;

		# unshift obtained quintet
		s = q FS s;

		# ABCDEF to 0ABCDE
		c = int( c / 16 );
	}

	# finally first quintet shall be 1xxxx
	s = ( c + 16 ) FS s;

	$0 = s;
	print $0;
}' |
#
# each quintet to alphabet
awk '
BEGIN{
	# 00000-01001 to 0-9
	for( i = 0; i < 10; i++ ){
		c[i] = "" i;
	}

	# 01010-11111 to A-V
	for( i = 10; i < 32; i++ ){
		c[i] = sprintf("%c", 55 + i);
	}
}
{
	for( i = 1; i <= NF; i++ ){
		printf c[$i];
	}
}
END{
	if( NR >= 1 ){
		printf ORS;
	}
}' |
#
# to

# finally
if test -r "$ERRSTATUS"; then
	exit $( head -n 1 "$ERRSTATUS" )
fi
exit 0>>>
