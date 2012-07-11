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

getversion() {
  TMP=0
  for VERS in $VERSIONS ; do
    source $VERS.offsets.sh
    echo -n $CHECKSUM"  "$1 > $VERS.sha1
    if ( sha1sum $VERS.sha1 $SHA1SUMPARAMS > /dev/null ); then
      TMP=$VERS
    fi
    rm -f $VERS.sha1
  done
  echo -n $TMP
  return 0
}

readdata() {
  DATA=
  echo "Reading data from file $FILE"
  let setcount=0
  for LAYOUT in $LAYOUTS; do
    let offset=$( varval $LAYOUT )
    LAYHEX=$( readhex $FILE $offset $(( ( ROWS + ADDROWS ) * $BUTTONS * 16 )) )
    let i=0
    while [ $i -lt $(( ROWS + ADDROWS )) ]; do
      let j=0
      while [ $j -lt $BUTTONS ]; do
        VAR=$LAYOUT"_"$i"_"$j"_WIDTH"
        HEXSTRING=${LAYHEX:$(( ( i * BUTTONS * 16 * 2 ) + ( j * 16 * 2 ) )):32}
        eval $VAR=${HEXSTRING:4:2}
        storedata $VAR
        VAR=$LAYOUT"_"$i"_"$j"_CLASS"
        eval $VAR=${HEXSTRING:6:2}
        storedata $VAR
        VAR=$LAYOUT"_"$i"_"$j"_MAIN_TYPE"
        eval $VAR=${HEXSTRING:12:4}
        storedata $VAR
        VAR=$LAYOUT"_"$i"_"$j"_MAIN_CHAR"
        TMP=${HEXSTRING:10:2}${HEXSTRING:8:2}
        eval $VAR=$TMP
        storedata $VAR
        VAR=$LAYOUT"_"$i"_"$j"_SEC_TYPE"
        eval $VAR=${HEXSTRING:20:4}
        storedata $VAR
        VAR=$LAYOUT"_"$i"_"$j"_SEC_CHAR"
        eval $VAR=${HEXSTRING:18:2}${HEXSTRING:16:2}
        storedata $VAR
        PTN=${HEXSTRING:30:2}${HEXSTRING:28:2}${HEXSTRING:26:2}${HEXSTRING:24:2}
        VAR=$LAYOUT"_"$i"_"$j"_EXT"
        if [ "$PTN" != "00000000" ]; then
          let flag=0
          let l=0
          while [ $l -lt $setcount ]; do
            SET="SET"$l
            if [ "$( varval $SET )" == "$PTN" ]; then
              eval $VAR=$SET
              storedata $VAR
              let flag=1
            fi
            l=$(( l + 1 ))
          done
          if [ $flag -eq 0 ]; then
            SET="SET"$setcount
            setcount=$(( setcount + 1 ))
            eval $VAR=$SET
            storedata $VAR
            eval $SET=$PTN
          fi
        else
          eval $VAR=
          storedata $VAR
        fi
        offset=$(( offset + 16 ))
        j=$(( j + 1 ))
      done
      i=$(( i + 1 ))
    done
  done
  storedata "setcount"
  let minset=0x$SET0
  MINSET=SET0
  let i=1
  while [ $i -lt $setcount ]; do
    CURSET=SET$i
    let curset=0x$( varval $CURSET )
    if [ $curset -lt $minset ]; then
      minset=$curset
      MINSET=$CURSET
    fi
    i=$(( i + 1 ))
  done
  let startset=$EXTENDED
  let i=0
  while [ $i -lt $setcount ]; do
    CURSET=SET$i
    storedata $CURSET
    let curset=0x$( varval $CURSET )
    let curoffset=$(( startset + curset - minset ))
    let offset=$curoffset
    let flag=1
    let charsinset=0
    while [ $flag -eq 1 ]; do
      CHAR=$( readhex $FILE $(( offset + 1 )) 1 )$( readhex $FILE $offset 1 )
      TYPE=$( readhex $FILE $(( offset + 2 )) 2 )
      if [ "$CHAR$TYPE" == "00000000" ]; then
        flag=0
      else
        VAR=$CURSET"_"$charsinset"_TYPE"
        eval $VAR=$TYPE
        storedata $VAR
        VAR=$CURSET"_"$charsinset"_CHAR"
        eval $VAR=$CHAR
        storedata $VAR
        charsinset=$(( charsinset + 1 ))
        offset=$(( offset + 4 ))
      fi
    done
    VAR=$CURSET"_COUNT"
    eval $VAR=$charsinset
    storedata $VAR
    VAR=$CURSET"_OFFSET"
    eval $VAR=$curoffset
    storedata $VAR
    i=$(( i + 1 ))
  done
  echo "Storing data into $VERSION.data"
  echo -ne $DATA > $VERSION.data
  return 0
}

