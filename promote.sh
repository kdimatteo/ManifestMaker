#!/bin/bash
#
# @file promote_static.sh
# @author ktdimatteo@constultantemail.com
# @description Deploy to stage-static
# 
# This is the script executed by Jenkins/Hudson to move files from accurev (depo:ux, stream:wmc-bootstrap, dir:publish-static) 
# to the deploy dir. Jenkins then triggers "Deploy CDN" in Nolio to move these file to stage-static.wellmanage.com
#
# You probably dont want to modify this unless the hosting environment or deploy process has changed 
#


# get the build version from the ANT properties file
export BUILD_VERSION=`sed '/^[[:space:]]*\#/d' config/project.properties | grep build.version | tail -n 1 | cut -d "=" -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'`



#Prompt the user to select a target promotion environment
if [[ $1 == "stage" ]]; then
	export DOMAIN=http://stage-static.wellmanage.com/bootstrap/$BUILD_VERSION
elif [[ "$1" == "prod" ]]; then
	export DOMAIN=http://static.wellmanage.com/bootstrap/$BUILD_VERSION
else
	echo "Bogus env, please use stage or prod"
	exit;
fi

# config
export DIR_DEPLOY=/deploy/capps/cdn/bootstrap

#export DIR_SRC=/build/capps/cdn/bootstrap/publish-static
export DIR_SRC=../publish-static

# path prefixes to move files from and to
export NOLIO_SRC=/deploy/capps/cdn/bootstrap/publish-static
export NOLIO_DEPLOY=/apps/cdn/bootstrap

# file handling
#pwd: /tech/tools/hudson-ws/jobs/Bootstrap build/workspace/build
export MANIFEST=../../manifest.txt

#pull from accurev
#/apps/wmc/scripts/updReftree bootstrap_build_reftree

# for debugging, you can simply display the dir listings
#find $FILES_SRC -type f -exec echo '{}' \;

# we will store file lists in these arrays
FILES_SRC=()

# loop through the src dir and stip non-matching path prefixes
# or use this -exec to kerp them : for file in `find $DIR_SRC -type f -exec echo '{}' \;`
for file in `find $DIR_SRC -type f -exec sh -c 'echo {} | sed s:$DIR_SRC::g' \;`
do
	FILES_SRC+=($file)
done

# notify user of current status
echo SRC: ${#FILES_SRC[@]} items in $DIR_SRC

# delete the manifest if it exists
if [ -f $MANIFEST ]; then
	rm $MANIFEST
fi
touch $MANIFEST


for file in ${FILES_SRC[@]}
do
	RESPONSE=$(curl --write-out %{http_code} --silent --output /dev/null $DOMAIN$file)
	if [ "$RESPONSE" == "404" ]; then
		echo "To Promote: $NOLIO_DEPLOY$file"
		echo
		printf $NOLIO_SRC$file" "$NOLIO_DEPLOY$file"\n" >> $MANIFEST
	fi
done

#Copy the war file into the deployment directory
rm -rf $DIR_DEPLOY
mkdir -p $DIR_DEPLOY
cp -r $DIR_SRC/../build/deploy.xml $DIR_DEPLOY

mkdir -p $NOLIO_SRC
cp -r $DIR_SRC/../publish-static/* $NOLIO_SRC

cp $MANIFEST $DIR_DEPLOY/
echo Copied $MANIFEST to $DIR_DEPLOY/


istatus=$?
if [ $istatus != 0 ]; then
	echo
	echo "The promotion has Failed!"
	echo "Reason: Unable to Copy"
	exit;
fi

echo "-----------------------"
echo "Promote Static Complete"
echo "-----------------------"
