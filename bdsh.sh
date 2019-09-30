#!/bin/bash

displayHelp() {
    printf "\tWelcome to Database Shell Manager = Julien Legay 2019\n"
    printf "\t            -=      Helping board      =-            \n "
    printf "\t-----------------------------------------------------\n\n"
    printf "\tDatabase management : \n"
    printf "\t -f     | select JSON file (-f test.json)\n"
    printf "\t --save | store selected JSON file for futures operations\n"
    printf "\t -b     | beautify JSON, indenting file\n"
    printf "\t -d     | displaying the database in JSON\n\n"
    printf "\tCreate management : \n"
    printf "\t create database                 | Create the database\n"
    printf "\t create table (name) (raw1,raw2) | Create table\n\n"
    printf "\tInsert : \n"
    printf "\t insert (tablename) (raw1=[value],raw2=[value]) | insert values\n\n"
    printf "\tflush and delete : \n"
    printf "\t flush [database/table] | drop the table\n"
    printf "\t delete [database/table] | completely deleting the table or the database\n\n"
    printf "\tSelect : \n"
    printf "\t select table raw1,raw2 | displaying elements of the DB\n\n"
    printf "\tGlobal management : \n"
    printf "\t describe table | describing raws used in this table\n"
    printf "\t list [table/database] | list all available JSONDB / tables\n\n"
}

########### Standards Functions ################
checkDatabase() {
  if [ ! -f "db/$BDSH_FILE" ]; then
      echo "BDSH | ERROR | Database $BDSH_FILE doesn't exist"
      exit 1
  fi
}

checkTable() {
  if [ -z "$args1" ]; then
    echo "BDSH | ERROR | Please select a table. use /bdsh list table"
    exit 1
  fi
  if [[ ! "$DATABASE" == *"$args1"* ]]; then
      echo "BDSH | ERROR | Table $args1 doesn't exist"
      exit 1
  fi
}

commandManager() {
  case $command in
      create)
          if [ "$args1" == "database" ]; then
              createDatabase $BDSH_FILE
          elif [ "$args1" == "table" ]; then
              createTable $args2 $args3 $BDSH_FILE
          fi
          ;;
      insert)
          insertData $args1 $args2 $BDSH_FILE
          ;;
      select)
          doSelect $BDSH_FILE $args1 $args2 $args3 $args4
          ;;
      delete)
          if [ -z "$args1" ]; then
              deleteDatabase $BDSH_FILE
          else
              deleteTable $BDSH_FILE $args1
          fi
          ;;
      flush)
          if [ -z "$args1" ]; then
              flushDatabase $BDSH_FILE
          else
              flushTable $BDSH_FILE $args1
          fi
          ;;
      describe)
          doDescribe $BDSH_FILE $args1
          ;;
      list)
          doList $BDSH_FILE
          ;;
      beautify)
          doBeautify $BDSH_FILE
          ;;
  esac
}

############# CREATE DATABASE, TABLE ############

createDatabase() {
    if [ ! -d "db" ]; then
      mkdir "db"
    fi
    if [ ! -f "db/$BDSH_FILE" ]; then
        touch "db/$BDSH_FILE"
        BDSH_NAME=$(echo $BDSH_FILE | cut -d"." -f1)
        echo "{}" >> "db/$BDSH_FILE"
        echo "BDSH | Database \"$BDSH_FILE\" successfully created !"
    else
        echo "BDSH | ERROR : database already exist"
        exit 1
    fi
}

createTable() {
    checkDatabase $BDSH_FILE
    Ttable='"desc_%s": [%s]'
    TdataTable='"data_%s": []'
    DATABASE=$(cat db/$BDSH_FILE | tr -d '\n\r' | tr -s " ");
    TABLENAME="$args2"
    IFS=',' read -r -a COL <<< "$args3"

    if [[ "$DATABASE" == *"data_$TABLENAME"* ]]; then
        echo "BDSH | ERROR | Table already exist."
        exit 1
    else
        for element in "${COL[@]}"
        do
          Tcol=$(echo "$Tcol \"$element\"" )
          if [ ! $element == ${COL[-1]} ]; then
              Tcol=$(echo "$Tcol," )
          fi
        done
        Ttable=$(printf "$Ttable" $TABLENAME "$Tcol")
        TdataTable=$(printf "$TdataTable" $TABLENAME)
        addTable $DATABASE $Ttable
        Ttable=$TdataTable
        addTable $DATABASE $Ttable
        echo "BDSH | $BDSH_FILE | Table successfully created"
    fi
}

