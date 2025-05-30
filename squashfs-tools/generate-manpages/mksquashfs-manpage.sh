#!/bin/sh

# This script generates a manpage from the mksquashfs -help and -version
# output, using help2man.  The script does various modfications to the
# output from -help and -version, before passing it to help2man, to allow
# it be successfully processed into a manpage by help2man.

if [ ! -f functions.sh ]; then
	echo "$0: this script should be run in the <git-root/source-root>/generate-manpages directory" >&2
	exit 1
fi

. ./functions.sh

if [ $# -lt 2 ]; then
	error "$0: Insufficient arguments"
	error "$0: <path to mksquashfs> <output file>"
	exit 1
fi

# Sanity check, ensure $1 points to a directory with a runnable Mksquashfs
if [ ! -x $1/mksquashfs ]; then
	error "$0: <arg1> doesn't point to a directory with Mksquashfs in it!"
	error "$0: <arg1> should point to the directory with the Mksquashfs" \
		"you want to generate a manpage for."
	exit 1
fi

# Sanity check, check that the utilities this script depends on, are in PATH
for i in expand help2man; do
	if ! which $i > /dev/null 2>&1; then
		error "$0: This script needs $i, which is not in your PATH."
		error "$0: Fix PATH or install before running this script!"
		exit 1
	fi
done

tmp=$(mktemp -d)

# Run mksquashfs -help-all, expand TABS to spaces, and output the help text to
# $tmp/mksquashfs.help.  This is to allow it to be modified before
# passing to help2man.

if ! $1/mksquashfs -help-all > $tmp/mksquashfs.help2 2>&1; then
	error "$0: Running Mksquashfs failed.  Cross-compiled or incompatible binary?"
	exit 1
fi

expand $tmp/mksquashfs.help2 > $tmp/mksquashfs.help

# Run mksquashfs -version, and output the version text to
# $tmp/mksquashfs.version.  This is to allow it to be modified before
# passing to help2man.

$1/mksquashfs -version > $tmp/mksquashfs.version

# Create a dummy executable in $tmp, which outputs $tmp/mksquashfs.help
# and $tmp/mksquashfs.version.  This gets around the fact help2man wants
# to pass --help and --version directly to mksquashfs, rather than take the
# (modified) output from $tmp/mksquashfs.help and $tmp/mksquashfs.version

print "#!/bin/sh
if [ \$1 = \"--help\" ]; then
	cat $tmp/mksquashfs.help
else
	cat $tmp/mksquashfs.version
fi" > $tmp/mksquashfs.sh

chmod u+x $tmp/mksquashfs.sh

# help2man gets confused by the version date returned by -version,
# and includes it in the version string

${SED} -i "s/ (.*)$//" $tmp/mksquashfs.version

# help2man expects copyright to have an upper-case C ...

${SED} -i "s/^copyright/Copyright/" $tmp/mksquashfs.version

# help2man doesn't pick up the author from the version.  Easiest to add
# it here.

print >> $tmp/mksquashfs.version
print "Written by Phillip Lougher <phillip@squashfs.org.uk>" >> $tmp/mksquashfs.version

# If the second line isn't empty, it means the first line (starting with
# SYNTAX) has wrapped.

${SED} -i "1 {
N
/\n$/!s/\n/ /
}" $tmp/mksquashfs.help

# help2man expects "Usage: ", and so rename "SYNTAX:" to "Usage: "

${SED} -i "s/^SYNTAX:/Usage: /" $tmp/mksquashfs.help

# Man pages expect the options to be in the "Options" section.  So insert
# Options section after Usage

${SED} -i "/^Usage/a *OPTIONS*" $tmp/mksquashfs.help

# help2man expects options to start in the 2nd column

${SED} -i "s/^-/  -/" $tmp/mksquashfs.help
${SED} -i "s/^ *-X/  -X/" $tmp/mksquashfs.help

# help2man expects the options usage to be separated from the
# option and operands text by at least 2 spaces.  These options
# due to their length only have one space, and so add an extra
# space

${SED} -i -e "s/expr> as/expr>  as/" -e "s/exp> as/exp>  as/" \
	-e "s/file> as/file>  as/" -e "s/regex> exclude/regex>  exclude/" \
	-e "s/regex> include/regex>  include/" -e "s/mode> set/mode>  set/" \
	-e "s/value> offset/value>  offset/" \
	-e "s/section> print/section>  print/" $tmp/mksquashfs.help

# Expand certain operands truncated in help text due to lack of space

${SED} -i -e "s/act@/action@/g" -e "s/expr>/expression>/g" -e "s/exp>/expression>/" -e "s/<f>/<file>/g" $tmp/mksquashfs.help

# Uppercase the options operands (between < and > ) to make it conform
# more to man page standards

${SED} -i "s/<[^>]*>/\U&/g" $tmp/mksquashfs.help

# Undo the above for the -pd option, where the case actually matters!  Also
# expand the truncated uid and gid in help text due to lack of space.
# Also put quotes around the above pseudo definitions

${SED} -i -e "s/<D MODE UID GID>/\"d mode uid gid\"/" -e "s/<D TIME MODE U G>/\"D time mode uid gid\"/" $tmp/mksquashfs.help 

# Remove the "<" and ">" around options operands to make it conform
# more to man page standards

${SED} -i -e "s/<//g" -e "s/>//g" $tmp/mksquashfs.help

# help2man doesn't deal well with the list of supported compressors.
# So concatenate them onto one line with commas

${SED} -i "/^  -comp/ {
N
s/\n */ /
N
s/\n */ /
N
s/\n */ /
s/:/: /

N
s/\n *\([^ ]*$\)/\1/
s/\n *\([^ ]* (default)$\)/\1/

: again
N
/\n  -noI/b

s/\n *\([^ ]*$\)/, \1/
s/\n *\([^ ]* (default)$\)/, \1/
b again
}" $tmp/mksquashfs.help

