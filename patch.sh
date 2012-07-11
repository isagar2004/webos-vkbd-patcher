#Copyright (C) 2011 by Dmitry V. Silaev aka Compvir (compvir@compvir.com), Isaac Garzon aka isagar2004
#
#Permission is hereby granted, free of charge, to any person obtaining a copy
#of this software and associated documentation files (the "Software"), to deal
#in the Software without restriction, including without limitation the rights
#to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#copies of the Software, and to permit persons to whom the Software is
#furnished to do so, subject to the following conditions:
#
#The above copyright notice and this permission notice shall be included in
#all copies or substantial portions of the Software.
#
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
#THE SOFTWARE.

source vars
source funcs.sh
source map.sh
OSVERSION=`grep PRODUCT_VERSION_STRING /etc/palm-build-info | sed -e 's/.* webOS \([0-9.]*\).*/\1/'`
USAGE="Usage:\n  sh $0 --help\n  sh $0 {version|generate|revert}\n  OR\n  sh $0 check [<layout file>]\n  OR\n  sh $0 patch <layout file>"
FILE=$FILEPATH
echo "Keyboard layout patcher for HP (TM) TouchPad (r)."
echo "Copyright (C) 2011 by Dmitry V. Silaev aka Compvir (compvir@compvir.com), Isaac Garzon aka isagar2004"
if [ -z $1 ]; then
  echo "ERROR: see usage info"
  echo -e $USAGE
  exit 1
fi
if [ "$1" == "--help" ]; then
  echo ""
  echo "USAGE:"
  echo ""
  echo "sh $0 --help"
  echo "  shows this help info"
  echo ""
  echo "sh $0 version"
  echo "  Checks wheather there are suitable versions of LunaSysMgr to perform
 patching and generaitng processes"
  echo ""
  echo "sh $0 generate"
  echo "  Generates or regenerates <version>.data and <version>.template.json files. The first one is needed for patching and checking processes. The second one is the JSON file containing keyboard layout in UTF-8."
  echo ""
  echo "sh $0 check [<layout file>]"
  echo "  1) If layout file is not given runs a selftest."
  echo "    a) Generates <version>.data file, if it is not present"
  echo "    b) Generates <version>.template.json file, if it is not present"
  echo "    c) Parses <version>.template.json file"
  echo "    d) Copying LunaSysMgr in temp location and patches it"
  echo "    c) Compares original file with patched one and reports if they differ"
  echo "    WARNING: If any differ is reported DO NOT run patching process and contact the developer."
  echo "  2) If layout file is given runs test patching process"
  echo "    a) Generates <version>.data file, if it is not present"
  echo "    b) Parses given layout file"
  echo "    c) Copying LunaSysMgr in temp location and patches it"
  echo "    d) Outputs patched file location"
  echo "    This mode is mostly done for checking this file manually for testing purposes"
  echo "  WARNING: JSON parsing process is taking fair amount of time. For full template it is about 5-8 minutes. Be patient"
  echo ""
  echo "sh patch patch <layout file>"
  echo "  The main patching process. It is doing all the same as check with layout file given, but after creating patched file it is backuping original file and then replacing it with patched one."
  echo "  WARNING: During this process Luna will be restarted so don't do anything important on your Touchpad"
  echo "  WARNING: JSON parsing process is taking fair amount of time. For full template it is about 5-8 minutes. Be patient"
  echo ""
  echo "sh $0 revert"
  echo "  Will replace the patched file with the back upped one"
  echo "  WARNING: During this process Luna will be restarted so don't do anythi
ng important on your Touchpad"
  echo ""
  echo "If you have any questions left contact the developer via compvir@compvir.com prior to any further process"
  exit 0
fi
echo "webOS version "$OSVERSION" found"
echo "Checking main file..."
if [ -f $FILE ]; then
  VERSION=$( getversion $FILE )
  if [ "$VERSION" == "0" ]; then
    echo "Main version not detected"
  else
    source $VERSION.offsets.sh
    echo "Main file "$VERSNAME" version found"
  fi
else
  VERSION=0
  echo "Main file not found"
fi
echo "Checking backup file..."
if [ -f $FILE.orig ]; then
  ORIGVER=$( getversion $FILE.orig )
  if [ "$ORIGVER" == "0" ]; then
    echo "Backup version not detected"
  else
    source $ORIGVER.offsets.sh
    echo "Backup file "$VERSNAME" version found"
  fi
else
  ORIGVER=0
  echo "Backup file not found"
