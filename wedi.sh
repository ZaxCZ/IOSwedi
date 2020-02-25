#!/bin/sh

###### EDITOR VARIABLE START ######
MYEDITOR='' #promena, ve ktere bude nazev editoru, pouziva se pri jeho spousteni
if [ -z "$EDITOR" ];  then
  if [ -z "$VISUAL" ]; then
    echo "EDITOR and VISUAL variables are not set" 1>&2
    exit 1  # chyba
  else
    MYEDITOR="$VISUAL"
  fi
else
  MYEDITOR="$EDITOR"
fi
#EDITOR=nano  #zakomentovat!
###### EDITOR VARIABLE END ######

###### WEDI_RC VARIABLE START ######
if [ -z "$WEDI_RC" ];  then
  echo "WEDI_RC variable is not set" 1>&2
  exit 1  # chyba
fi
touch "$WEDI_RC"
###### WEDI_RC VARIABLE END ######


###### FUNCTIONS START ######

#nahrada newline
nl='
'

# odstrani tecku na zacatku passed predela potencionalni relativni path v PASSED na absolutni
checkpath() {
  TMP=`realpath "$PASSED" 2>&1 | rev | cut -b -9 | rev`
  if [ ! "$TMP" = "directory" ]; then
    PASSED=`realpath "$PASSED"`
  else
    PASSED="`realpath`/"$PASSED""
  fi
}

#ulozi zaznam o editaci/vytvoreni souboru
log() {
  echo "`date "+%Y-%m-%d"` + ${PASSED}" >> $WEDI_RC
}