addTable() {
    length=$(echo "$DATABASE" | wc -c)
    virgule=""
    if [ "$length" -gt 3 ]; then
      virgule=","
    fi
    DATABASE="${DATABASE:0:1}$Ttable$virgule${DATABASE:1}"
    echo "$DATABASE" > db/$BDSH_FILE
}

###### INSERT DATA INSIDE TABLES ############################

insertData() {
    checkDatabase $BDSH_FILE
    DATABASE=$(cat db/$BDSH_FILE | tr -d '\n\r' | tr -s " ");
    checkTable $BDSH_FILE $args1
    Tinfos="{%s}"
    tableinfos=$(echo $DATABASE |grep -Po '"desc_'$args1'": \[\K[^\]]*')
    table=$(echo $DATABASE |grep -Po '"data_'$args1'": \[\K[^\]]*')
    if [ ! -z "$table" ]; then
        virgule=","
    fi
    DATABASE_INSERT=$(echo $DATABASE|sed -e 's/\("data_'$args1'": \[\)\(\)/\1%s\2/')
    IFS=',' read -r -a INFOS <<< "$args2"
    for element in "${INFOS[@]}"
    do
        key=$(echo $element | cut -d"=" -f1)
        value=$(echo $element | cut -d"=" -f2)
        if [[ "$tableinfos" == *"\"$key\""* ]]; then
            info=$(echo "$info" "\"$key\": \"$value\"" )
            if [ ! "$element" == "${INFOS[-1]}" ]; then
                info=$(echo "$info," )
            else
                info=$(echo "$info ")
            fi
        else
            echo "BDSH | ERROR | Key \"$key\" doesn't exist in $args1"
            exit 1
        fi
    done
    Tinfos=$(printf $Tinfos "$info")
    addData $DATABASE_INSERT $Tinfos $virgule
    info=""
}

addData() {
  DATABASE_INSERT=$(printf "$DATABASE_INSERT" "$Tinfos$virgule")
  echo "$DATABASE_INSERT" > db/$BDSH_FILE
  echo "BDSH | $BDSH_FILE | Data successfully inserted !"
  DATABASE_INSERT=""
}

####### FLUSH OR DELETE DATABASE OR TABLE #################

flushDatabase() {
  checkDatabase $BDSH_FILE
  echo "{}" > db/$BDSH_FILE
  echo "BDSH | $BDSH_FILE | flushed !"
}

deleteDatabase() {
  checkDatabase $BDSH_FILE
  rm db/$BDSH_FILE
  echo "BDSH | $BDSH_FILE | Deleted !"
}

flushTable() {
  checkDatabase $BDSH_FILE
  DATABASE=$(cat db/$BDSH_FILE | tr -d '\n\r' | tr -s " ");
  checkTable $BDSH_FILE $args1
  DATABASE_FLUSHED=$(echo $DATABASE|sed -e 's/\("data_'$args1'": \[\)\([^]]*\]\)\(\)/\1]\3/')
  echo $DATABASE_FLUSHED > db/$BDSH_FILE
  echo "BDSH | $BDSH_FILE | Table flushed !"
}

deleteTable() {
  checkDatabase $BDSH_FILE
  DATABASE=$(cat db/$BDSH_FILE | tr -d '\n\r' | tr -s " ");
  checkTable $BDSH_FILE $args1
  DATABASE_FLUSHED=$(echo $DATABASE|sed -e 's/\("data_'$args1'": \[[^]]*\]\)\(\)/\2/')
  DATABASE_FLUSHED=$(echo $DATABASE_FLUSHED |sed -e 's/\("desc_'$args1'": \[[^]]*\]\)\(\)/\2/')
  DATABASE_FLUSHED=$(echo $DATABASE_FLUSHED | sed -e 's/, ,/,/g' | sed -e 's/{ ,/{/g' | sed -e 's/, }/}/g')
  DATABASE_FLUSHED=$(echo $DATABASE_FLUSHED | sed -e 's/,,/,/g' | sed -e 's/{,/{/g' | sed -e 's/,}/}/g')
  echo $DATABASE_FLUSHED > db/$BDSH_FILE
  echo "BDSH | $BDSH_FILE | Table deleted !"
}