readhex() {
  # reading chars as hexcode from file $1 at offset $2 count $3
  echo -n $( hexdump -v -e '1/1 "%02X"' -s $2 -n $3 $1 )
  return 0
}

UCS22UTF() {
  # converting 2 byte Unicode hexstring to UTF-8 character
  if [ "$1" == "0022" ]; then
    CHR="\\\""
  elif [ "$1" == "005C" ]; then
    CHR="\\\\"
  else
    let char=0x$1
    if [ $char -le $(( 0x7F )) ]; then
      #1 Byte
      CHR1="\x"$( printf "%02X" $char )
      CHR=$( echo -ne $CHR1 )
    elif [ $char -le $(( 0x7FF )) ]; then
      #2 Bytes
      CHR2="\x"$( printf "%02X" $(( ( $char & 0x3F ) | 0x80 )) )
      CHR1="\x"$( printf "%02X" $(( ( ( $char >> 6 ) & 0x1F ) | 0xC0 )) )
      CHR=$( echo -ne $CHR1$CHR2 )
    else
      #3 Bytes
      CHR3="\x"$( printf "%02X" $(( ( $char & 0x3F ) | 0x80 )) )
      CHR2="\x"$( printf "%02X" $(( ( ( $char >> 6 ) & 0x3F ) | 0x80 )) )
      CHR1="\x"$( printf "%02X" $(( ( ( $char >> 12 ) & 0x0F ) | 0xE0 )) )
      CHR=$( echo -ne $CHR1$CHR2$CHR3 )
    fi
  fi
  echo "$CHR"
  return 0
}

varval() {
  eval echo -n \$$1
  return 0
}

getmap() {
  if [ -z $3 ]; then
    VALUE="VALUE"
    NAME="NAME"
  else
    VALUE="NAME"
    NAME="VALUE"
  fi
  let i=0
  let flag=1
  VAR=$( varval $1$i"_"$VALUE )
  while [ "$VAR" != "" -a $flag -eq 1 ]; do
    if [ "$VAR" == "$2" ]; then
      flag=0
      RES=$( varval $1$i"_"$NAME )
    fi
    i=$(( i + 1 ))
    VAR=$( varval $1$i"_"$VALUE )
  done
  if [ $flag -eq 1 ]; then
    echo "ERROR: Unmatched symbol found! ( $1 == $2 )"
    return 1
  fi
  echo -n "$RES"
  return 0
}