#najde nejcasteji pouzivany soubor z adresare
findmost() {
  SIZE=$((${#PASSED}+14))

  #do LIST se ulozi seznam v poradi od nejcasteji editovaneho souboru - jenom nazvy a pripony
  LIST="`sed '1!G;h;$!d' "$WEDI_RC" | grep "$PASSED" | cut -b ${SIZE}- | grep -v / | sort -n | uniq -c | sort -n -r |  sed -e 's/^[ \t]*//' | cut -c 3-`"
  IFS="$(printf '\n ')" && IFS="${IFS% }"
  for ITEM in $LIST
  do
    if [ -f "${PASSED}${ITEM}" ];  then #jestlize je to validni soubor - existuje -> otevreme a koncime
      PASSED="$PASSED$ITEM"
      log
      $MYEDITOR "${PASSED}"
      exit $?
    fi
  done

  #pokud to projde loopem, tak nebyly zadne soubory editovany
  echo "No files were edited in ${PASSED}" 1>&2
  exit 1
}

#najde posledni otevreny soubor z adresare
latest() {
  SIZE=$((${#PASSED}+14))  # delka  cesty v passed   + 14 (datum)

  LATEST="`sed '1!G;h;$!d' "$WEDI_RC" | grep "$PASSED" | cut -b ${SIZE}- | grep -v / | uniq`"   # uniq je optimalizace
  #echo "$LATEST"

  IFS="$(printf '\n ')" && IFS="${IFS% }"
  for ITEM in $LATEST
  do
    if [ -f "${PASSED}${ITEM}" ];  then #jestlize je to validni soubor - existuje -> otevreme a koncime
      PASSED="$PASSED$ITEM"
      log
      $MYEDITOR "${PASSED}"
      exit $?
    fi
  done
  echo "No files were edited in ${PASSED}" 1>&2
  exit 1
}

#vypise seznam souboru v adresari, pro ktere ma wedi zaznam
list() {
  SIZE=$((${#PASSED}+14))  # delka  cesty v passed   + 14 (datum)

  LIST="`sed '1!G;h;$!d' "$WEDI_RC" | grep "$PASSED" | cut -b ${SIZE}- | grep -v / | sort -n | uniq`"

  BOOL=0

  IFS="$(printf '\n ')" && IFS="${IFS% }"
  for ITEM in $LIST
  do
    if [ -f "${PASSED}${ITEM}" ];  then #jestlize je to validni soubor - existuje -> otevreme a koncime
      echo "$ITEM"  #  | sed 's/^/./'    prida tecku na zacatek
      BOOL=1
    fi
  done

  if [ $BOOL -eq 0 ];
    then
    echo "No files were edited in ${PASSED}"  #### je to chyba ???? kdyztak patch
  fi
  exit 0
  #viz latest
}

#overi, zda konci filepath k adresari lomitkem, jestli ne, prida ho
checkend() {
  i=$((${#PASSED}))   # vrati poradi predposledniho znaku
  CHECK="$(echo "$PASSED" | cut -c $i-)" # posledni znak do CHECK
  #CHECK="${PASSED:$i:1}" # posledni znak do CHECK
  if [ ! "$CHECK" = "/" ];  then
    PASSED="$PASSED/"
  fi
}

before() {
  SIZE=$((${#PASSED}+14))  # delka  cesty v passed   + 14 (datum)
  LIST="`sort -n $WEDI_RC | uniq`" #sed '/'$DATUM'/,$d' | grep "$PASSED" | cut -b ${SIZE}- | grep -v / | sort -n | uniq`"

  BOOL=0
  DATUM=`echo $DATUM | cut -b -9`$((`echo $DATUM | cut -b 10-`+1))

  LIST="$LIST${nl}$DATUM"  # prida hledane datum na konec listu
  #LIST="$LIST$DATUM" # spatne
  #echo "$LIST" # debug

  LIST="`echo "$LIST" | sort -n  | sed '/'$DATUM'/,$d' | grep "$PASSED" | cut -b ${SIZE}- | grep -v / | sort -n | uniq`"
  IFS="$(printf '\n ')" && IFS="${IFS% }"
  for ITEM in $LIST
  do
    #IDATUM="$(echo "$ITEM" >> cut -c -12)"
    #echo "$IDATUM"
    if [ -f "${PASSED}${ITEM}" ];  then #je to soubor, vypiseme
      echo "$ITEM"   #  | sed 's/^/./'    prida tecku na zacatek
      BOOL=1
    fi
  done

  if [ $BOOL -eq 0 ];
    then
    echo "No files were edited in ${PASSED} before ${DATUM}"  #### je to chyba ???? kdyztak patch
  fi
  exit 0
}

after() {
  SIZE=$((${#PASSED}+14))  # delka  cesty v passed   + 14 (datum)
  LIST="`sort -n $WEDI_RC | uniq`" #sed '/'$DATUM'/,$d' | grep "$PASSED" | cut -b ${SIZE}- | grep -v / | sort -n | uniq`"
  BOOL=0

  LIST="$LIST${nl}$DATUM"   # prida hledane datum na konec listu
  #LIST="$LIST$DATUM"
  #echo "$LIST"
  #(echo "HELLO"; cat file1) | sed '1,/'$DATUM'/d'  kvuli tomu, ze freebsd nema rado 0 v sedu
  LIST="`echo "$LIST" | (echo "HELLO"; sort -n) | sed '1,/'$DATUM'/d' | grep "$PASSED" | cut -b ${SIZE}- | grep -v / | sort -n | uniq`"
  #LIST="`echo "$LIST" | sort -n  | sed '0,/'$DATUM'/d' | grep "$PASSED" | cut -b ${SIZE}- | grep -v / | sort -n | uniq`"
  #echo "$LIST"

  IFS="$(printf '\n ')" && IFS="${IFS% }"
  for ITEM in $LIST
  do
    #IDATUM="$(echo "$ITEM" >> cut -c -12)"
    #echo "$IDATUM"
    if [ -f "${PASSED}${ITEM}" ];  then #je to soubor, vypiseme
      echo "$ITEM"  #  | sed 's/^/./'    prida tecku na zacatek
      BOOL=1
    fi
  done

  if [ $BOOL -eq 0 ];
    then
    echo "No files were edited in ${PASSED} after ${DATUM}"  #### je to chyba ???? kdyztak patch
  fi
  exit 0

}
###### FUNCTIONS END ######


###### ARG HANDLING START ######
#pro 0 argumentu
if [ $# -eq 0 ]; then
  #START wedi          // aktualni adresar
  PASSED="`realpath`/"  # aktualni adresar do promenne PASSED
  latest                                                         
  #END   wedi          // aktualni adresar   
#pro 0 argumentu END

#pro 1 argument
elif [ $# -eq 1 ]; then 

  if [ "$1" = "-m" ]; then
    #START wedi -m    // aktualni adresar
    PASSED="`realpath`/"  # aktualni adresar do promenne PASSED
    findmost

    #END   wedi -m    // aktualni adresar


  elif [ "$1" = "-l" ]; then 
    #START wedi -l    // aktualni adresar
    PASSED="`realpath`/"  # aktualni adresar do promenne PASSED
    list 
    #END   wedi -l    // aktualni adresar      


  else 
    #START wedi [ADRESÁŘ]     nebo      wedi SOUBOR
    PASSED=$1   # prvni argument do promene PASSED
    checkpath

    if   [ -d "${PASSED}" ];  then #v argumentu je adresar - pracujeme s adresarem 
      checkend
      latest 
    elif [ -f "${PASSED}" ];  then #v argumentu je soubor - pracujeme se souborem 
      log
      $MYEDITOR "${PASSED}"
      exit $? 
    else  # neexistuje - predhodime to editoru a vratime jeho navratovou hodnotu 
      log
      $MYEDITOR "${PASSED}"
      exit $?  
    fi
    #END   wedi [ADRESÁŘ]     nebo      wedi SOUBOR               
  fi                                        
#pro 1 argument END


#pro 2 argumenty
elif [ $# -eq 2 ]; then                       

 if [ "$1" = "-m" ]; then
    #START wedi -m [ADRESÁŘ]   // zadany adresar
    PASSED=$2   # druhy argument do promene PASSED
    checkpath

    if   [ -d "${PASSED}" ];  then #v argumentu je adresar - pracujeme s adresarem

      #UNICORN MAGIC ON
      checkend
      findmost
      #UNICORN MAGIC OFF
    else  # spatny argument - error
      echo "${PASSED} is not a directory" 1>&2
      exit 1
    fi
    #END   wedi -m [ADRESÁŘ]   // zadany adresar


  elif [ "$1" = "-l" ]; then
    #START wedi -l [ADRESÁŘ]  // zadany adresar 
    PASSED=$2   # druhy argument do promene PASSED
    checkpath 

    if   [ -d "${PASSED}" ];  then #v argumentu je adresar - pracujeme s adresarem 
      checkend
      list
    else  # spatny argument - error 
      echo "${PASSED} is not a directory" 1>&2
      exit 1
    fi
    #END   wedi -l [ADRESÁŘ]  // zadany adresar


  elif [ "$1" = "-b" ]; then
    #START wedi -b DATUM     // aktualni adresar
    DATUM=$2 # druhy argument do promene DATUM
	
    #d=${DATUM:8:2}; m=${DATUM:5:2}; Y=${DATUM:0:4};
    #if ! date -d "$DATUM";
    #then
    #  echo "Invalid date"
    #fi

    PASSED="`realpath`/"  # aktualni adresar do promenne PASSED
    before

    #END   wedi -b DATUM     // aktualni adresar


  elif [ "$1" = "-a" ]; then
    #START wedi -a DATUM    // aktualni adresar
    DATUM=$2 # druhy argument do promene DATUM
	
    #d=${DATUM:8:2}; m=${DATUM:5:2}; Y=${DATUM:0:4};
    #if ! date -d "$DATUM";
    #then
    #  echo "Invalid date"
    #fi

    PASSED="`realpath`/"  # aktualni adresar do promenne PASSED
    after
    #END   wedi -a DATUM    // aktualni adresar


  else
    echo "Wrong arguments" 1>&2
    exit 1
  fi                                         
#pro 2 argumenty END


#pro 3 argumenty
elif [ $# -eq 3 ]; then

  if [ "$1" = "-b" ]; then
    #START wedi -b DATUM [ADRESÁŘ]   // zadany adresar
    DATUM=$2 # druhy argument do promene DATUM
	
    #d=${DATUM:8:2}; m=${DATUM:5:2}; Y=${DATUM:0:4};
    #if ! date -d "$DATUM";
    #then
    #  echo "Invalid date"
    #fi

    PASSED=$3 # treti argument do promene PASSED
    checkpath

    if   [ -d "${PASSED}" ];  then #v argumentu je adresar - pracujeme s adresarem
      checkend
      before
    else  # spatny argument - error
      echo "${PASSED} is not a directory" 1>&2
      exit 1
    fi
    #END   wedi -b DATUM [ADRESÁŘ]   // zadany adresar


  elif [ "$1" = "-a" ]; then
    #START wedi -a DATUM [ADRESÁŘ]  // zadany adresar
    DATUM=$2 # druhy argument do promene DATUM
	
    #d=${DATUM:8:2}; m=${DATUM:5:2}; Y=${DATUM:0:4};
    #if ! date -d "$DATUM";
    #then
    #  echo "Invalid date"
    #fi

    PASSED=$3 # treti argument do promene PASSED
    checkpath

    if   [ -d "${PASSED}" ];  then #v argumentu je adresar - pracujeme s adresarem
      checkend
      after
    else  # spatny argument - error
      echo "${PASSED} is not a directory" 1>&2
      exit 1
    fi
    #END   wedi -a DATUM [ADRESÁŘ]  // zadany adresar


  else
    echo "Wrong arguments" 1>&2
    exit 1
  fi                                          
#pro 3 argumenty END



else                                          #pro >3 arg
  echo "The amount of your arguments is unbearable" 1>&2
  exit 1  # chyba
fi
###### ARG HANDLING END ######

echo "If you see this, something went terribly wrong" 1>&2
exit 1