################## SMALLS COMMANDS ##############

doDescribe() {
    checkDatabase $BDSH_FILE
    DATABASE=$(cat db/$BDSH_FILE | tr -d '\n\r' | tr -s " ");
    checkTable $DATABASE $args1
    tableinfos=$(echo $DATABASE |grep -Po '"desc_'$args1'": \[\K[^\]]*')
    tableinfos=$(echo $tableinfos | sed -e s/\"//g)
    IFS=', ' read -r -a tableinfos <<< "$tableinfos"
    echo "DESCRIPTION FOR TABLE \"$args1\""
    for element in "${tableinfos[@]}"
    do
        echo "> $element"
    done
}

doList() {
  if [ "$args1" == "database" ]; then
    ls -lt db/
  elif [ "$args1" == "table" ]; then
    checkDatabase $BDSH_FILE
    DATABASE=$(cat db/$BDSH_FILE | tr -d '\n\r' | tr -s " ");
    echo $DATABASE |grep -Po 'desc_\K[^"]*'
  fi
}

############### BEAUTIFIER ######################

doBeautify() {
  checkDatabase $BDSH_FILE
  DATABASE=$(cat db/$BDSH_FILE | tr -d '\n\r' | tr -s " ");
  DATABASE=$(echo $DATABASE | sed -e s/{/{\\n/g | sed -e s/,/,\\n/g | sed -e s/\\[/\\[\\n/g | sed -e s/\\]/\\n\\]/g | sed -e s/}/\\n}/g)
  DATABASE=$(printf "$DATABASE" | sed -e 's/[[:space:]]"/"/g' -e 's/[[:space:]]{/{/g') # trim
  indent=""
  while IFS= read -r line
  do
      i=$((${#line}-2))
      lastchar=$(echo "${line:$i:2}")
      if [[ "$lastchar" == *"]"* ]]; then
            indent=$(printf "$indent" | cut -c3-)
      elif [[ "$lastchar" == *"}"* ]];then
            indent=$(printf "$indent" | cut -c3-)
      fi

      NEWDB=$(printf "$NEWDB\n$indent$line\n")

      if [[ "$lastchar" == *"{"* ]]; then
            indent=$indent"  "
      elif [[ "$lastchar" == *"["* ]];then
            indent=$indent"  "
      fi

  done < <(printf '%s\n' "$DATABASE")
  echo "BDSH | Successfully beautify !"
  printf "$NEWDB" > db/$BDSH_FILE
}

################## SELECT #######################

doSelect() {
  checkDatabase $BDSH_FILE
  DATABASE=$(cat db/$BDSH_FILE | tr -d '\n\r' | tr -s " ");
  checkTable $DATABASE $args1
  tableinfos=$(echo $DATABASE |grep -Po '"desc_'$args1'": \[\K[^\]]*')
  tableinfos=$(echo $tableinfos | sed -e s/\"//g)
  tableData=$(echo $DATABASE |grep -Po '"data_'$args1'": \[\K[^\]]*')
  tableData=$(echo $tableData | sed -e s/\"//g -e s/:[\ ]/:/g -e s/[\ ]:/:/g)
  IFS=', ' read -r -a tableinfos <<< "$tableinfos"
  IFS=', ' read -r -a tableData <<< "$tableData"
  filterCol $tableinfos $tableData $args2
  filter $tableData $args3 $args4
  IFS=', ' read -r -a tableinfos <<< "$tableinfos"
  displayString $tableData $tableinfos #init displaying
  printf "|";for element in "${tableinfos[@]}"
  do
      str=$element
      displayString $str
      printf "|"
  done
  printf "\n-"
  totallength=$(( $maxlength * ${#tableinfos[@]} + ${#tableinfos[@]} ))
  for i in $(seq 1 $totallength);
  do
    printf "-";
  done
  printf "\n"
  bloqued="0"
  for element in "${tableData[@]}"
  do
      if [[ "$element" == "^" ]]; then
          if [[ "$bloqued" == "0" ]]; then
            bloqued="1"
          else
            bloqued="0"
            continue
          fi
      fi
      if [[ "$bloqued" == "1" ]]; then
        continue
      fi
      if [[ "$element" == "}" ]]; then
          printf "\n";
      elif [[ "$element" == "{" ]]; then
          printf "|";
      elif [[ "$element" == "#" ]]; then
          continue
      else
          str=$( printf "$element" | cut -d":" -f2)
          displayString $str
          printf "|";
      fi
  done
}

filter() {
  args3=$(echo $args3 |sed -e s/=/:/g)
  echo filtering $args3
  for i in "${!tableData[@]}"
  do
      if [[ "${tableData[$i]}" == "{" ]]; then
          start=$i
      elif [[ "${tableData[$i]}" == "}" ]]; then
          if [[ "${tableData[$start]}" == "^" ]]; then
              tableData[$i]="^"
          fi
      else
          key=$(echo ${tableData[$i]} | cut -d":" -f1)
          searchkey=$(echo $args3 | cut -d":" -f1)
          value=$(echo ${tableData[$i]} | cut -d":" -f2)
          searchvalue=$(echo $args3 | cut -d":" -f2)
          if [[ "$searchkey" == "$key" ]]; then
              if [[ ! "$value" == *"$searchvalue"* ]]; then
                  tableData[$start]="^"
              fi
          fi
      fi
  done
  start=""
  echo -------
  for element in ${tableData[@]}; do
      echo $element
  done
  if [ ! -z $args4 ]; then
    args3=$args4
    args4=""
    filter $args3 $tableData
  fi
}

filterCol() {
    for i in "${!tableinfos[@]}"
    do
        if [[ "$args2" == *"${tableinfos[$i]}"* ]]; then
            new=$(echo $new ${tableinfos[$i]})
        fi
    done
    for i in "${!tableData[@]}"
    do
        if [[ "${tableData[$i]}" == "{" ]]; then
            continue
        elif [[ "${tableData[$i]}" == "}" ]]; then
            continue
        else
            key=$(echo ${tableData[$i]} | cut -d":" -f1)
            value=$(echo ${tableData[$i]} | cut -d":" -f2)
            if [[ ! "$args2" == *"$key"* ]]; then
                tableData[$i]="#"
            fi
        fi
    done
    tableinfos=$new
}

displayString() { #manage maxlength for display
    if [ -z $maxlength ]; then
        maxlength="2"
        for element in "${tableData[@]}"
        do
            if [ "${#element}" -gt "$maxlength" ];then
                maxlength=$(expr ${#element})
            fi
        done
        maxlength=$(expr $maxlength + 2)
    else
        remaininglength=$(expr $maxlength - ${#str} - 1)
        printf " $str"
        for i in $(seq 1 $remaininglength);
        do
          printf " ";
        done
    fi
}

#################################################
#################################################

main() {
  full_args=$( echo "$@" | sed 's/ /\\ /g' )
  IFS=':' read -r -a arr_args <<< "$full_args"

  for all in "${arr_args[@]}"
  do
    ## DISPLAYING HELP MESSAGE IF -H IS PRESENT OR NO ARGUMENTS
    if [[ "$all" == *"-h"* ]]; then
        displayHelp
    fi

    ## GETTING DATABASE NAME
    if [[ "$all" == *"-f"* ]]; then
        BDSH_FILE=$(echo $all | sed -e 's/.*-f\\ \([a-zA-Z.0-9]\+\).*/\1/g' )
        if [[ "$all" == *"--save"* ]];then
            echo $BDSH_FILE > .bdshrc
            echo "BDSH | Saved $BDSH_FILE as default database"
        fi
    else
        BDSH_FILE=$(env | grep BDSH_File | cut -d"=" -f2- );
        if [ -z "$BDSH_FILE" ]; then
            BDSH_FILE=$(cat .bdshrc)
        fi
    fi

    ## RETRIEVING ARGUMENTS
    if [[ "$all" == *"create"* ]]; then
        command="create"
        args1=$(echo $all | sed -e 's/.*create\\ \([a-zA-Z]\+\).*/\1/g' )
        if [ ! "$all" == "$args1" ]; then
            args2=$(echo $all | sed -e 's/.*'$args1'\\ \([a-zA-Z]\+\).*/\1/g' )
        else
            args1=""
        fi
        if [ ! "$all" == "$args2" ]; then
            args3=$(echo $all | sed -e 's/.*'$args2'\\ \([a-zA-Z, ]\+\).*/\1/g' )
        else
            args2=""
        fi
        if [ "$all" == "$args3" ]; then
            args3=""
        fi
        #echo $command " | " $args1 " | " $args2 " | " $args3
    elif [[ "$all" == *"insert"* ]]; then
        command="insert"
        args1=$(echo $all | sed -e 's/.*insert\\ \([a-zA-Z]\+\).*/\1/g' )
        if [ ! "$all" == "$args1" ]; then
            args2=$(echo $all | sed -e 's/.*'$args1'\\ \([a-zA-Z0-9\\ =,]\+\).*/\1/g' )
        else
            args1=""
        fi
        if [ "$all" == "$args2" ]; then
            args2=""
        fi
        #echo $command " | " $args1 " | " $args2
    elif [[ "$all" == *"delete"* ]]; then
        command="delete"
        args1=$(echo $all | sed -e 's/.*delete\\ \([a-zA-Z]\+\).*/\1/g' )
        if [ "$all" == "$args1" ]; then
            args1=""
        fi
    elif [[ "$all" == *"flush"* ]]; then
        command="flush"
        args1=$(echo $all | sed -e 's/.*flush\\ \([a-zA-Z]\+\).*/\1/g' )
        if [ "$all" == "$args1" ]; then
            args1=""
        fi
    elif [[ "$all" == *"describe"* ]]; then
        command="describe"
        args1=$(echo $all | sed -e 's/.*describe\\ \([a-zA-Z]\+\).*/\1/g' )
        if [ "$all" == "$args1" ]; then
            args1=""
        fi
    elif [[ "$all" == *"list"* ]]; then
        command="list"
        args1=$(echo $all | sed -e 's/.*list\\ \([a-zA-Z]\+\).*/\1/g' )
        if [ "$all" == "$args1" ]; then
            args1="database"
        fi
    elif [[ "$all" == *"select"* ]]; then
        command="select"
        args1=$(echo $all | sed -e 's/.*select\\ \([a-zA-Z]\+\).*/\1/g' )
        if [ ! "$all" == "$args1" ]; then
            args2=$(echo $all | sed -e 's/.*'$args1'\\ \([a-zA-Z0-9\\ =,]\+\).*/\1/g' )
        else
            args1=""
        fi
        if [[ "$all" == *"where"* ]]; then
           args3=$(echo $all | sed -e 's/.*where\\ \([a-zA-Z0-9=]\+\).*/\1/g' )
           if [ "$all" == "$args3" ]; then
               args3=""
           fi
        fi
        if [[ "$all" == *"and"* ]]; then
           args4=$(echo $all | sed -e 's/.*and\\ \([a-zA-Z0-9\\ =,]\+\).*/\1/g' )
           if [ "$all" == "$args3" ]; then
               args4=""
           fi
        fi
        if [ "$all" == "$args2" ]; then
            args2=""
        fi
    fi
    if [[ "$all" == *"-b"* ]]; then
        doBeautify $BDSH_FILE
    fi
    if [[ "$all" == *"-d"* ]]; then
        cat db/$BDSH_FILE
        printf \\n
    fi

    if [ -z "$BDSH_FILE" ]; then
        echo "BDSH | ERROR | No Database Specified"
        exit 1
    fi
    if [ ! -z "$command" ]; then
        #echo commandManager $command $args1 $args2 $args3 $BDSH_FILE
        commandManager $command $args1 $args2 $args3 $args4 $BDSH_FILE
    fi
  done
}

######################################
if [ ! -f .bdshrc ]; then
  echo default.json > .bdshrc
fi
main $@