fi
if [ "$1" == "revert" ]; then
  if [ "$VERSION" != "0" ]; then
    echo "Ok. No need to backup. Main file is original"
    exit
  elif [ "$ORIGVER" == "0" ]; then
    echo "ERROR: Backup file is not present or is not original. Would not revert"
    exit 1
  elif [ "$( ls -la $FILE  | awk '{print $5}' )" != "$( ls -la $FILE.orig | awk '{print $5}' )" ]; then
      echo "ERROR: Main and backup files have different size. Will not proceed"
      exit 1
  else
    FILE=$FILE.orig
    VERSION=$ORIGVER
  fi
elif [ "$VERSION" == "0" -a "$ORIGVER" == "0" ]; then
  echo "ERROR: No original version found cannot proceed"
  exit 1
elif [ "$VERSION" != "0" ]; then
  echo "Main file will be used"
  source $VERSION.offsets.sh
elif [ "$( ls -la $FILE  | awk '{print $5}' )" != "$( ls -la $FILE.orig | awk '{print $5}' )" ]; then
  echo "ERROR: Main and backup files have different size. Will not proceed"
  exit 1
else
  echo "Backup file will be used"
  FILE=$FILE.orig
  VERSION=$ORIGVER
fi
case "$1" in
  patch)
  	if [ "${OSVERSION//./}" -le "${ORIGVER//.emul/}" ] || [ "$VERSION" != "0" ]; then
		if [ -z $2 ]; then
			echo "ERROR: No layout file set"
			echo -e $USAGE
			exit 1
		fi
		if [ -f $2 ]; then
			TEMPLATE=$2
		else
			echo "ERROR: Layout file $TEMPLATE does not exist"
			exit 1
		fi
		if [ -f $VERSION.data ]; then
			echo "Found file data $VERSION.data"
			source $VERSION.data
		else
			readdata
		fi
		readtemplate
		if [ "$?" != "0" ]; then
			exit 1
		fi 
		patch
		if [ "$( ls -la $VERSION.patched | awk '{print $5}' )" != "$( ls -la $FILE | awk '{print $5}' )" ]; then
			echo "ERROR: output file size doesn't match"
			exit 1
		fi
		installfile $VERSION.patched
	else
		echo "webOS $OSVERSION is not supported."
		exit 1
	fi
    ;;

  generate)
    rm -f $VERSION.data
    readdata
    rm -f $VERSION.template.json
    gentemplate
    if [ "$?" != "0" ]; then
      exit 1
    fi
    ;;

  revert)
	if [ "${OSVERSION//./}" -gt "${ORIGVER//.emul/}" ]; then
		echo "Backup file is from older webOS version, cannot revert."
		echo "Removing existing backup file to prevent problems."
		echo "Remounting / as rw"
		mount -o rw,remount /
		sleep 5
		if [ "$?" != 0 ]; then
			echo "ERROR. Cannot remount / as writable"
			exit 1
		else
			echo "Removing useless backup file"
			rm -f $FILE.orig
			if [ "$?" != 0 ]; then
				echo "ERROR. Cannot remove old backup file"
				exit 1
			else
				echo "Remounting / back as ro"
				if [ "$?" != 0 ]; then
					echo "WARNING. Cannot remount / as writable"
				fi
			fi
		fi      
	else
		installfile $FILEPATH.orig
	fi
    ;;
  
  check)
    if [ -z $2 ]; then
      echo "Starting self test"
    fi
    if [ -f $VERSION.data ]; then
      source $VERSION.data
      echo "Found file data $VERSION.data"
    else
      date
      readdata
    fi
    if [ -z $2 ]; then
      if [ -f $VERSION.template.json ]; then
        TEMPLATE=$VERSION.template.json
        echo "Template file found $TEMPLATE"
      else
        rm -f $VERSION.template.json
        date
        gentemplate
        if [ "$?" != "0" ]; then
          exit 1
        fi
        TEMPLATE=$VERSION.template.json
     fi
    else
      if [ -f $2 ]; then
        TEMPLATE=$2
      else
        echo "ERROR: Layout file $TEMPLATE does not exist"
        exit 1
      fi
    fi
    date
    readtemplate
    if [ "$?" != "0" ]; then
      exit 1
    fi
    date
    patch
    date
    if [ -z $2 ]; then
      diff $VERSION.patched $FILE
      if [ "$?" != "0" ]; then
        echo "CRITICAL ERROR: input and output file differs. DO NOT USE THIS SCTIPT FOR PATCHING. Contact developer ASAP!!!"
      else
        rm -f $VERSION.patched
        echo "Self test ok. Input file and patched file have no difference"
      fi
    fi
    ;;
 
  version)
    echo "Found suitable version. You can create patch and generate template from it."
    echo "Filename: $FILE"
    echo "Version: $VERSNAME"
    ;;

  *)
    echo "ERROR: see usage info"
    echo -e $USAGE
    exit 1
    ;;

esac
echo "Ok."

exit
