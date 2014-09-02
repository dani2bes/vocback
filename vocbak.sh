#!/bin/bash
# --------------------------------------------------------------------------- 
#title           :vocbak.sh
#description     :This script will make a backup from your vocabulary provider.
#author          :Daniel Muñoz
#date            :20140711
#version         :1.0    
#notes           :getopts is needed to use this script.
# ---------------------------------------------------------------------------


declare -r APPNAME="vocbak"
declare -r VERSION="1.0"
declare -r SCRIPT_SHELL=${SHELL}
declare -r TOTAL_ARGS=$#
declare -r ARGS=$@
declare -A options
declare -r WEBPAGE="webpage"
TEMP_DIR=/tmp/vocbak
COOKIES_DIR=$TEMP_DIR/cookies
COOKIES_FILE=$COOKIES_DIR/cookies.txt
WEBPAGES_DIR=$TEMP_DIR/webpages
VOCABULARY_HOST=
VOCABULARY_PROVIDER_URL=
MAIN_WEB_PAGE_URL=


appname_message(){
  cat << EOF     
  ▒█░░▒█ ▒█▀▀▀█ ▒█▀▀█ ▒█▀▀█ ░█▀▀█ ▒█░▄▀ 
      ░▒█▒█░ ▒█░░▒█ ▒█░░░ ▒█▀▀▄ ▒█▄▄█ ▒█▀▄░ 
      ░░▀▄▀░ ▒█▄▄▄█ ▒█▄▄█ ▒█▄▄█ ▒█░▒█ ▒█░▒█ 
EOF
}

app_description_message(){
  echo "Bash shell script to make safe backups from your vocabulary provider." 
}

welcome_message(){
  cat << EOF
  $(appname_message)
  
  Version: ${VERSION}
  $(app_description_message)
EOF
}

usage() {
  echo -e "Usage: ${APPNAME} [-h] -v host -u user -p pass -f file"
}

clean_up() { 
  rm -rf $TEMP_DIR;
  return
}
error_exit() {
  echo $1;
  clean_up;
  exit 1
}

graceful_exit() {
  clean_up;
  exit 0;
}


help_message() {
  cat << EOF
  $(welcome_message)

  $(usage)

  Options:

  -h    Display a help message and exit.
  -v    Host where the vocabulary will be back it up.
  -u    User name for signing in.
  -p    Password for signing in.
  -f    File to backup the vocabulary.

EOF
}

process_no_options(){
  if (($TOTAL_ARGS == 0)); then
    help_message;
    error_exit "no options provided.";
  fi 
}

process_options(){
  process_no_options;
  while getopts 'v:u:p:f:h' ARG; do
    case $ARG in
      v)
        options[host]=$OPTARG;;
      u)
        options[user]=$OPTARG ;;
      p)
        options[pass]=$OPTARG ;;
      f)
        options[file]=$OPTARG ;;
      h)
        help_message; graceful_exit ;;
      ?)
        help_message; error_exit "Unknown option $OPTARG" ;;
    esac
  done

  shift $(($OPTIND-1))
}

validate_opts(){
  if [[ -z ${options[host]} ]]; then
    help_message;
    error_exit "vocabulary host is required.";
  fi

  if [[ -z ${options[user]} ]]; then
    help_message;
    error_exit "user is required.";
  fi

  if [[ -z ${options[pass]} ]]; then
    help_message;
    error_exit "password is required.";
  fi

  if [[ -z ${options[file]} ]]; then
    help_message;
    error_exit "file is required.";
  fi
}

createTempDirs(){
   mkdir -p $TEMP_DIR $COOKIES_DIR $WEBPAGES_DIR;
}

defineHostUrls(){
  VOCABULARY_HOST=${options[host]};
  VOCABULARY_PROVIDER_URL=http://$VOCABULARY_HOST
  MAIN_WEB_PAGE_URL="$VOCABULARY_PROVIDER_URL/word_lists/692046/memo_words"
}

login(){
  curl -L "${VOCABULARY_PROVIDER_URL}/users/sign_in" -c $COOKIES_FILE -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8' \
  -H 'Accept-Encoding: gzip, deflate' -H 'Accept-Language: en-US,en;q=0.5' -H 'Connection: keep-alive' \
  -H "Host: ${VOCABULARY_HOST}" -H "Referer: ${VOCABULARY_PROVIDER_URL}/users/sign_in" \
  -H 'User-Agent: Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:29.0) Gecko/20100101 Firefox/29.0' \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d 'utf8=%E2%9C%93&authenticity_token=9%2BpGwzW3pGGeJkZ8uYT9A1jL%2BNWdmSpGr7hoy0%2BOW4c%3D&user%5Bremember_me%5D=true&commit=Log-in' \
  -d "user[email]=${options[user]}" -d "user[password]=${options[pass]}" > /dev/null;
} 
  