gentemplate() {
  echo "Generating template"
  cp /dev/null tmp
  echo "{" >> tmp
  echo -n "    \"layouts\": {" >> tmp
  LAYSEP=
  for LAYOUT in $LAYOUTS; do
    echo $LAYSEP >> tmp
    LAYSEP=","
    echo "        \"$LAYOUT\": {" >> tmp
    let i=0
    ROWSEP=","
    while [ $i -lt $(( ROWS + ADDROWS )) ]; do
      echo "            \"$i\": {" >> tmp
      let j=0
      BUTSEP=","
      while [ $j -lt $BUTTONS ]; do
        echo "                \"$j\": {" >> tmp
        BUTTON=$LAYOUT"_"$i"_"$j
        WIDTH=$( varval $BUTTON"_WIDTH" )
        WIDTH=$( getmap WIDTH $WIDTH )
        if [ "$?" != "0" ]; then echo $WIDTH ; return 1; fi
        echo "                    \"WIDTH\": \"$WIDTH\"," >> tmp
        CLASS=$( varval $BUTTON"_CLASS" )
        CLASS=$( getmap CLASS $CLASS )
        if [ "$?" != "0" ]; then echo $CLASS ; return 1; fi
        echo "                    \"CLASS\": \"$CLASS\"," >> tmp
        MAIN=$( varval $BUTTON"_MAIN_CHAR" )
        MTYPE=$( varval $BUTTON"_MAIN_TYPE" )
        if [ "$MTYPE" == "0000" ]; then
          MAIN=$( UCS22UTF $MAIN )
        fi
        MTYPE=$( getmap TYPE $MTYPE )
        if [ "$?" != "0" ]; then echo $MTYPE ; return 1; fi
        echo -n "                    \"MAIN\": {" >> tmp
        echo -n "\"TYPE\": \"$MTYPE\", " >> tmp
        echo "\"CHAR\": \"$MAIN\"}," >> tmp
        SEC=$( varval $BUTTON"_SEC_CHAR" )
        STYPE=$( varval $BUTTON"_SEC_TYPE" )
        if [ "$STYPE" == "0000" ]; then
          SEC=$( UCS22UTF "$SEC" )
        fi
        STYPE=$( getmap TYPE $STYPE )
        if [ "$?" != "0" ]; then echo $STYPE ; return 1; fi
        echo -n "                    \"SEC\": {" >> tmp
        echo -n "\"TYPE\": \"$STYPE\", " >> tmp
        echo "\"CHAR\": \"$SEC\"}," >> tmp
        EXT=$( varval $BUTTON"_EXT" )
        echo "                    \"EXT\": \"$EXT\"" >> tmp
        j=$(( j + 1 ))
        if [ $j -eq $BUTTONS ]; then
          BUTSEP=
        fi
        echo "                }$BUTSEP" >> tmp
      done
      i=$(( i + 1 ))
      if [ $i -eq $(( ROWS + ADDROWS )) ]; then
        ROWSEP=
      fi
      echo "            }$ROWSEP" >> tmp
    done
    echo -n "        }" >> tmp
  done
  echo "" >> tmp
  echo "    }," >> tmp
  echo "    \"sets\": {" >> tmp
  let i=0
  SETSEP=","
  while [ $i -lt $setcount ]; do
    CURSET=SET$i
    echo "        \"$CURSET\": {" >> tmp
    VAR=$CURSET"_COUNT"
    let j=0
    let count=$( varval $VAR )
    CHARSEP=","
    while [ $j -lt $count ]; do
      echo -n "            \"$j\": {" >> tmp
      CHAR=$( varval $CURSET"_"$j"_CHAR" )
      TYPE=$( varval $CURSET"_"$j"_TYPE" )
      if [ "$TYPE" == "0000" ]; then
        CHAR=$( UCS22UTF $CHAR )
      fi
      TYPE=$( getmap TYPE $TYPE )
      if [ "$?" != "0" ]; then echo $TYPE ; return 1; fi
      echo -n "\"TYPE\": \"$TYPE\", " >> tmp
      j=$(( j + 1 ))
      if [ $j -eq $count ]; then
        CHARSEP=
      fi
      echo "\"CHAR\": \"$CHAR\"}$CHARSEP" >> tmp
    done
    i=$(( i + 1 ))
    if [ $i -eq $setcount ]; then
      SETSEP=
    fi
    echo "        }$SETSEP" >> tmp
  done
  echo "    }," >> tmp
  echo "    \"params\": {" >> tmp
  echo "        \"REGIONPATCH\": \"0\"," >> tmp
  echo "        \"LANGCODE\": {" >> tmp
  echo "            \"0\": \"\"" >> tmp
  echo "        }" >> tmp
  echo "    }," >> tmp
  echo "}" >> tmp
  echo "Writing template to file $VERSION.template.json"
  mv tmp $VERSION.template.json
  return 0
}