# help2man doesn't deal well with the list of lzo1* algorithms.
# So concatenate them onto one line with commas

${SED} -i "/^ *lzo1x_1/ {
s/\n *\([^ ]*$\)/\1/
s/\n *\([^ ]* (default)$\)/\1/

: again
N
/\n *lzo/!b

s/\n *\([^ ]*$\)/, \1/
s/\n *\([^ ]* (default)$\)/, \1/
b again
}" $tmp/mksquashfs.help

# Make the pseudo file definitions into "options" so they're handled
# properly by help2man

${SED} -i "s/^\"filename/  -p \"filename/" $tmp/mksquashfs.help

# Make each compressor entry in the compressors available section, a subsection
# First, have to deal with the deprecated lzma compressor separately, because
# it doesn't have any options (i.e. text prefixed with -).

${SED} -i "/^ *lzma/ {
s/^ *\(lzma.*$\)/\1:/
n
s/^ */  /
} " $tmp/mksquashfs.help

# Now deal with the others

${SED} -i -e "s/^ *\(gzip.*$\)/\1:/" -e "s/^ *\(lzo$\)/\1:/" \
	-e "s/^ *\(lzo (default)$\)/\1:/" -e "s/^ *\(lz4.*$\)/\1:/" \
	-e "s/^ *\(xz.*$\)/\1:/" -e "s/^ *\(zstd.*$\)/\1:/" \
	$tmp/mksquashfs.help

# Concatenate the options text (normal options, pseudo file definitions and
# compressor options) on to one line.  Add a full stop to the end of the
# options text

${SED} -i "/^  -/ {
:option
s/^ *-/  -/

/  -.*  /!s/.$/& /

:again
N
/\n$/b print
/\n[^ ]/b print
/\n  -/b print
s/\n */ /
b again

:print
s/ \n/.\n/
s/\([^.]\)\n/\1.\n/
P
s/^.*\n//
/^ *-/b option
}" $tmp/mksquashfs.help

# Concatenate the SOURCE_DATE_EPOCH text on to one line.  Indent the line by
# two and add a full stop to the end of the line

${SED} -i " /SOURCE_DATE_EPOCH/ {
s/SOURCE_DATE_EPOCH/  SOURCE_DATE_EPOCH/

:again
N
/\n$/b print
s/\n */ /
b again

:print
s/\([^.]\)\n/\1.\n/
}" $tmp/mksquashfs.help

# Concatenate the PAGER text on to one line.  Indent the line by
# two and add a full stop to the end of the line

${SED} -i " /PAGER/ {
s/PAGER/  PAGER/

:again
N
/\n$/b print
s/\n */ /
b again

:print
s/\([^.]\)\n/\1.\n/
}" $tmp/mksquashfs.help

# Concatenate the SQFS_CMDLINE text on to one line.  Indent the line by
# two and add a full stop to the end of the line

${SED} -i " /SQFS_CMDLINE/ {
s/SQFS_CMDLINE/  SQFS_CMDLINE/

:again
N
/\n$/b print
s/\n */ /
b again

:print
s/\([^.]\)\n/\1.\n/
}" $tmp/mksquashfs.help

# Make Compressors available header into a manpage section

${SED} -i "s/\(Compressors available and compressor specific options\):/*\1*/" $tmp/mksquashfs.help

# Make pseudo definition format header into a manpage section

${SED} -i "s/\(Pseudo file definition format\):/*\1*/" $tmp/mksquashfs.help

# Add reference to manpages for other squashfs-tools programs
${SED} -i "s/See also (extra information elsewhere):/See also:\nunsquashfs(1), sqfstar(1), sqfscat(1)\n/" $tmp/mksquashfs.help

# Make Exit status header into a manpage section

${SED} -i "s/\(Exit status\):/*\1*/" $tmp/mksquashfs.help

# Make See also header into a manpage section

${SED} -i "s/\(See also\):/*\1*/" $tmp/mksquashfs.help

# Make Environment header into a manpage section

${SED} -i "s/\(Environment\):/*\1*/" $tmp/mksquashfs.help

# Make Symbolic mode specification header into a manpage section

${SED} -i "s/\(Symbolic mode specification\):/*\1*/" $tmp/mksquashfs.help

if ! help2man -Ni mksquashfs.h2m -o $2 $tmp/mksquashfs.sh; then
	error "$0: help2man returned error.  Aborting"
	exit 1
fi

rm -rf $tmp