decompressAndRenameTo(){
  gunzip $WEBPAGES_DIR/$WEBPAGE.gz; mv $WEBPAGES_DIR/$WEBPAGE $WEBPAGES_DIR/$1;
}


createAbsoluteLink(){
  local relativeLink=$1;
  [[ ! -z $relativeLink ]] && echo $VOCABULARY_PROVIDER_URL$relativeLink || echo "";
}

findNextPageLinkFrom(){
  local page=$1;
  local pagelink=$(sed -n '/next_page.*href=\".*"/ s/.*\(next_page.*href=".*\"\).*/\1/p' $page \
     | sed -n '/href=".*"/ s/.*\(href=".*"\).*/\1/p' \
        | sed 's/\(href=\|"\)//g');
  echo $pagelink;
}

obtainLinkFromPageNumber(){
  local page=$1;
  local pageRelativeLink=$(findNextPageLinkFrom $WEBPAGES_DIR/$WEBPAGE$page.html);
  local pageAbsoluteLink=$(createAbsoluteLink $pageRelativeLink);
  echo $pageAbsoluteLink;
}


download_page(){
   local url=$1;
   local name=$2;
   curl $url -b $COOKIES_FILE -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8' \
     -H 'Accept-Encoding: gzip, deflate' -H 'Accept-Language: en-US,en;q=0.5' -H 'Connection: keep-alive' \
     -H "Host: ${VOCABULARY_HOST}" -H 'User-Agent: Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:29.0) Gecko/20100101 Firefox/29.0' \
     -o $WEBPAGES_DIR/$WEBPAGE.gz > /dev/null;

   [ $? != 0 ] && error_exit "cannot save page";
   decompressAndRenameTo $name;
}

linkIsUpToFollow(){
   local link=$1;
   [[ ! -z $link ]] && return 0 || return 1;
}

exitIfNoFollowable(){
   local link=$1;
   if linkIsUpToFollow $link;
      then 
        return 0;
      else 
        error_exit "main page not valid to process links";
   fi
}

saveTmpWebPages(){
  declare local page=1; 
  download_page $MAIN_WEB_PAGE_URL "${WEBPAGE}${page}.html";  
  local pageAbsoluteLink=$(obtainLinkFromPageNumber $page);
  echo $pageAbsoluteLink;
  exitIfNoFollowable $pageAbsoluteLink;

  while linkIsUpToFollow $pageAbsoluteLink; do
     
      page=$(( $page + 1 )) 
      download_page $pageAbsoluteLink "${WEBPAGE}${page}.html";
      pageAbsoluteLink=$(obtainLinkFromPageNumber $page);
      echo $pageAbsoluteLink;

  done
}

webPagesList(){
   local webPages=$(ls $WEBPAGES_DIR | xargs);
   echo $webPages;
}


writeWords(){
    local fromFile=$1;
    local toFile=$2;
    local tmpWordsFile="${TEMP_DIR}/tmpWords.txt";
    local tmpTranslatedWordsFile="${TEMP_DIR}/tmpTranslatedWords.txt"

    awk '/td word_value/,/<\/span>/' $fromFile | awk '!/div/ && !/span/ {print $1";"}' > $tmpWordsFile;

    awk '/div class=.def_val/,/<\/div>/' $fromFile | sed 's/<\(\/\)*div\(.*\x27\)*>//g' > $tmpTranslatedWordsFile;

    paste $tmpWordsFile $tmpTranslatedWordsFile | sed 's/\t//g' >> $toFile;
}

cleanContents(){
  local file=$1;
  cat /dev/null > $file;
}

writeVocabulary(){
  local file=$1;
  local webPages=$(webPagesList);

  cleanContents $file;
  for webPage in $webPages
  do
    writeWords $WEBPAGES_DIR/$webPage $file;
  done
}

backup_vocabulary(){
  createTempDirs;
  defineHostUrls;
  login;
  saveTmpWebPages;
  writeVocabulary ${options[file]};
}

totalWordsAddedToFile(){
  local file=$1;
  local totalWords=$(wc -l $file | cut -d' ' -f1);
  echo $totalWords;
}
  

showStatsInfo(){
  local file=$1;
  local totalWordsAdded=$(totalWordsAddedToFile $file);
  echo "Done."
  echo "${totalWordsAdded} words were added to ${file}."
  echo "Keep improving your language skills buddy."
}


main(){
  process_options $ARGS;
  validate_opts; 
  backup_vocabulary; 
  showStatsInfo ${options[file]};
  clean_up;
}

main;