storedata () {
  DATA=$DATA$1"="$( varval $1 )"\\n"
}

readtemplate () {
  echo "Reading template $TEMPLATE and redefining variables"
  #Removing line breaks
  sed -n -e ":a" -e "$ s/\n//gp;N;b a" $TEMPLATE > tmp
  #Replacing special chars and adding my delimeters
  sed -e 's/" "/"sp"/g;s/"\\""/"qt"/g;s/\s*//g;s/{"layouts":{//g;s/},"sets":{//g;s/},"params":{//g;s/"\([^"]*\)":{/\1_/g;s/"\([^"]*\)":\("[^"]*"\),\?/|\1=\2 /g;s/},/}/g' tmp > tmp0
  mv tmp0 tmp
  CURPREFIX=
  SYMB=$( cut -c1 tmp )
  while [ "$SYMB" != "" ]; do
    SYMB=$( cut -c1 tmp )
    if [ "$SYMB" != "}" ]; then
      if [ "$SYMB" != "|" ]; then
        CURPREFIX=$CURPREFIX$( cut -s -d\| -f1 tmp )
      fi
      VAR=$( cut -s -d\| -f2- tmp | cut -s -d= -f1 )
      if [ "$CURPREFIX$VAR" != "" ]; then
        VAL=$( cut -s -d= -f2- tmp | cut -s -d\  -f1 )
        VAL=${VAL:1:$(( ${#VAL} - 2 ))}
        if [ "$VAR" == "WIDTH" -o "$VAR" = "CLASS" -o "$VAR" = "TYPE" ]; then
          VAL=$( getmap $VAR $VAL 1 )
          if [ "$?" != "0" ]; then echo $VAL ; return 1; fi
        fi
        if [ "$VAR" == "TYPE" ]; then
          TYPE=$VAL
        fi
        if [ "$VAR" == "CHAR" ]; then
          if [ -z "$VAL" ]; then
            VAL="0000"
          elif [ "$TYPE" == "0000" ]; then
            VAL=$( echo -n "$VAL" | hexdump -v -e '1/1 "%02X"' ) 
            if [ "$VAL" == "7174" ]; then
              VAL="0022"
            elif [ "$VAL" == "7370" ]; then
              VAL="0020"
            elif [ "$VAL" == "5C5C" ]; then
              VAL="005C"
            else
              VAL=$( UTF2UCS2 "$VAL" )
            fi
          fi
        fi
        eval $CURPREFIX$VAR=$VAL
      fi
      cut -s -d\  -f2- tmp > tmp0
    else
      cut -c2- tmp > tmp0
      CURPREFIX=$( echo $CURPREFIX | sed -e 's/[^_]*_$//g' )
    fi
    mv tmp0 tmp
  done
  rm -f tmp
}

patch() {
  echo "Copying source file to temp location"
  cp $FILE tmp
  echo "Applying patch to tempfile"
  for LAYOUT in $LAYOUTS; do
    let offset=$( varval $LAYOUT )
    let i=0
    while [ $i -lt $(( ROWS + ADDROWS )) ]; do
      let j=0
      while [ $j -lt $BUTTONS ]; do
        BUTTON=$LAYOUT"_"$i"_"$j
        WIDTH="\x00\x00\x"$( varval $BUTTON"_WIDTH" )
        CLASS="\x"$( varval $BUTTON"_CLASS" )
        MAIN=$( varval $BUTTON"_MAIN_CHAR" )
        MAIN="\x"${MAIN:2:2}"\x"${MAIN:0:2}
        MTYPE=$( varval $BUTTON"_MAIN_TYPE" )
        MTYPE="\x"${MTYPE:0:2}"\x"${MTYPE:2:2}
        SEC=$( varval $BUTTON"_SEC_CHAR" )
        SEC="\x"${SEC:2:2}"\x"${SEC:0:2}
        STYPE=$( varval $BUTTON"_SEC_TYPE" )
        STYPE="\x"${STYPE:0:2}"\x"${STYPE:2:2}
        EXT=$( varval $BUTTON"_EXT" )
        if [ "$EXT" == "" ]; then
          EXT="\x00\x00\x00\x00"
        else
          EXT=$( varval $EXT )
          EXT="\x"${EXT:6:2}"\x"${EXT:4:2}"\x"${EXT:2:2}"\x"${EXT:0:2}
        fi
        BUTT=$WIDTH$CLASS$MAIN$MTYPE$SEC$STYPE$EXT
        if [ ${#BUTT} -ne 64 ]; then
          echo "ERROR: Something bad happened replace data doesn't match length"
          echo $BUTT ${#BUTT}
          return 1
        fi
        echo -ne $BUTT | dd of=tmp seek=$offset ibs=1 obs=1 count=16 conv=notrunc 2>/dev/null
        j=$(( j + 1 ))
        offset=$(( offset + 16 ))
      done
      i=$(( i + 1 ))
    done
  done
  let i=0
  while [ $i -lt $setcount ]; do
    CURSET=SET$i
    VAR=$CURSET"_OFFSET"
    offset=$( varval $VAR )
    VAR=$CURSET"_COUNT"
    let j=0
    let count=$( varval $VAR )
    while [ $j -lt $count ]; do
      CHAR=$( varval $CURSET"_"$j"_CHAR" )
      CHAR="\x"${CHAR:2:2}"\x"${CHAR:0:2}
      TYPE=$( varval $CURSET"_"$j"_TYPE" )
      TYPE="\x"${TYPE:0:2}"\x"${TYPE:2:2}
      ADD=$CHAR$TYPE
      if [ ${#ADD} -ne 16 ]; then
        echo "ERROR: Something bad happened replace data doesn't match length"
        echo $ADD ${#ADD}
        return 1
      fi
      echo -ne $ADD | dd of=tmp seek=$offset ibs=1 obs=1 count=4 conv=notrunc 2>/dev/null
      offset=$(( offset + 4 ))
      j=$(( j + 1 ))
    done
    i=$(( i + 1 ))
  done
  mv tmp $VERSION".patched"
  if [ "$REGIONPATCH" == "1" ]; then
    echo "Patching regional keys"
    regionpatch
  fi
  echo "Patched file $VERSION.patched generated"
  return 0
}

installfile() {
  echo "Installation started"
  let error=0
  echo "Remounting / as rw"
  mount -o rw,remount /
  sleep 5
  if [ "$?" != 0 ]; then
    echo "ERROR. Cannot remount / as writable"
    error=1
  fi
  if [ "$error" == "0" ]; then
    if [ "$VERSION" != "$ORIGVER" ]; then
      echo "Backuping original file into $FILEPATH.orig"
      cp -dpR $FILE $FILE.orig
      if [ "$?" != 0 ]; then
        echo "ERROR. Cannot backup file $FILEPATH to $FILEPATH.orig"
        error=2
      fi
    else
      echo "Original file aleready backed up in $FILEPATH.orig"
    fi
  fi
  if [ "$error" == "0" ]; then
    echo "Stopping Luna"
    initctl stop LunaSysMgr > /dev/null
    sleep 5
    if [ "$?" != 0 ]; then
      echo "ERROR. Cannot stop Luna"
      error=3
    fi
  fi
  if [ "$error" == "0" ]; then
    echo "Coping file $1 to $FILEPATH"
    cp $1 $FILEPATH
    if [ "$?" != 0 ]; then
      echo "ERROR. Cannot replace file with patched one"
      error=4
    fi
  fi
#  if [ "$error" == "0" ]; then
#    let i=0
#    if [ -f /usr/lib/luna/customization/locale.txt ]; then
#      LOCALEPATH=/usr/lib/luna/customization/locale.txt
#    else
#      LOCALEPATH=/etc/palm/locale.txt
#    fi
#    if [ ! -f $LOCALEPATH.orig ]; then
#      cp -dpR $LOCALEPATH $LOCALEPATH.orig
#    fi
#    sed "/^.*KeyBoardPatch_.*$/d" $LOCALEPATH > locale.txt
#    while [ "$( varval LANGCODE_$i )" != "" ]; do
#      LANGCODE=$( varval LANGCODE_$i )
#      if [ -n "$( grep "\"languageCode\":\"$LANGCODE\"" locale.txt )" ]; then
#        echo "Language code \"$LANGCODE\" already present"
#      else
#        echo "Adding language code \"$LANGCODE\" to locale.txt"
#        sed "3i{\"languageName\":\"KeyBoardPatch_$LANGCODE\",\"languageCode\":\"$LANGCODE\",\"countries\":[{\"countryName\":\"Dummy_$LANGCODE\",\"countryCode\":\"$LANGCODE\"}]}," locale.txt > tmp
#        mv tmp locale.txt
#      fi
#      i=$(( i + 1 ))
#    done
#    mv locale.txt $LOCALEPATH
#    chmod 640 $LOCALEPATH
#  fi
  if [ $error -gt 3 -o $error -eq 0 ]; then
    echo "Starting Luna"
    initctl start LunaSysMgr > /dev/null
    if [ "$?" != 0 ]; then
      echo "WARNING. Cannot start Luna"
    fi
  fi
  if [ $error -ne 1 ]; then
    echo "Remounting / back as ro"
    mount -o ro,remount /
    if [ "$?" != 0 ]; then
      echo "WARNING. Cannot remount / as writable"
    fi
  fi
  if [ "$1" == "$VERSION.patched" ]; then
    echo "Removing temp file $VERSION.patched"
    rm -f $VERSION.patched
  fi
  return $error
}

regionpatch() {
  let i=0
  while [ "$( varval "SPECIAL"$i"_OFFSET" )" != "" ]; do
    let offset=$( varval "SPECIAL"$i"_OFFSET" )
    CHR=$( readhex $FILE $offset 1 )
    if [ "$CHR" == "$( varval 'SPECIAL'$i'_FROM' )" ]; then
      echo -ne "\x"$( varval "SPECIAL"$i"_TO" ) | dd of=$VERSION.patched seek=$offset ibs=1 obs=1 count=1 conv=notrunc 2>/dev/null
    fi
    i=$(( i + 1 ))
  done 
}

UTF2UCS2() {
  HEXSTR=$1
  CHR1=${HEXSTR:0:2}
  CHR2=${HEXSTR:2:2}
  CHR3=${HEXSTR:4:2}
  if [ -z $CHR2 ]; then
    #1 Byte
    CHR="00"$CHR1
  elif [ -z $CHR3 ]; then
    #2 Byte
    let chr2=0x$CHR1
    let chr1=0x$CHR2
    chr1=$(( chr1 & 0x3F ))
    chr2=$(( ( chr2 & 0x1F ) << 6 ))
    chr1=$(( chr1 | chr2 ))
    CHR=$( printf "%04X" $chr1 )
  else
    #3 Byte
    let chr3=0x$CHR1
    let chr2=0x$CHR2
    let chr1=0x$CHR3
    chr1=$(( chr1 & 0x3F ))
    chr2=$(( ( chr2 & 0x3F ) << 6  ))
    chr3=$(( ( chr3 & 0x0F ) << 12 ))
    chr1=$(( chr1 | chr2 | chr3 ))
    CHR=$( printf "%04X" $chr1 )
  fi
  echo -n "$CHR"
}

