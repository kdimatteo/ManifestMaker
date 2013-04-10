#!/bin/bash

#Prompt the user to select a target promotion environment
if [ $# -lt 1 ]
then echo Usage: promote.sh [Version]
exit;
fi

# config
export DIR_DEPLOY=/deploy/capps/cdn/bootstrap
export DIR_SRC=/build/capps/cdn/bootstrap/publish-static
export MANIFEST=manifest.txt
export LOG=log.txt

#pull from accurev
/apps/wmc/scripts/updReftree bootstrap_build_reftree

# for debugging, you can simply display the dir listings
#find $FILES_SRC -type f -exec echo '{}' \;

# we will store file lists in these arrays
FILES_SRC=()
FILES_DEPLOY=()

# loop through the src dir and stip non-matching path prefixes
# or use this -exec to kerp them : for file in `find $DIR_SRC -type f -exec echo '{}' \;`
for file in `find $DIR_SRC -type f -exec sh -c 'echo {} | sed s:$DIR_SRC::g' \;`
do
  FILES_SRC+=($file)
done

# loop through the log and generate an array of previous deploy files
while read line
do
	FILES_DEPLOY+=($line)
done < $LOG

# notify user of current status
echo SRC ${#FILES_SRC[@]} items in $DIR_SRC
echo LOG ${#FILES_DEPLOY[@]} items in $LOG

# our array of both files sorted by dictionary order
COMBINED=(`for R in "${FILES_SRC[@]}" "${FILES_DEPLOY[@]}" ; do echo "$R" ; done | sort -d`)

# delete the manifest if it exists
if [ -f $MANIFEST ]; then
	rm $MANIFEST
fi

# write a formatted manifest file
COLCOUNT=0
for file in ${COMBINED[@]}; do
	printf $file >> $MANIFEST
	if [[ $(( $COLCOUNT % 2 )) == 0 ]]; then
		printf "\t" >> $MANIFEST
	elif [[ $(( $COLCOUNT % 2 )) == 1 ]]; then
		printf "\n" >> $MANIFEST
	fi
	COLCOUNT=$((COLCOUNT+1))
done

#update the logfile
if [ -f $LOG ]; then
	rm $LOG
fi

for line in ${FILES_SRC[@]}; do
	echo $line >> $LOG
done


#Copy the war file into the deployment directory
rm -rf $DIR_DEPLOY
mkdir -p $DIR_DEPLOY
cp -r $DIR_SRC/ $DIR_DEPLOY
cp $DIR_SRC/../build/deploy.xml $DIR_DEPLOY/

istatus=$?
if [ $istatus != 0 ]; then
	echo
	echo "The promotion has Failed!"
	echo "Reason: Unable to Copy"
	exit;
fi